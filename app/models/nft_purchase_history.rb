class NftPurchaseHistory < ApplicationRecord
  belongs_to :nft
  belongs_to :owner

  scope :without_target_nfts, -> { includes(:nft).where.not(nft: {is_marked: true})}
  scope :last_24h, -> { where("purchase_date >= ? and purchase_date <= ?", Date.yesterday, Date.today) }
end
