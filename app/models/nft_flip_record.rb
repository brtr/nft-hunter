class NftFlipRecord < ApplicationRecord
  belongs_to :nft, touch: true

  ETH_PAYMENT = ["ETH", "WETH"]

  def is_eth_payment?
    bought_coin.in?(ETH_PAYMENT) && sold_coin.in?(ETH_PAYMENT)
  end

  def revenue_eth
    price - cost
  end

  def roi_eth
    cost == 0 ? 0 : revenue_eth / cost
  end
end
