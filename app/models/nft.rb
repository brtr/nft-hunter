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

  def fetch_covalent_histories
    end_date = Date.today.strftime("%Y-%m-%d")
    start_date = (Date.today - 1.year).strftime("%Y-%m-%d")
    response = URI.open("https://api.covalenthq.com/v1/1/nft_market/collection/#{address}/?quote-currency=ETH&from=#{start_date}&to=#{end_date}&key=ckey_docs", {read_timeout: 20}).read rescue nil
    if response
      data = JSON.parse(response)
      items = data["data"]["items"]
      item = items.first
      self.update(chain_id: 1, symbol: item["collection_ticker_symbol"], logo: item["first_nft_image"])
      if items.any?
        items.each do |item|
          h = nft_histories.where(event_date: item["opening_date"]).first_or_create
          h.update(eth_floor_price: item["floor_price_quote_7d"], eth_volume: item["volume_quote_day"], sales: item["unique_token_ids_sold_count_day"])
        end
      else
        puts "Fetch covalent histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch covalent histories Error: #{name} can't fetch histories!"
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

        self.update(total_supply: result["count"], eth_floor_cap: result["market_cap"])
        bchp = NftHistoryService.cal_bchp(self)
        h = nft_histories.where(event_date: Date.yesterday).first_or_create
        h.update(eth_floor_price: result["floor_price"], eth_volume: result["one_day_volume"], sales: result["one_day_sales"], bchp: bchp)
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Opensea", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch opensea Error: #{name} can't sync stats"
    end
  end

  def sync_moralis_trades(mode="manual", offset=nil, date=Date.yesterday)
    return unless address
    if offset.present?
      from_date = date
    else
      today = Date.today
      from_date = nft_trades.where(trade_time: [date..today]).size > 0 ? date.strftime("%Y-%m-%d") : (today - 1.month).strftime("%Y-%m-%d")
    end

    begin
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/trades?chain=eth&marketplace=opensea&from_date=#{from_date}"
      url += "&offset=#{offset}" if offset
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["result"]
        if result.any?
          result.each do |trade|
            price = trade["price"].to_f / 10**18
            trade["token_ids"].each do |token_id|
              nft_trades.where(token_id: token_id, trade_time: trade["block_timestamp"], seller: trade["seller_address"],
                buyer: trade["buyer_address"], trade_price: price).first_or_create
            end
          end
        end
      end

      offset = data["page_size"].to_i * data["page"].to_i + 501
      if data["total"] > offset
        sleep 3
        sync_moralis_trades(mode, offset, from_date)
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Moralis", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch moralis Error: #{name} can't sync trades"
    end
  end

  def total_owners
    owner_nfts.where(event_date: Date.yesterday)
  end
end
