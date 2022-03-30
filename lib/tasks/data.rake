require 'open-uri'
require 'json'

namespace :data do
  desc 'Fetch NFT List from nftpricefloor'
  task fetch_pricefloor_nfts: :environment do
    puts "Start at #{Time.now}"

    response = URI.open("https://api-bff.nftpricefloor.com/nfts").read
    result = JSON.parse(response)
    if result.any?
      result.each do |asset|
        slug = asset["slug"]
        puts slug
        nft = Nft.where(slug: slug, chain_id: 1).first
        nft.update(total_supply: asset["totalSupply"], listed_ratio: asset["listedRatio"], floor_cap: asset["floorCapUSD"], variation: asset["variationUSD"], opensea_url: asset["url"])
        sales_data = asset["salesData"]
        nft.nft_histories.where(event_date: Date.yesterday).first_or_create(floor_price: asset["floorPriceUSD"], sales: sales_data["numberSales24h"], volume: sales_data["sales24hVolumeUSD"])
      end
    else
      puts "Fetch NFTPriceFloor Error: No nfts!"
    end

    puts "End at #{Time.now}"
  end

  desc 'Fetch nft price floor histories'
  task fetch_pricefloor_histories: :environment do
    puts "Start at #{Time.now}"

    Nft.includes(:nft_histories).where.not(slug: nil).each do |nft|
      puts nft.name
      nft.fetch_pricefloor_histories
      sleep 1
    end

    puts "End at #{Time.now}"
  end

  desc 'Create nfts_view'
  task generate_nfts_view: :environment do
    sql = ERB.new(File.read("app/data_views/nfts_view.sql")).result()
    Nft.connection.execute(sql)
    p "Create nfts_view success"
  end

  desc 'Fetch nft owners'
  task fetch_nft_owners: :environment do
    puts "Start at #{Time.now}"

    Nft.where.not(address: nil).each do |nft|
      puts nft.name
      nft.fetch_owners
      sleep 1
    end

    puts "End at #{Time.now}"
  end
end