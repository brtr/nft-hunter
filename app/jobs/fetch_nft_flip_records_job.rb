class FetchNftFlipRecordsJob < ApplicationJob
  queue_as :daily_job

  NFTS = ["bored-ape-kennel-club", "autoglyphs", "pegz", "azuki", "rtfkt-nike-cryptokicks",
          "ikb-cachet-de-garantie", "bored-ape-yacht-club", "beanz-official", "colorglyphs",
          "nouns", "tom-sachs-rockets", "wolfgamelegacy", "cryptopunks", "meebits",
          "mutant-ape-yacht-club", "fvck-crystal", "10ktf", "cryptoadz", "gutter-cat-gang",
          "mclarenmsolabgenesis", "otherdeed", "proof-moonbirds", "doodles",
          "okay-bears", "mous-in-da-hous", "communi3-mad-scientists"]

  def perform
    NFTS.each do |slug|
      n = Nft.find_by(slug: slug)
      FetchNftFlipDataByNftJob.perform_later(n) if n.present?
    end
  end
end