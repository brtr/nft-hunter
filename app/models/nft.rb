require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories

  def fetch_histories
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
        puts "Fetch Error: #{name} does not have history data!"
      end
    else
      puts "Fetch Error: #{name} 502 Bad Gateway!"
    end
  end
end
