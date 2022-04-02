module API
  module V1
    class Nfts < Grape::API
      resource :nfts do
        desc 'Get target NFT price data'
        get :price_data do
          nft = Nft.where(slug: params[:slug]).take
          data = NftHistory::PriceChartService.new(start_date: 7.days.ago.to_date, nft_id: nft.id).get_price_data rescue {}

          present :result, true
          present :data, data, with: Grape::Presenters::Presenter
          present :status, 200
        end
      end
    end
  end
end