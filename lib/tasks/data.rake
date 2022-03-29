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
        name = asset["name"].gsub(/[^A-Za-z0-9]/, '').downcase
        puts name
        nft = Nft.where(name: name, chain_id: 1).first_or_create(total_supply: asset["totalSupply"], slug: asset["slug"], listed_ratio: asset["listedRatio"], floor_cap: asset["floorCapUSD"], variation: asset["variationUSD"], opensea_url: asset["url"])
        sales_data = asset["salesData"]
        nft.nft_histories.where(event_date: Date.yesterday).first_or_create(floor_price: asset["floorPriceUSD"], sales: sales_data["numberSales24h"], volume: sales_data["sales24hVolumeUSD"])
      end
    else
      puts "Fetch NFTPriceFloor Error: No nfts!"
    end

    puts "End at #{Time.now}"
  end

  desc 'Fetch NFT List from covalent'
  task fetch_covalent_nfts: :environment do
    puts "Start at #{Time.now}"

    size = 500
    response = URI.open("https://api.covalenthq.com/v1/1/nft_market/?quote-currency=USD&page-size=#{size}&key=ckey_docs").read
    result = JSON.parse(response)
    data = result["data"]["items"]
    if data.any?
      data.each do |asset|
        name = asset["collection_name"].gsub(/[^A-Za-z0-9]/, '').downcase rescue nil
        next unless name
        puts name
        nft = Nft.where(name: name, chain_id: 1).first_or_create
        nft.update(logo: asset["first_nft_image"], address: asset["collection_address"], floor_cap: asset["market_cap_quote"])
        h = nft.nft_histories.where(event_date: Date.yesterday).first_or_create
        h.update(floor_price_7d: asset["floor_price_quote_7d"], volume: asset["volume_quote_24h"])
      end
    else
      puts "Fetch Covalent Error: No nfts!"
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

  desc 'Fetch covalent nft histories'
  task fetch_covalent_histories: :environment do
    puts "Start at #{Time.now}"

    Nft.includes(:nft_histories).where(slug: nil).each do |nft|
      puts nft.name
      nft.fetch_covalent_histories
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
      next if nft.id == 6235
      puts nft.name
      nft.fetch_owners
      sleep 1
    end

    puts "End at #{Time.now}"
  end
end