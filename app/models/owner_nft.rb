class OwnerNft < ApplicationRecord
  belongs_to :owner
  belongs_to :nft

  serialize :token_ids
end
