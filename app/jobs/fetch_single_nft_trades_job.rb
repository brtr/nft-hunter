class FetchSingleNftTradesJob < ApplicationJob
  queue_as :owner_daily_job

  def perform(nft_id)
    nft = Nft.find_by id: nft_id
    nft.sync_moralis_trades
  end
end