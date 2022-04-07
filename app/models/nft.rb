require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories
  has_many :owner_nfts
  has_many :owners, through: :owner_nfts
  has_many :nft_purchase_histories
  has_many :target_nft_owner_histories

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

  def fetch_covalent_histories
    end_date = Date.today.strftime("%Y-%m-%d")
    start_date = (Date.today - 1.year).strftime("%Y-%m-%d")
    response = URI.open("https://api.covalenthq.com/v1/1/nft_market/collection/#{address}/?from=#{start_date}&to=#{end_date}&key=ckey_docs", {read_timeout: 20}).read rescue nil
    if response
      data = JSON.parse(response)
      items = data["data"]["items"]
      item = items.first
      self.update(chain_id: 1, symbol: item["collection_ticker_symbol"], logo: item["first_nft_image"])
      if items.any?
        items.each do |item|
          h = nft_histories.where(event_date: item["opening_date"]).first_or_create
          h.update(floor_price: item["floor_price_quote_7d"], volume: item["volume_quote_day"], sales: item["unique_token_ids_sold_count_day"])
        end
      else
        puts "Fetch covalent histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch covalent histories Error: #{name} can't fetch histories!"
    end
  end

  def fetch_owners(mode="manual", cursor=nil)
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
          owner_nft = owner.owner_nfts.where(nft_id: self.id, event_date: Date.today).first_or_create(amount: 0, token_ids: [])
          token_ids = owner_nft.token_ids | token_ids
          owner_nft.update(amount: token_ids.count, token_ids: token_ids)
        end

        sleep 5
        fetch_owners(mode, data["cursor"]) if data["cursor"].present?
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
end
