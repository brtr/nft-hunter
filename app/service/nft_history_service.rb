require 'open-uri'

class NftHistoryService
  class << self
    def fetch_pricefloor_nfts
      result = get_pricefloor_data rescue []
      if result.any?
        result.each do |asset|
          slug = asset["slug"]
          puts slug
          nft = Nft.where(slug: slug, chain_id: 1).first
          next if slug.blank? || nft.blank?
          nft.update(total_supply: asset["totalSupply"], listed_ratio: asset["listedRatio"], floor_cap: asset["floorCapUSD"], variation: asset["variationUSD"], opensea_url: asset["url"])
          sales_data = asset["salesData"]
          h = nft.nft_histories.where(event_date: Date.yesterday).first_or_create
          h.update(floor_price: asset["floorPriceUSD"], sales: sales_data["numberSales24h"], volume: sales_data["sales24hVolumeUSD"])
        end
      else
        puts "Fetch NFTPriceFloor Error: No nfts!"
      end
    end

    def get_pricefloor_data
      response = URI.open("https://api-bff.nftpricefloor.com/nfts").read
      JSON.parse(response)
    end

    def generate_nfts_view
      sql = ERB.new(File.read("app/data_views/nfts_view.sql")).result()
      Nft.connection.execute(sql)
    end
  end
end