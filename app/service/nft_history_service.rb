require 'open-uri'

class NftHistoryService
  class << self
    def fetch_pricefloor_nfts
      except_nfts = ["gutter-dogs", "mutant-ape-yacht-club", "cyberkongz-vx", "ikb-cachet-de-garantie", "neo-tokyo-outer-identities", "furballs", "boss-beauties",
        "swampverse", "neo-tokyo-part-4-land-deeds", "neo-tokyo-part-3-item-caches", "party-degenerates", "fluf-world-thingies", "doge-pound-puppies", "cool-cats",
        "bored-ape-kennel-club", "forgotten-runes-wizards-cult", "neo-tokyo-identities", "punks-comic", "ape-kids-club", "cryptomories", "party-ape-billionaire-club",
        "sappy-seals", "meta-legends", "nftrees", "uwucrew", "nouns", "galacticapes", "anonymice", "crypto-bull-society", "dapper-dinos-nft", "divine-anarchy", "888-inner-circle"]
      nfts = []
      result = get_pricefloor_data rescue []
      if result.any?
        result.each do |asset|
          slug = asset["slug"]
          puts slug
          nfts.push(slug)
          nft = Nft.where(slug: slug, chain_id: 1).first
          next if slug.blank? || nft.blank?
          nft.update(total_supply: asset["totalSupply"]) unless except_nfts.include?(slug)
          listed_ratio = asset["listedRatio"]
          listed = nft.total_supply / listed_ratio
          nft.update(listed_ratio: listed_ratio, listed: listed, floor_cap: asset["floorCapUSD"], eth_floor_cap: asset["floorCapETH"],
                    variation: asset["variationUSD"], opensea_url: asset["url"], opensea_slug: slug)
          sales_data = asset["salesData"]
          h = nft.nft_histories.where(event_date: Date.yesterday).first_or_create
          bchp = cal_bchp(nft)

          h.update(floor_price: asset["floorPriceUSD"], eth_floor_price: asset["floorPriceETH"], sales: sales_data["numberSales24h"],
                  volume: sales_data["sales24hVolumeUSD"], eth_volume: sales_data["sales24hVolumeETH"], bchp: bchp)
        end

        (Nft.all.pluck(:slug) - nfts.uniq.compact).each do |slug|
          nft = Nft.find_by slug: slug
          next if nft.blank?
          nft.sync_opensea_stats
        end

        update_data_rank
      else
        puts "Fetch NFTPriceFloor Error: No nfts!"
      end
    end

    def get_pricefloor_data
      response = URI.open("https://api-bff.nftpricefloor.com/nfts").read
      JSON.parse(response)
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

    def get_floor_price_from_moralis(nft)
      url = "https://deep-index.moralis.io/api/v2/nft/#{nft.address}/lowestprice?chain=eth&days=1&marketplace=opensea"
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"], read_timeout: 10}).read rescue nil
      if response
        data = JSON.parse(response)
        price = data["price"].to_f / 10**18
        h = nft.nft_histories.where(event_date: Date.yesterday).first_or_create
        h.update(eth_floor_price: price.to_f)
      end

      generate_nfts_view
    end

    def cal_bchp(nft)
      bchp_nft_ids = Nft.where(is_marked: true).pluck(:id) - [nft.id]
      bchp_owner_ids = OwnerNft.where(event_date: Date.yesterday, nft_id: bchp_nft_ids).pluck(:owner_id).uniq
      bchp_owners = nft.total_owners.where(owner_id: bchp_owner_ids)
      bchp = nft.total_owners.size == 0 ? 0 : (bchp_owners.size / nft.total_owners.size.to_f) * 100
    end

    def get_data_from_trades(nft_id)
      trades = NftTrade.where(nft_id: nft_id).group_by{|t| t.trade_time.to_date}.sort_by{|k,v| k}
      trades.each do |date, trades|
        h = NftHistory.where(nft_id: nft_id, event_date: date).first_or_create
        h.update(sales: trades.size)
      end
    end
  end
end