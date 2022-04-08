class FetchTargetNftOwnerHistoryJob < ApplicationJob
  queue_as :daily_job

  def perform
    NftOwnerService.fetch_target_nft_owners_purchase(1)
    Nft.all.each do |nft|
      NftOwnerService.get_target_owners_ratio(nft.id)
      sleep 2
      NftOwnerService.get_target_owners_trades(nft.id)
      sleep 2
    end
  end
end