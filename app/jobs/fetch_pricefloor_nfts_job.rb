class FetchPricefloorNftsJob < ApplicationJob
  queue_as :daily_job

  def perform
    NftHistoryService.fetch_pricefloor_nfts
    NftHistoryService.generate_nfts_view
  end
end