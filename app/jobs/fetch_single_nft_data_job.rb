class FetchSingleNftDataJob < ApplicationJob
  queue_as :default

  def perform(nft_id, date=Date.yesterday)
    nft = Nft.find nft_id
    nft.sync_opensea_stats
    nft.fetch_covalent_histories
    sleep 2
    nft.fetch_owners(mode: "auto", date: date)
    sleep 2
    target_owners = NftOwnerService.get_target_owners(date)
    NftOwnerService.fetch_purchase_histories(nft, 1, target_owners)
    sleep 2
    NftOwnerService.get_target_owners_ratio(nft.id)
    sleep 2
    NftOwnerService.get_target_owners_trades(nft.id)
  end
end