class NftFlipRecord < ApplicationRecord
  belongs_to :nft, touch: true

  scope :today, -> { where(sold_time: [Date.yesterday.at_beginning_of_day..Date.today.at_end_of_day]) }

  ETH_PAYMENT = ["ETH", "WETH"]

  def is_eth_payment?
    bought_coin.in?(ETH_PAYMENT) && sold_coin.in?(ETH_PAYMENT)
  end

  def same_coin?
    bought_coin == sold_coin || is_eth_payment?
  end

  def crypto_revenue
    sold - bought
  end

  def crypto_roi
    bought == 0 ? 0 : crypto_revenue / bought
  end

  def self.successful
    select{|n| n.roi > 0 || n.same_coin? && n.crypto_roi > 0}
  end

  def self.failed
    select{|n| n.roi < 0 || n.same_coin? && n.crypto_roi < 0}
  end
end
