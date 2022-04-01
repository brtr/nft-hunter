class FetchOwnersDataJob < ApplicationJob
  queue_as :daily_job

  def perform
    NftOwnerService.fetch_owners
    NftOwnerService.fetch_target_nft_owners_data(1)
  end
end
