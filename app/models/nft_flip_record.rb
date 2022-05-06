class NftFlipRecord < ApplicationRecord
  belongs_to :nft, touch: true
end
