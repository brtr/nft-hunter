require 'open-uri'
require 'json'

namespace :data do
  desc 'Generate NFT List from nftpricefloor'
  task generate_nfts: :environment do
    puts "Start at #{Time.now}"

    response = URI.open("https://api-bff.nftpricefloor.com/nfts").read
    result = JSON.parse(response)
    if result.any?
      result.each do |asset|
        name = asset["name"]
        puts name
        nft = Nft.where(name: name, chain_id: 1, slug: asset["slug"]).first_or_create
        nft.update(total_supply: asset["totalSupply"], listed_ratio: asset["listedRatio"], floor_cap: asset["floorCapUSD"], variation: asset["variationUSD"], opensea_url: asset["url"])
        sales_data = asset["salesData"]
        h = nft.nft_histories.where(event_date: Date.yesterday).first_or_create
        h.update(floor_price: asset["floorPriceUSD"], sales: sales_data["numberSales24h"], volume: sales_data["sales24hVolumeUSD"])
      end
    else
      puts "Fetch Error: No nfts!"
    end

    puts "End at #{Time.now}"
  end

  desc 'Fetch NFT histories'
  task fetch_histories: :environment do
    puts "Start at #{Time.now}"

    Nft.includes(:nft_histories).each do |nft|
      puts nft.name
      nft.fetch_histories
      sleep 1
    end

    puts "End at #{Time.now}"
  end

  desc "Create nfts_view"
  task generate_nfts_view: :environment do
    sql = ERB.new(File.read("app/data_views/nfts_view.sql")).result()
    Nft.connection.execute(sql)
    p "Create nfts_view success"
  end
end