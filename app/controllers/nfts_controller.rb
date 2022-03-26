class NftsController < ApplicationController
  before_action :get_nft, except: :index
  def index
    @page_index = 1
    @page = params[:page].to_i || 1
    sort_by = params[:sort_by] || "floor_cap" 
    @sort = params[:sort] == "desc" ? "asc" : "desc"
    @nfts = NftsView.order("#{sort_by} #{@sort}").page(@page).per(50)
  end

  def show
    @data = NftHistory::PriceChartService.new(start_date: period_date, nft_id: @nft.nft_id).get_price_data
  end

  private
  def get_nft
    @nft = NftsView.find_by nft_id: params[:id]
  end

  def period_date
    case params[:period]
    when "month" then Date.today.last_month.to_date
    when "year" then Date.today.last_year.to_date
    else 7.days.ago.to_date
    end
  end
end
