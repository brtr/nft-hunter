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

  class << self
    def get_flipa_winners(start_date: 30.days.ago, number: 10)
      sql = <<-SQL
        WITH fliper_counts AS (
              select fliper_address, count(*) as total_count from nft_flip_records where sold_time > '#{start_date.to_date.to_s}' group by fliper_address
        ), win_fliper_counts AS (
              select fliper_address, count(*) as win_count from nft_flip_records where roi > 0 and sold_time > '#{start_date.to_date.to_s}' group by fliper_address
        )
        select win_fliper_counts.fliper_address, win_fliper_counts.win_count/total_count*100 as win_rate, win_fliper_counts.win_count, total_count
        from fliper_counts
        LEFT JOIN win_fliper_counts
        ON win_fliper_counts.fliper_address = fliper_counts.fliper_address
        where win_fliper_counts.win_count > 1 
        order by win_rate desc, win_count desc
        limit #{number};
      SQL
      NftFlipRecord.connection.select_all(sql)
    end

    def get_best_flipas(fliper_address:, number: 5)
      NftFlipRecord.where(fliper_address: fliper_address).order(revenue: :desc, gap: :asc).limit(number)
    end
  end
end
