class FetchOwnersDataJob < ApplicationJob
  queue_as :daily_job

  def perform
    NftOwnerService.fetch_target_nft_owners_data(1)
    NftOwnerService.fetch_owners
  end
end
