require 'open-uri'
require 'json'

namespace :data do
  desc 'Fetch NFT List from nftpricefloor'
  task fetch_pricefloor_nfts: :environment do
    puts "Start at #{Time.now}"

    NftHistoryService.fetch_pricefloor_nfts

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
    NftHistoryService.generate_nfts_view
    p "Create nfts_view success"
  end

  desc 'Fetch nft owners'
  task fetch_nft_owners: :environment do
    puts "Start at #{Time.now}"
    NftOwnerService.fetch_owners("auto")
    puts "End at #{Time.now}"
  end

  desc 'Fetch target nft owners purchase data'
  task :fetch_target_nft_owners_purchase, [:duration] => [:environment] do |task, args|
    NftOwnerService.fetch_target_nft_owners_purchase(args[:duration])
  end
end