class NftsView < ApplicationRecord
  self.table_name = 'nfts_view'

  has_many :nft_histories, primary_key: :nft_id, foreign_key: :nft_id
  belongs_to :nft
end