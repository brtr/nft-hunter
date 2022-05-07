require 'open-uri'
require 'nokogiri'

class NftHistoryService
  class << self
    def fetch_nfts_data
      Nft.where.not(opensea_slug: nil).each do |nft|
        nft.sync_opensea_stats
        sleep 1
      end

      update_data_rank
    end

    def generate_nfts_view
      sql = ERB.new(File.read("app/data_views/nfts_view.sql")).result()
      Nft.connection.execute(sql)
    end

    def update_data_rank(date=Date.yesterday)
      hh = NftHistory.where(event_date: date).select("rank() over (ORDER BY eth_volume desc) cap_rank, id")

      if hh.present?
        sql = "update nft_histories set eth_volume_rank = case id "
        hh.each {|h| sql = sql + " when #{h.id} then #{h.cap_rank} " }
        sql = sql + "end where id in (#{hh.ids.join(',')})"

        NftHistory.connection.execute(sql)
        puts "--------------update #{date.to_s} rank by eth volume--------------"
      else
        puts "-------------- #{date.to_s} no nft_histories --------------"
      end
    end

    def cal_bchp(nft, h)
      bchp_nft_ids = Nft.where(is_marked: true).pluck(:id) - [nft.id]
      bchp_owner_ids = OwnerNft.where(nft_id: bchp_nft_ids).pluck(:owner_id).uniq
      bchp_owners = nft.total_owners.where(owner_id: bchp_owner_ids)
      bchp = nft.total_owners.size == 0 ? 0 : (bchp_owners.size / nft.total_owners.size.to_f) * 100
      bchp_6h = $redis.get("bchp_#{nft.id}") || h.bchp
      bchp_12h = $redis.get("bchp_#{nft.id}_6h") || h.bchp_6h
      h.update(bchp: bchp, bchp_6h: bchp_6h, bchp_12h: bchp_12h)
      $redis.set("bchp_#{nft.id}", bchp)
      $redis.set("bchp_#{nft.id}_6h", bchp_6h)
    end

    def get_data_from_trades(nft_id)
      n = NftsView.find_by(nft_id: nft_id)
      data = NftTrade.where(nft_id: nft_id).group_by{|t| t.trade_time.to_date}.sort_by{|k,v| k}
      data.each do |date, trades|
        floor_price = trades.pluck(:trade_price).select{|i| i > n.eth_floor_price_24h.to_f * 0.2}.min
        volume = trades.sum(&:trade_price)
        h = NftHistory.where(nft_id: nft_id, event_date: date).first_or_create

        h.update(eth_floor_price: floor_price, eth_volume: volume, sales: trades.size)
      end
    end

    def get_latest_block
      response = URI.open("https://deep-index.moralis.io/api/v2/dateToBlock?chain=eth&date=#{Time.now.to_i}", {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        return data["block"]
      else
        0
      end
    end

    def get_data_from_transfers(cursor: nil, mode: "manual", result: [], to_block: nil)
      begin
        to_block ||= get_latest_block
        puts "from_block: #{to_block}"
        from_block = to_block.to_i - 100
        url = "https://deep-index.moralis.io/api/v2/nft/transfers?chain=eth&format=decimal&from_block=#{from_block}&to_block=#{to_block}"
        url += "&cursor=#{cursor}" if cursor
        response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
        data = JSON.parse(response)
        data["result"].each do |r|
          next if r["value"].to_f == 0 || r["contract_type"] != "ERC721" || r["from_address"].in?([ENV["NFTX_ADDRESS"], ENV["SWAP_ADDRESS"]]) || r["to_address"].in?([ENV["NFTX_ADDRESS"], ENV["SWAP_ADDRESS"]])
          result.push(r)
        end

        size = data["page_size"].to_i * data["page"].to_i + 501
        if data["cursor"].present? && data["total"].to_f > size
          get_data_from_transfers(cursor: data["cursor"], mode: mode, result: result, to_block: to_block)
        else
          return result
        end
      rescue => e
        FetchDataLog.create(fetch_type: mode, source: "Fetch Transfer", url: url, error_msgs: e, event_time: DateTime.now)
        puts "Fetch moralis Error: #{e}"
      end
    end

    def fetch_nfts_from_transfer(mode="manual")
      result = []
      get_data_from_transfers(mode: mode, result: result)
      if result.any?
        result.group_by{|r| r["token_address"]}.inject({}){|sum, r| sum.merge({r[0] => r[1].sum{|i| i["amount"].to_i * (i["value"].to_i / 10**18)}})}.select{|k, v| v.to_f > 10}.each do |r|
          Nft.where(address: r[0]).first_or_create
        end
      else
        puts "No Transfers!"
      end
    end

    def fetch_listed_from_opensea(slug, mode="manual")
      url = "https://opensea.io/collection/#{slug}?search[sortAscending]=true&search[sortBy]=PRICE&search[toggles][0]=BUY_NOW"
      begin
        browser = Capybara.current_session
        browser.visit url
        doc = Nokogiri::HTML(browser.html)
        doc.css("p.kejuyj").first.text.split(" ")[0].gsub(/[^\d\.]/, '').to_f
      rescue => e
        FetchDataLog.create(fetch_type: mode, source: "Fetch listed", url: url, error_msgs: e, event_time: DateTime.now)
        puts "Fetch opensea Error: #{e}"
      end
    end

    def fetch_flip_data_by_nft(nft: nil, start_at: nil, mode: "manual", cursor: nil)
      start_at ||= Time.now.at_beginning_of_day.to_i
      url = "https://api.opensea.io/api/v1/events?&asset_contract_address=#{nft.address}&event_type=successful&occurred_after=#{start_at}"
      url += "&cursor=#{cursor}" if cursor
      # begin
      response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        events = data["asset_events"]
        events.each do |event|
          asset = event["asset"]
          next if asset.nil? || asset["num_sales"] < 2 || asset["asset_contract"]["schema_name"] != "ERC721"
          last_trade = fetch_opensea_events(nft.address, asset["token_id"], event["seller"]["address"], mode)
          next unless last_trade.size > 0
          update_flip_record(nft, last_trade, event, asset)
        end

        sleep 1
        fetch_flip_data_by_nft(nft: nft, start_at: start_at, mode: mode, cursor: data["next"]) if data["next"].present?
      end
      # rescue => e
      #   FetchDataLog.create(fetch_type: mode, source: "Fetch flip data", url: url, error_msgs: e, event_time: DateTime.now)
      #   puts "Fetch opensea Error: #{e}"
      # end
    end

    def fetch_opensea_events(token_address, token_id, user_address, mode="manual")
      result = {}
      sleep 1
      begin
        url = "https://api.opensea.io/api/v1/events?token_id=#{token_id}&asset_contract_address=#{token_address}&event_type=successful&account_address=#{user_address}"
        response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
        if response
          data = JSON.parse(response)
          events = data["asset_events"]
          e = events.select{|e| e["winner_account"]["address"] == user_address}.first
          if e
            payment = e["payment_token"]
            cost = e["total_price"].to_f / 10 ** payment["decimals"].to_i
            cost_usd = cost * payment["usd_price"].to_f
            result = {bought_coin: payment["symbol"], cost: cost, cost_usd: cost_usd, from_address: e["seller"]["address"], trade_time: e["created_date"]}
          end
          return result
        end
      rescue => e
        FetchDataLog.create(fetch_type: mode, source: "Sync Opensea Events", url: url, error_msgs: e, event_time: DateTime.now)
        puts "Fetch opensea Error: #{name} can't sync events"
      end
    end

    def fetch_flip_data(start_at: nil, mode: "manual", cursor: nil)
      start_at ||= (Time.now - 1.hour).to_i
      url = "https://api.opensea.io/api/v1/events?only_opensea=true&event_type=successful&occurred_after=#{start_at}"
      url += "&cursor=#{cursor}" if cursor
      begin
        response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
        if response
          data = JSON.parse(response)
          events = data["asset_events"]
          events.each do |event|
            asset = event["asset"]
            next if asset.nil? || asset["num_sales"] < 2 || asset["asset_contract"]["schema_name"] != "ERC721"
            token_address = asset["asset_contract"]["address"]
            last_trade = fetch_opensea_events(token_address, asset["token_id"], event["seller"]["address"], mode)
            next unless last_trade.size > 0
            nft = Nft.where(address: token_address, opensea_slug: asset["collection"]["slug"]).first_or_create
            update_flip_record(nft, last_trade, event, asset)
          end

          sleep 1
          fetch_flip_data(start_at: start_at, mode: mode, cursor: data["next"]) if data["next"].present?
        end
      rescue => e
        FetchDataLog.create(fetch_type: mode, source: "Fetch flip data", url: url, error_msgs: e, event_time: DateTime.now)
        puts "Fetch opensea Error: #{e}"
      end
    end

    private
    def update_flip_record(nft, last_trade, event, asset)
      payment = event["payment_token"]
      price = event["total_price"].to_f / 10 ** payment["decimals"].to_i
      price_usd = price * payment["usd_price"].to_f
      cost_usd = last_trade[:cost_usd]
      revenue = price_usd - cost_usd
      roi = cost_usd == 0 ? 0 : revenue / cost_usd
      gap = DateTime.parse(event["created_date"]).to_i - DateTime.parse(last_trade[:trade_time]).to_i
      r = nft.nft_flip_records.where(slug: nft.opensea_slug, token_address: asset["asset_contract"]["address"], token_id: asset["token_id"], txid: event["transaction"]["transaction_hash"]).first_or_create
      r.update( price: price, price_usd: price_usd, cost: last_trade[:cost], cost_usd: cost_usd, revenue: revenue.round(3), roi: roi.round(3), gap: gap,
                sold_time: event["created_date"], bought_time: last_trade[:trade_time], sold_coin: payment["symbol"], bought_coin: last_trade[:bought_coin],
                from_address: last_trade[:from_address], fliper_address: event["seller"]["address"], to_address: event["winner_account"]["address"])
    end
  end
end