class NftPurchaseHistory < ApplicationRecord
  belongs_to :nft
  belongs_to :owner
end
