class TargetNftOwnerHistory < ApplicationRecord
  belongs_to :nft

  serialize :data

  enum n_type: [:holding, :purchase]
end
