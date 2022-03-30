class NftOwnerService
  class << self
    def get_target_owners_ratio(nft_id)
      owners = total_owners(nft_id)

      get_target_nft_owners(owners)
    end

    def total_owners(nft_id)
      OwnerNft.where(nft_id: nft_id).pluck(:owner_id)
    end

    def get_target_nft_owners(owners)
      result = []
      nfts = Nft.where(is_marked: true)
      nfts.each do |nft|
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
  end
end