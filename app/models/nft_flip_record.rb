class NftFlipRecord < ApplicationRecord
  include ApplicationHelper

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

  def display_message
    "
    #{decimal_format bought} #{bought_coin} ($#{decimal_format bought_usd}) / #{decimal_format sold} #{sold_coin} ($#{decimal_format sold_usd}) / #{decimal_format crypto_revenue} #{sold_coin} ($#{decimal_format revenue})

    #{date_format bought_time} - #{date_format sold_time}

    #{I18n.t("views.labels.gap")}: #{ActiveSupport::Duration.build(gap).parts.except(:minutes, :seconds).map { |unit, n| I18n.t unit, count: n, scope: 'duration' }.to_sentence}
    "
  end

  def self.successful
    select{|n| n.roi > 0 || n.same_coin? && n.crypto_roi > 0}
  end

  def self.failed
    select{|n| n.roi < 0 || n.same_coin? && n.crypto_roi < 0}
  end
end
