require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories

  def fetch_pricefloor_histories
    response = URI.open("https://api-bff.nftpricefloor.com/nft/#{slug}/chart/pricefloor?interval=all").read rescue nil
    if response
      data = JSON.parse(response)
      dates = data["dates"]
      if dates.any?
        dates.each_with_index do |el, idx|
          date = DateTime.parse el
          next unless date == date.at_beginning_of_day
          h = nft_histories.where(event_date: date).first_or_create
          h.update(floor_price: data["dataPriceFloorUSD"][idx], volume: data["dataVolumeUSD"][idx], sales: data["sales"][idx])
        end
      else
        puts "Fetch price floor histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch price floor histories Error: #{name} 502 Bad Gateway!"
    end
  end

  def fetch_covalent_histories
    start_date = "2022-01-01"
    end_date = Date.today.strftime("%Y-%m-%d")
    response = URI.open("https://api.covalenthq.com/v1/1/nft_market/collection/#{address}/?from=#{start_date}&to=#{end_date}&key=ckey_docs").read rescue nil
    if response
      data = JSON.parse(response)
      items = data["data"]["items"]
      if items.any?
        items.each do |item|
          self.update(symbol: item["collection_ticker_symbol"]) if symbol.nil?
          date = item["opening_date"]
          h = nft_histories.where(event_date: date).first_or_create
          h.update(floor_price_7d: item["floor_price_quote_7d"], volume: item["volume_quote_day"], sales: item["unique_token_ids_sold_count_day"])
        end
      else
        puts "Fetch covalent histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch covalent histories Error: #{name} can't fetch histories!"
    end
  end
end
