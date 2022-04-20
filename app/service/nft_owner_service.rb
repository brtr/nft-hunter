require 'open-uri'

class NftOwnerService
  class << self
    def get_target_owners_ratio(nft_id, date=Date.yesterday)
      owners = OwnerNft.where(nft_id: nft_id, event_date: date)

      result = {total_count: owners.size, bch_count: [], data: {}}
      target_nfts.each do |nft|
        next if nft.id == nft_id
        target_owners = OwnerNft.where(nft_id: nft.id, event_date: date).pluck(:owner_id)
        data = owners.select{|o| target_owners.include?(o.owner_id)}

        if data.any?
          ratio = owners.count == 0 ? 0 : data.count / target_owners.count.to_f
          result[:bch_count].push(data.pluck(:owner_id).compact)
          result[:data].merge!(
            {
              nft.slug => {
                tokens_count: data.sum(&:amount),
                owners_count: data.count,
                owners_ratio: (ratio * 100).round(2),
                logo: nft.logo
              }
            }
          )
        end
      end
      result[:bch_count] = result[:bch_count].flatten.uniq.size

      t = TargetNftOwnerHistory.where(nft_id: nft_id, event_date: date, n_type: "holding").first_or_create
      t.update(data: result)
    end

    def get_target_owners_trades(nft_id, date=Date.yesterday)
      trades = NftTrade.where(nft_id: nft_id, trade_time: [date.at_beginning_of_day..date.at_end_of_day])
      owners = OwnerNft.joins(:owner).where(nft_id: nft_id, event_date: date, owner: {address: trades.pluck(:buyer)})
      result = {total_count: owners.size, bch_count: [], tokens_count: 0}

      target_nfts.each do |nft|
        next if nft.id == nft_id
        target_owners = OwnerNft.where(nft_id: nft.id, event_date: date).map{|o| o.owner_id}.uniq
        data = owners.select{|o| target_owners.include?(o.owner_id)}

        if data.any?
          result[:bch_count].push(data.pluck(:id).compact)
          result[:tokens_count] += data.size
        end
      end

      result[:bch_count] = result[:bch_count].flatten.uniq.size

      t = TargetNftOwnerHistory.where(nft_id: nft_id, event_date: date, n_type: "purchase").first_or_create
      t.update(data: result)
    end

    def target_nfts
      Nft.where(is_marked: true)
    end

    def get_target_owners_rank(date=Date.yesterday)
      result = []
      target_ids = Nft.where(is_marked: true).pluck(:id)
      owner_ids = OwnerNft.where(event_date: date, nft_id: target_ids).pluck(:owner_id).uniq
      NftsView.all.each do |nft|
        next if target_ids.include?(nft.nft_id)
        owners = nft.owner_nfts.where(event_date: date, owner_id: owner_ids)
        tokens_count = owners.sum(&:amount) rescue 0
        owners_count = owners.size rescue 0

        result.push(
          {
            nft_id: nft.nft_id,
            nft: nft,
            tokens_count: tokens_count,
            owners_count: owners_count
          }
        )
      end

      result.sort_by{|r| r[:tokens_count]}.reverse.first(10)
    end

    def get_target_owners(date=Date.yesterday)
      OwnerNft.includes(:owner).where(event_date: date, nft_id: target_nfts.pluck(:id)).map{|o| [o.owner.address, o.owner_id]}.uniq.to_h
    end

    def fetch_purchase_histories(nft)
      target_owners = get_target_owners
      owners_address = target_owners.keys
      nft.nft_trades.group_by{|t| [t.buyer, t.trade_time]}.each do |k, v|
        if owners_address.include?(k[0])
          h = nft.nft_purchase_histories.where(owner_id: target_owners[k[0]], purchase_date: k[1]).first_or_create
          h.update(amount: v.count)
        end
      end
    end

    def fetch_owners(nft_id: nil, mode: "manual", date: Date.today)
      nft = Nft.find nft_id
      return if nft.nil? || nft.owner_nfts.where(event_date: date).sum(:amount).to_f == nft.total_supply.to_f
      puts nft.name
      nft.fetch_owners(mode: mode, date: date)
    end

    def holding_time_median(nft_id)
      end_at = DateTime.now
      start_at = (end_at - 1.month).at_beginning_of_day

      result = {}
      NftTrade.where(nft_id: nft_id, trade_time: [start_at..end_at]).order(trade_time: :asc).group_by{|t| t.token_id}.each do |token_id, trades|
        trades.each do |trade|
          result[trade.buyer] ||= trade.trade_time
          if result.keys.include?(trade.seller)
            result[trade.seller] = trade.trade_time - result[trade.seller]
          end
        end
      end

      values = result.values.select{|v| v.is_a?(Float)}
      median = values.size == 0 ? 0 : cal_median(values)

      h = NftHistory.where(nft_id: nft_id, event_date: Date.today).first_or_create
      h.update(median: (median.to_f / 86400).round(2))
    end

    def get_address(address)
      return address if address.match(/^0x[a-fA-F0-9]{40}$/)
      url = "https://deep-index.moralis.io/api/v2/resolve/#{address}?currency=eth"

      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"], read_timeout: 10}).read rescue nil
      if response
        data = JSON.parse(response)
        return data["address"]
      else
        return nil
      end
    end

    private
    def cal_median(arr)
      arr.sort!
      len = arr.size
      return arr[len / 2] if len.odd?
      (arr[len / 2] + arr[len / 2 - 1]) / 2.0
    end
  end
end