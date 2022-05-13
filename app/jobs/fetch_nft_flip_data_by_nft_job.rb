class FetchNftFlipDataByNftJob < ApplicationJob
  queue_as :daily_job

  def perform(nft)
    NftHistoryService.fetch_flip_data_by_nft(nft: nft)
  end
end