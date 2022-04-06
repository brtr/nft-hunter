require 'open-uri'

class NftOwnerService
  class << self
    def get_target_owners_ratio(nft_id, date=Date.yesterday)
      owners = total_owners(nft_id)

      result = {total_count: owners.size, data: {}}
      target_nfts.each do |nft|
        owner_ids = OwnerNft.where(nft_id: nft.id, event_date: date).pluck(:owner_id)
        target_owner_ids = owners.select{|o| owner_ids.include?(o)}
        ratio = owners.count == 0 ? 0 : (target_owner_ids.count.to_f / owners.count.to_f).round(2)

        result[:data].merge!(
          {
            nft.name => {
              owners_count: target_owner_ids.count,
              owners_ratio: (ratio * 100).round(2)
            }
          }
        )
      end

      TargetNftOwnerHistory.where(nft_id: nft_id, event_date: date, n_type: "holding").first_or_create(data: result)
    end

    def total_owners(nft_id, date=Date.yesterday)
      OwnerNft.where(nft_id: nft_id, event_date: date).pluck(:owner_id)
    end

    def fetch_trades(address, duration)
      to_date = Date.today
      from_date = to_date - duration.to_i.days
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/trades?chain=eth&marketplace=opensea&format=decimal&from_date=#{from_date}&to_date=#{to_date}"
      URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"], read_timeout: 10}).read rescue nil
    end

    def get_target_owners_trades(nft_id, date=Date.yesterday)
      result = {total_count: 0, data: {}}

      histories = NftPurchaseHistory.where(nft_id: nft_id, purchase_date: date)

      owners = OwnerNft.where(event_date: date, nft_id: target_nfts.pluck(:id)).includes(:nft).group_by{|o| o.nft.name}.inject({}){|sum, d| sum.merge!({d[0] => d[1].map(&:owner_id)})}
      owners.each do |nft_name, owner_ids|
        purchase_count = histories.select{|h| owner_ids.include?(h.owner_id)}.sum(&:amount)

        result[:total_count] += purchase_count
        result[:data].merge!({nft_name => purchase_count})
      end

      TargetNftOwnerHistory.where(nft_id: nft_id, event_date: date, n_type: "purchase").first_or_create(data: result)
    end

    def target_nfts
      Nft.where(is_marked: true)
    end

    def get_target_owners_rank(date=Date.yesterday)
      result = []
      if result.blank?
        target_ids = target_nfts.pluck(:id)
        owner_ids = OwnerNft.where(event_date: date, nft_id: target_ids).pluck(:owner_id).uniq
        NftsView.includes(:owner_nfts).each do |nft|
          next if target_ids.include?(nft.nft_id)
          tokens_count = nft.owner_nfts.where(owner_id: owner_ids).sum(&:amount)
          owners_count = TargetNftOwnerHistory.holding.where(nft_id: nft.nft_id, event_date: Date.yesterday).take.data[:data].sum{|i| i.values.sum{|y| y[:owners_count]}} rescue 0

          result.push(
            {
              nft_id: nft.nft_id,
              nft: nft,
              tokens_count: tokens_count,
              owners_count: owners_count
            }
          )
        end
      end

      result.sort_by{|r| r[:tokens_count]}.reverse.first(10)
    end

    def fetch_target_nft_owners_data(duration, date=Date.yesterday)
      target_owners = OwnerNft.includes(:owner).where(event_date: date, nft_id: target_nfts.pluck(:id)).uniq.inject({}){|sum, o| sum.merge!({ o.owner.address => o.owner_id})}
      Nft.all.each do |nft|
        response = fetch_trades(nft.address, duration)

        if response
          data = JSON.parse(response) rescue nil
          if data
            data["result"].each do |r|
              owners_address = target_owners.keys
              address = r["buyer_address"]

              if owners_address.include?(address)
                h = nft.nft_purchase_histories.where(owner_id: target_owners[address], purchase_date: r["block_timestamp"]).first_or_create
                h.update(amount: r["token_ids"].count)
              end
            end
          end
        end
      end
    end

    def fetch_owners(mode="manual")
      Nft.where.not(address: nil).each do |nft|
        puts nft.name
        nft.fetch_owners(mode)
        sleep 3
      end
    end
  end
end