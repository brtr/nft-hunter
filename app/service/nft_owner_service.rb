require 'open-uri'

class NftOwnerService
  class << self
    def get_target_owners_ratio(nft_id)
      owners = total_owners(nft_id)

      result = []
      target_nfts.each do |nft|
        owner_ids = OwnerNft.where(nft_id: nft.id).pluck(:owner_id)
        target_owner_ids = owners.select{|o| owner_ids.include?(o)}
        ratio = owners.count == 0 ? 0 : (target_owner_ids.count.to_f / owners.count.to_f).round(2)

        result.push(
          {
            nft: nft.name,
            owners_count: target_owner_ids.count,
            owners_ratio: (ratio * 100).round(2)
          }
        )
      end

      result
    end

    def total_owners(nft_id)
      OwnerNft.where(nft_id: nft_id).pluck(:owner_id)
    end

    def fetch_trades(address, duration)
      to_date = Date.today
      from_date = to_date - duration.to_i.days
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/trades?chain=eth&marketplace=opensea&format=decimal&from_date=#{from_date}&to_date=#{to_date}"
      URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read rescue nil
    end

    def get_target_owners_trades(address, duration)
      result = {total_count: 0, data: []}
      response = fetch_trades(address, duration)

      if response
        data = JSON.parse(response)
        total_count = data["result"].sum{|r| r["token_ids"].count}
        result[:total_count] = total_count
        target_nfts.each do |nft|
          owners = OwnerNft.where(nft_id: nft.id).includes(:owner).map{|o| o.owner.address}
          purchase_count = data["result"].select{|r| owners.include?(r["buyer_address"])}.sum{|r| r["token_ids"].count}

          result[:data].push(
            {
              nft: nft.name,
              purchase_count: purchase_count
            }
          )
        end
      end

      result
    end

    def target_nfts
      Nft.where(is_marked: true)
    end

    def get_target_owners_rank
      result = JSON.parse($redis.get("holding_rank")) rescue {}
      if result.blank?
        target_ids = target_nfts.pluck(:id)
        owner_ids = OwnerNft.where(nft_id: target_ids).pluck(:owner_id).uniq
        Nft.includes(:owner_nfts).each do |nft|
          next if target_ids.include?(nft.id)
          owners_count = nft.owner_nfts.where(owner_id: owner_ids).sum(:amount)

          result.merge!(
            {
              nft.id => owners_count
            }
          )
        end

        $redis.set("holding_rank", result.to_json, ex: 23.hours)
      end

      result.sort_by{|k, v| v}.reverse.first(10).to_h
    end
  end
end