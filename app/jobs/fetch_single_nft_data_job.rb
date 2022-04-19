class FetchSingleNftDataJob < ApplicationJob
  queue_as :default

  def perform(nft_id, date=Date.yesterday)
    nft = Nft.find nft_id
    nft.sync_opensea_stats
    sleep 2
    FetchSingleNftTradesJob.perform_later(nft.id)
    sleep 2
    FetchOwnersDataJob.perform_later(nft.id)
    sleep 2
    NftOwnerService.get_target_owners_ratio(nft.id)
    sleep 2
    NftOwnerService.get_target_owners_trades(nft.id)
  end
end