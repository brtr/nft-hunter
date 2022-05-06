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
        if data["cursor"].present?
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
  end
end