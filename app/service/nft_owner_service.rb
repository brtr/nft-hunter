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

    def get_target_owners_trades(address, duration)
      result = {total_count: 0, data: []}
      to_date = Date.yesterday
      from_date = to_date - duration.to_i.days
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/trades?chain=eth&marketplace=opensea&format=decimal&from_date=#{from_date}&to_date=#{to_date}"
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read rescue nil

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

    private
    def target_nfts
      Nft.where(is_marked: true)
    end
  end
end