class NftFlipRecordsController < ApplicationController
  def index
    @page_index = 5
    @q = NftFlipRecord.includes(:nft).ransack(params[:q])
    @records = @q.result.order(sold_time: :desc).page(params[:page]).per(10)

    fliper_records = NftFlipRecord.today.group_by(&:fliper_address)
    @top_flipers = get_data(fliper_records, "top")
    @last_flipers = get_data(fliper_records, "last")

    collection_records = NftFlipRecord.today.group_by(&:slug)
    @top_collections = get_data(collection_records, "top")
    @last_collections = get_data(collection_records, "last")
  end

  def fliper_detail
    @fliper_data = NftFlipRecord.where(fliper_address: params[:fliper_address])
    @rank = NftFlipRecord.all.group_by(&:fliper_address).sort_by{|k, v| v.sum(&:revenue)}.map{|k,v| k}.index(params[:fliper_address]) + 1
    @top_nfts = @fliper_data.group_by(&:slug).map{|k,v| [k, v.sum(&:revenue), v.sum(&:crypto_revenue), v.first.sold_coin]}.sort_by{|r| r[1]}.reverse.first(3)
    @flip_data_chart = PriceChartService.new(start_date: 7.days.ago.to_date, fliper_address: params[:fliper_address]).get_flip_data
    @flip_count_chart = PriceChartService.new(start_date: 7.days.ago.to_date, fliper_address: params[:fliper_address]).get_flip_count
  end

  def collection_detail
    @collection_data = NftFlipRecord.where(slug: params[:slug])
    @rank = NftFlipRecord.all.group_by(&:slug).sort_by{|k, v| v.sum(&:revenue)}.map{|k,v| k}.index(params[:slug]) + 1
    @top_flipers = @collection_data.group_by(&:fliper_address).map{|k,v| [k, v.sum(&:revenue), v.sum(&:crypto_revenue), v.first.sold_coin]}.sort_by{|r| r[1]}.reverse.first(3)
    @flip_data_chart = PriceChartService.new(start_date: 7.days.ago.to_date, slug: params[:slug]).get_flip_data
    @flip_count_chart = PriceChartService.new(start_date: 7.days.ago.to_date, slug: params[:slug]).get_flip_count
  end

  private
  def get_data(data, type)
    if type == "top"
      data.map{|k,v| [k, v.count{|n| n.roi > 0 || n.same_coin? && n.crypto_roi > 0}]}.sort_by{|r| r[1]}.reverse.first(10)
    else
      data.map{|k,v| [k, v.count{|n| n.roi < 0 || n.same_coin? && n.crypto_roi < 0}]}.sort_by{|r| r[1]}.reverse.first(10)
    end
  end
end
