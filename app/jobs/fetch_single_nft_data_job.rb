class FetchSingleNftDataJob < ApplicationJob
  queue_as :default

  def perform(nft_id, date=Date.yesterday)
    nft = Nft.find nft_id
    nft.sync_opensea_stats
    sleep 2
    FetchSingleNftTradesJob.perform_later(nft.id)
    NftHistoryService.get_data_from_trades(nft.id)
    sleep 2
    FetchOwnersDataJob.perform_later(nft.id)
    sleep 2
    target_owners = NftOwnerService.get_target_owners(date)
    NftOwnerService.fetch_purchase_histories(nft, 1, target_owners)
    sleep 2
    NftOwnerService.get_target_owners_ratio(nft.id)
    sleep 2
    NftOwnerService.get_target_owners_trades(nft.id)
  end
end