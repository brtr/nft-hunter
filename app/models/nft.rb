require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories
  has_many :owner_nfts
  has_many :owners, through: :owner_nfts

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

  def fetch_owners(cursor=nil)
    return unless address
    url = "https://deep-index.moralis.io/api/v2/nft/#{address}/owners?chain=eth&format=decimal"
    url += "&cursor=#{cursor}" if cursor
    response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read rescue nil
    if response
      data = JSON.parse(response)
      result = data["result"].group_by{|x| x["owner_of"]}.inject({}){|sum, x| sum.merge({x[0] => x[1].map{|y| y["token_id"]}})}
      puts "#{name} has #{result.count} owners"
      result.each do |address, token_ids|
        owner = Owner.where(address: address).first_or_create
        owner_nft = owner.owner_nfts.where(nft_id: self.id).first_or_create
        owner_nft.update(amount: token_ids.count, token_ids: token_ids)
      end

      fetch_owners(data["cursor"]) if data["cursor"].present?
    else
      puts "Fetch moralis Error: #{name} can't fetch owners"
    end
  end
end