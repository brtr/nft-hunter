class OwnerNft < ApplicationRecord
  belongs_to :owner
  belongs_to :nft

  serialize :token_ids

  def self.bchp_ids
    OwnerNft.where(event_date: Date.yesterday, nft_id: Nft.where(is_marked: true).pluck(:id)).pluck(:owner_id).uniq
  end
end
