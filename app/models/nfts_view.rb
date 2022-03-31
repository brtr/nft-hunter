class NftsView < ApplicationRecord
  self.table_name = 'nfts_view'
  self.primary_key = 'nft_id'

  has_many :nft_histories, primary_key: :nft_id, foreign_key: :nft_id
  has_many :owner_nfts, primary_key: :nft_id, foreign_key: :nft_id
  has_many :owners, through: :owner_nfts
  has_many :nft_purchase_histories, primary_key: :nft_id, foreign_key: :nft_id
  belongs_to :nft
end