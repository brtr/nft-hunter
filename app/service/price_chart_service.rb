class PriceChartService
  attr_reader :start_date, :end_date, :nft_id

  def initialize(start_date: nil, end_date: nil, nft_id: nil)
    @start_date = start_date
    @end_date = end_date || Date.yesterday
    @nft_id = nft_id
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
end