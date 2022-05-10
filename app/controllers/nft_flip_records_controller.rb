class NftFlipRecordsController < ApplicationController
  def index
    @page_index = 5
    @q = NftFlipRecord.includes(:nft).ransack(params[:q])
    @records = @q.result.order(roi: :desc).page(params[:page]).per(10)

    fliper_records = NftFlipRecord.group(:fliper_address).count.sort_by{|k, v| v}
    @top_flipers = fliper_records.reverse.first(10)
    @last_flipers = fliper_records.first(10)

    collection_records = NftFlipRecord.group(:slug).count.sort_by{|k, v| v}
    @top_collections = collection_records.reverse.first(10)
    @last_collections = collection_records.first(10)
  end
end
