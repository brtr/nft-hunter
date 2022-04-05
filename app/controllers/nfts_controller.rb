class NftsController < ApplicationController
  before_action :get_nft, except: :index
  def index
    @page_index = 0
    @page = params[:page].to_i || 1
    sort_by = params[:sort_by] || "eth_volume_24h"
    @sort = params[:sort] == "desc" ? "asc" : "desc"
    @nfts = NftsView.order("#{sort_by} #{@sort}").page(@page).per(50)
  end

  def show
    date = Date.yesterday
    yesterday_histories = @nft.target_nft_owner_histories.where(event_date: date)
    @owners_data = yesterday_histories.holding.take.data
    @purchase_24h = yesterday_histories.purchase.take.data
    @purchase_7d = @nft.target_nft_owner_histories.purchase.where(event_date: [date - 7.days..date]).map(&:data)
    @price_data = PriceChartService.new(start_date: period_date, nft_id: @nft.nft_id).get_price_data
    @holding_data = PriceChartService.new(start_date: period_date, nft_id: @nft.nft_id).get_holding_data
    @purchase_data = PriceChartService.new(start_date: period_date, nft_id: @nft.nft_id).get_purchase_data
  end

  def new
    @nft = Nft.new
  end

  def create
    nft = Nft.new(nft_params)
    if nft.address.match(/^0x[a-fA-F0-9]{40}$/)
      unless nft.fetch_pricefloor_nft
        nft.fetch_covalent_histories
      end

      NftHistoryService.generate_nfts_view

      redirect_to nfts_path, notice: "Add NFT successful!"
    else
      flash[:alert] = "Invalid address!"
      @nft = Nft.new

      render :new
    end
  end

  def purchase_rank
    @page_index = 1
    @data = NftPurchaseHistory.without_target_nfts.last_day.group(:nft_id).count.map{|k, v| [k, v]}.sort_by{|k, v| v}.reverse.first(10).to_h
    @nfts = NftsView.find(@data.keys)
  end

  def holding_rank
    @page_index = 2
    snap_shot = HoldingRankSnapShot.last
    @nfts = snap_shot.holding_rank_snap_shot_views
  end

  private
  def get_nft
    @nft = NftsView.find_by slug: params[:id]
  end

  def period_date
    case params[:period]
    when "month" then Date.today.last_month.to_date
    when "year" then Date.today.last_year.to_date
    else 7.days.ago.to_date
    end
  end

  def nft_params
    params.require(:nft).permit(:name, :slug, :address)
  end
end
