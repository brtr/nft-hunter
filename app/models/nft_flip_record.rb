class NftFlipRecord < ApplicationRecord
  belongs_to :nft, touch: true

  scope :today, -> { where(sold_time: [Date.yesterday.at_beginning_of_day..Date.today.at_end_of_day]) }
  scope :successful, -> { where("roi > ?", 0) }
  scope :failed, -> { where("roi <= ?", 0) }

  ETH_PAYMENT = ["ETH", "WETH"]

  def is_eth_payment?
    bought_coin.in?(ETH_PAYMENT) && sold_coin.in?(ETH_PAYMENT)
  end

  def crypto_revenue
    sold - bought
  end

  def crypto_roi
    bought == 0 ? 0 : crypto_revenue / bought
  end
end
