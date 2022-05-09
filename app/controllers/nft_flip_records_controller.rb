class NftFlipRecordsController < ApplicationController
  def index
    @records = NftFlipRecord.order(roi: :desc).page(params[:page]).per(10)
  end
end
