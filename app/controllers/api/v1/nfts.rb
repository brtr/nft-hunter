module API
  module V1
    class Nfts < Grape::API
      resource :nfts do
        desc 'Get target NFT price data and owners data'
        get :data do
          nft = Nft.where(slug: params[:slug]).take
          price_data = NftHistory::PriceChartService.new(start_date: 7.days.ago.to_date, nft_id: nft.id).get_price_data rescue {}
          owners_data = NftOwnerService.get_target_owners_ratio(nft.id) rescue []
          data = {
            price_data: price_data,
            owners_data: owners_data
          }

          present :result, true
          present :data, data, with: Grape::Presenters::Presenter
          present :status, 200
        end
      end
    end
  end
end