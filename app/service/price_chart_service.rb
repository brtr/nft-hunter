class PriceChartService
  attr_reader :start_date, :end_date, :nft_id, :fliper_address

  def initialize(start_date: nil, end_date: nil, nft_id: nil, fliper_address: nil)
    @start_date = start_date
    @end_date = end_date || Date.yesterday
    @nft_id = nft_id
    @fliper_address = fliper_address
  end

  def get_price_data
    result = {}
    NftHistory.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      result.merge!({date => records.map{|x| {floor_price: x.eth_floor_price, volume: x.eth_volume, sales: x.sales, date: date}}})
    end

    result
  end

  def get_holding_data
    result = {}
    TargetNftOwnerHistory.holding.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      h = NftHistory.where(nft_id: nft_id, event_date: date).first_or_create
      result.merge!({date => records.map{|x| {bch_count: x.data[:bch_count], floor_price: h.eth_floor_price, date: date}}})
    end
    result
  end

  def get_purchase_data
    result = {}
    TargetNftOwnerHistory.purchase.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      result.merge!({date => records.map{|x| {bch_count: x.data[:bch_count], date: date}}})
    end
    result
  end

  def get_trade_data
    data = NftTrade.where(trade_time: [start_date.at_beginning_of_day..end_date.at_end_of_day], nft_id: nft_id).order(trade_time: :asc).map{|trade| [trade.trade_price, trade.trade_time.strftime("%Y-%m-%d %H:%M")]}.uniq
    {
      data: data
    }
  end

  def get_flip_data
    data = NftFlipRecord.where(sold_time: [start_date.at_beginning_of_day..end_date.at_end_of_day], fliper_address: fliper_address).order(sold_time: :asc).map{|r| [r.crypto_revenue, r.sold_time.strftime("%Y-%m-%d %H:%M")]}.uniq
    {
      data: data
    }
  end

  def get_flip_count
    result = {}
    NftFlipRecord.where(sold_time: [start_date.at_beginning_of_day..end_date.at_end_of_day]).group_by{|r| r.sold_time.to_date}.sort_by{|date, records| date}.each do |date, records|
      result.merge!({date => {total_count: records.size, successful_count: records.count{|r| r.roi > 0}, failed_count: records.count{|r| r.roi <= 0}, date: date}})
    end
    result
  end
end