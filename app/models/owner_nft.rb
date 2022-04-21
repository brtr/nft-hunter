class OwnerNft < ApplicationRecord
  belongs_to :owner
  belongs_to :nft, touch: true

  serialize :token_ids
end
