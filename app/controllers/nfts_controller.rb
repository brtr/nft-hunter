class NftsController < ApplicationController
  before_action :get_nft, except: :index
  def index
    @page_index = 0
    @page = params[:page].to_i || 1
    sort_by = params[:sort_by] || "floor_cap" 
    @sort = params[:sort] == "desc" ? "asc" : "desc"
    @nfts = NftsView.order("#{sort_by} #{@sort}").page(@page).per(50)
  end

  def show
    @total_owners = NftOwnerService.total_owners(@nft.nft_id).size
    @owners_data = NftOwnerService.get_target_owners_ratio(@nft.nft_id)
    @result_24h = NftOwnerService.get_target_owners_trades(@nft.address, 1)
    @result_7d = NftOwnerService.get_target_owners_trades(@nft.address, 7)
    @data = NftHistory::PriceChartService.new(start_date: period_date, nft_id: @nft.nft_id).get_price_data
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
    @data = NftPurchaseHistory.without_target_nfts.last_24h.group(:nft_id).count.map{|k, v| [k, v]}.sort_by{|k, v| v}.reverse.first(10).to_h
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
