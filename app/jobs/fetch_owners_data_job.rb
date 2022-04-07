class FetchOwnersDataJob < ApplicationJob
  queue_as :daily_job

  def perform
    NftOwnerService.fetch_owners("auto")
  end
end