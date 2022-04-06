class TargetNftOwnerHistory < ApplicationRecord
  belongs_to :nft

  serialize :data

  enum n_type: [:holding, :purchase]

  def self.last_day
    date = TargetNftOwnerHistory.order(event_date: :asc).last.event_date
    TargetNftOwnerHistory.where(event_date: date)
  end
end
