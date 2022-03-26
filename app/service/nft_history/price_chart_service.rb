class NftHistory::PriceChartService
  attr_reader :start_date, :end_date, :nft_id

  def initialize(start_date: nil, end_date: nil, nft_id: nil)
    @start_date = start_date
    @end_date = end_date || Date.yesterday
    @nft_id = nft_id
  end

  def get_price_data
    result = {}
    NftHistory.where(event_date: [start_date..end_date], nft_id: nft_id).group_by(&:event_date).each do |date, records|
      result.merge!({date => records.map{|x| {floor_price: x.floor_price, volume: x.volume, sales: x.sales, date: date}}})
    end

    result
  end
end