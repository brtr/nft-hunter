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

    Nft.where.not(address: nil).each do |nft|
      puts nft.name
      nft.fetch_owners
      sleep 1
    end

    puts "End at #{Time.now}"
  end

  desc 'Fetch target nft owners purchase data'
  task :fetch_target_nft_owners_data, [:duration] => [:environment] do |task, args|
    target_owners = OwnerNft.includes(:owner).where(nft_id: Nft.where(is_marked: true).pluck(:id)).uniq.inject({}){|sum, o| sum.merge!({ o.owner.address => o.owner_id})}
    Nft.all.each do |nft|
      response = NftOwnerService.fetch_trades(nft.address, args[:duration])

      if response
        data = JSON.parse(response)
        data["result"].each do |r|
          owners_address = target_owners.keys
          address = r["buyer_address"]

          if owners_address.include?(address)
            h = nft.nft_purchase_histories.where(owner_id: target_owners[address], purchase_date: r["block_timestamp"]).first_or_create
            h.update(amount: r["token_ids"].count)
          end
        end
      end
    end
  end
end