class PriceChartService
  attr_reader :start_date, :end_date, :nft_id, :labels

  def initialize(start_date: nil, end_date: nil, nft_id: nil)
    @start_date = start_date
    @end_date = end_date || Date.yesterday
    @nft_id = nft_id
    @labels = NftOwnerService.target_nfts.pluck(:name)
  end

  def get_price_data
    result = {}
    NftHistory.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      result.merge!({date => records.map{|x| {floor_price: x.eth_floor_price, volume: x.eth_volume, sales: x.sales, date: date}}})
    end

    result
  end

  def get_holding_data
    result = {labels: labels, data: {}}
    TargetNftOwnerHistory.holding.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      result[:data].merge!({date => records.map{|x| {bch_count: x.data[:bch_count], date: date}}})
    end
    result
  end

  def get_purchase_data
    result = {labels: labels, data: {}}
    TargetNftOwnerHistory.purchase.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).sort_by{|date, records| date}.each do |date, records|
      result[:data].merge!({date => records.map{|x| {bch_count: x.data[:bch_count], date: date}}})
    end
    result
  end
end