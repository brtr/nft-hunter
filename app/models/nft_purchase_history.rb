class NftPurchaseHistory < ApplicationRecord
  belongs_to :nft
  belongs_to :owner

  scope :without_target_nfts, -> { includes(:nft).where.not(nft: {is_marked: true})}
  scope :last_24h, -> { where(purchase_date: [Date.yesterday..Date.today]) }

  def self.last_day
    date = NftPurchaseHistory.order(purchase_date: :asc).last.purchase_date
    NftPurchaseHistory.where(purchase_date: [date - 1.day..date])
  end
end
