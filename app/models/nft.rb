require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories
  has_many :owner_nfts
  has_many :owners, through: :owner_nfts
  has_many :nft_purchase_histories
  has_many :target_nft_owner_histories
  has_many :nft_trades

  def fetch_pricefloor_histories
    response = URI.open("https://api-bff.nftpricefloor.com/nft/#{slug}/chart/pricefloor?interval=all", {read_timeout: 20}).read rescue nil
    if response
      data = JSON.parse(response)
      dates = data["dates"]
      if dates.any?
        dates.each_with_index do |el, idx|
          date = DateTime.parse el
          next unless date == date.at_beginning_of_day
          h = nft_histories.where(event_date: date).first_or_create
          h.update(floor_price: data["dataPriceFloorUSD"][idx], eth_floor_price: data["dataPriceFloorETH"][idx], sales: data["sales"][idx],
                  volume: data["dataVolumeUSD"][idx], eth_volume: data["dataVolumeETH"][idx])
        end
      else
        puts "Fetch price floor histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch price floor histories Error: #{name} 502 Bad Gateway!"
    end
  end

  def fetch_owners(mode: "manual", cursor: nil, date: Date.today)
    return unless address
    begin
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/owners?chain=eth&format=decimal"
      url += "&cursor=#{cursor}" if cursor
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["result"].group_by{|x| x["owner_of"]}.inject({}){|sum, x| sum.merge({x[0] => x[1].map{|y| y["token_id"]}})}
        puts "#{name} has #{result.count} owners"
        result.each do |address, token_ids|
          owner = Owner.where(address: address).first_or_create
          owner_nft = owner.owner_nfts.where(nft_id: self.id, event_date: date).first_or_create(amount: 0, token_ids: [])
          token_ids = owner_nft.token_ids | token_ids
          owner_nft.update(amount: token_ids.count, token_ids: token_ids)
        end

        sleep 3
        fetch_owners(mode: mode, cursor: data["cursor"], date: date) if data["cursor"].present?
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Fetch Owner", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch moralis Error: #{name} can't fetch owners"
    end
  end

  def fetch_pricefloor_nft
    result = NftHistoryService.get_pricefloor_data rescue []
    if result.any?
      asset = result.select{|r| r["slug"] == slug}.first
      if asset
        self.update(total_supply: asset["totalSupply"], listed_ratio: asset["listedRatio"], floor_cap: asset["floorCapUSD"],
          variation: asset["variationUSD"], opensea_url: asset["url"], opensea_slug: slug, eth_floor_cap: asset["floorCapETH"])
        self.fetch_pricefloor_histories
      else
        return false
      end
    else
      return false
    end
  end

  def sync_opensea_stats(mode="manual")
    return unless opensea_slug

    begin
      url = "https://api.opensea.io/api/v1/collection/#{opensea_slug}/stats"
      response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["stats"]

        self.update(total_supply: result["count"], eth_floor_cap: result["market_cap"], variation: 0)
        bchp = NftHistoryService.cal_bchp(self)
        h = nft_histories.where(event_date: Date.yesterday).first_or_create
        h.update(eth_floor_price: result["floor_price"], eth_volume: result["one_day_volume"], sales: result["one_day_sales"], bchp: bchp)
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Opensea Stats", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch opensea Error: #{name} can't sync stats"
    end
  end

  def sync_moralis_trades(mode="manual", cursor=nil)
    return unless address

    begin
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/transfers?chain=eth&format=decimal"
      url += "&cursor=#{cursor}" if cursor
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["result"]
        if result.any?
          result.each do |trade|
            next if trade["value"].to_f == 0 || trade["contract_type"] != "ERC721" || trade["from_address"] == "0x0000000000000000000000000000000000000000"
            price = trade["value"].to_f / 10**18
            nft_trades.where(token_id: trade["token_id"], trade_time: trade["block_timestamp"], seller: trade["from_address"],
                buyer: trade["to_address"], trade_price: price).first_or_create
          end
        end
      end

      size = data["page_size"].to_i * data["page"].to_i + 500
      sync_moralis_trades(mode, data["cursor"]) if data["cursor"].present? && nft_trades.count < size
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Moralis Transfers", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch moralis Error: #{name} can't sync transfers"
    end
  end

  def total_owners
    owner_nfts.where(event_date: Date.yesterday)
  end

  def sync_opensea_info(mode="manual")
    return unless address

    begin
      url = "https://api.opensea.io/api/v1/asset_contract/#{address}"
      response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
      if response
        data = JSON.parse(response)

        slug = data["collection"]["slug"]
        self.update(chain_id: 1, name: data["name"], slug: slug, opensea_slug: slug, logo: data["image_url"], opensea_url: "https://opensea.io/collection/#{slug}")
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Opensea Info", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch opensea Error: #{name} can't sync info"
    end
  end
end
