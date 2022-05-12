class NftFlipRecordsController < ApplicationController
  def index
    @page_index = 5
    @q = NftFlipRecord.includes(:nft).ransack(params[:q])
    @records = @q.result.order(sold_time: :desc).page(params[:page]).per(10)

    fliper_records = NftFlipRecord.today.group(:fliper_address).count.sort_by{|k, v| v}
    @top_flipers = fliper_records.reverse.first(10)
    @last_flipers = fliper_records.first(10)

    collection_records = NftFlipRecord.today.group(:slug).count.sort_by{|k, v| v}
    @top_collections = collection_records.reverse.first(10)
    @last_collections = collection_records.first(10)
  end

  def fliper_detail
    @fliper_data = NftFlipRecord.where(fliper_address: params[:fliper_address])
    @rank = NftFlipRecord.all.group_by(&:fliper_address).sort_by{|k, v| v.sum(&:revenue)}.map{|k,v| k}.index(params[:fliper_address])
    @top_nfts = @fliper_data.group_by(&:slug).map{|k,v| [k, v.sum(&:revenue), v.sum(&:crypto_revenue), v.first.sold_coin]}.sort_by{|r| r[1]}.first(3)
    @flip_data_chart = PriceChartService.new(start_date: 7.days.ago.to_date, fliper_address: params[:fliper_address]).get_flip_data
    @flip_count_chart = PriceChartService.new(start_date: 7.days.ago.to_date, fliper_address: params[:fliper_address]).get_flip_count
  end

  def collection_detail
    @collection_data = NftFlipRecord.where(slug: params[:collection])
  end
end
