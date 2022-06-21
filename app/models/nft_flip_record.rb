class NftFlipRecord < ApplicationRecord
  belongs_to :nft, touch: true

  ETH_PAYMENT = ["ETH", "WETH"]

  def is_eth_payment?
    bought_coin.in?(ETH_PAYMENT) && sold_coin.in?(ETH_PAYMENT)
  end

  def revenue_eth
    sold - bought
  end

  def roi_eth
    bought == 0 ? 0 : revenue_eth / bought
  end
end
