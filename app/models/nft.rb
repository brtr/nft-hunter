require 'open-uri'

class Nft < ApplicationRecord
  has_many :nft_histories, autosave: true
  has_many :owner_nfts
  has_many :owners, through: :owner_nfts
  has_many :nft_purchase_histories, autosave: true
  has_many :target_nft_owner_histories, autosave: true
  has_many :nft_trades, autosave: true
  has_many :nft_transfers, autosave: true

  def fetch_pricefloor_histories
    response = URI.open("https://api-bff.nftpricefloor.com/nft/#{slug}/chart/pricefloor?interval=all", {read_timeout: 20}).read rescue nil
    if response
      data = JSON.parse(response)
      dates = data["dates"]
      if dates.any?
        dates.each_with_index do |el, idx|
          date = DateTime.parse el
          next unless date == date.at_beginning_of_day
          h = nft_histories.where(event_date: date).first_or_create
          h.update(floor_price: data["dataPriceFloorUSD"][idx], eth_floor_price: data["dataPriceFloorETH"][idx], sales: data["sales"][idx],
                  volume: data["dataVolumeUSD"][idx], eth_volume: data["dataVolumeETH"][idx])
        end
      else
        puts "Fetch price floor histories Error: #{name} does not have history data!"
      end
    else
      puts "Fetch price floor histories Error: #{name} 502 Bad Gateway!"
    end
  end

  def fetch_owners(mode: "manual", cursor: nil, date: Date.today)
    return unless address
    begin
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/owners?chain=eth&format=decimal"
      url += "&cursor=#{cursor}" if cursor
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["result"].group_by{|x| x["owner_of"]}.inject({}){|sum, x| sum.merge({x[0] => x[1].map{|y| y["token_id"]}})}
        puts "#{name} has #{result.count} owners"
        result.each do |address, token_ids|
          owner = Owner.where(address: address).first_or_create
          owner_nft = owner.owner_nfts.where(nft_id: self.id, event_date: date).first_or_create(amount: 0, token_ids: [])
          token_ids = owner_nft.token_ids | token_ids
          owner_nft.update(amount: token_ids.count, token_ids: token_ids)
        end

        self.update(updated_at: Time.now)
        sleep 1
        fetch_owners(mode: mode, cursor: data["cursor"], date: date) if data["cursor"].present?
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Fetch Owner", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch moralis Error: #{name} can't fetch owners"
    end
  end

  def sync_opensea_stats(mode="manual")
    return unless opensea_slug

    begin
      url = "https://api.opensea.io/api/v1/collection/#{opensea_slug}/stats"
      response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["stats"]

        self.update(total_supply: result["count"], total_volume: result["total_volume"], eth_floor_cap: result["market_cap"], variation: 0)
        bchp = NftHistoryService.cal_bchp(self)
        h = nft_histories.where(event_date: Date.yesterday).first_or_create
        if h.bchp_12h.present?
          h.update(bchp: bchp, bchp_12h: h.bchp)
        else
          h.update(bchp_12h: bchp)
        end
        h.update(eth_floor_price: result["floor_price"], eth_volume: result["one_day_volume"], sales: result["one_day_sales"])
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Opensea Stats", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch opensea Error: #{name} can't sync stats"
    end
  end

  def sync_moralis_trades(date=Date.today)
    transfers = nft_transfers.where(block_timestamp: [date.at_beginning_of_day..date.at_end_of_day])
    transfers.each do |trade|
      price = trade.value.to_f / 10**18 rescue 0
      next if price == 0 || trade.from_address.in?([ENV["NFTX_ADDRESS"], ENV["SWAP_ADDRESS"]]) || trade.to_address.in?([ENV["NFTX_ADDRESS"], ENV["SWAP_ADDRESS"]])
      nft_trades.where(token_id: trade.token_id, trade_time: trade.block_timestamp, seller: trade.from_address,
          buyer: trade.to_address, trade_price: price).first_or_create
    end
  end

  def total_owners
    owner_nfts
  end

  def sync_opensea_info(mode="manual")
    return unless address

    begin
      url = "https://api.opensea.io/api/v1/asset_contract/#{address}"
      response = URI.open(url, {"X-API-KEY" => ENV["OPENSEA_API_KEY"]}).read
      if response
        data = JSON.parse(response)

        slug = data["collection"]["slug"]
        self.update(chain_id: 1, name: data["name"], slug: slug, opensea_slug: slug, logo: data["image_url"], opensea_url: "https://opensea.io/collection/#{slug}")
      end
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Opensea Info", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch opensea Error: #{name} can't sync info"
    end
  end

  def sync_moralis_transfers(mode="manual", cursor=nil)
    return unless address

    begin
      url = "https://deep-index.moralis.io/api/v2/nft/#{address}/transfers?chain=eth&format=decimal"
      url += "&cursor=#{cursor}" if cursor
      response = URI.open(url, {"X-API-Key" => ENV["MORALIS_API_KEY"]}).read
      if response
        data = JSON.parse(response)
        result = data["result"]
        if result.any?
          result.each do |transfer|
            nft_transfers.where(token_id: transfer["token_id"], block_timestamp: transfer["block_timestamp"], from_address: transfer["from_address"],
                                to_address: transfer["to_address"], value: transfer["value"], block_hash: transfer["block_hash"],
                                block_number: transfer["block_number"], amount: transfer["amount"]).first_or_create
          end
        end
      end

      # size = data["page_size"].to_i * data["page"].to_i + 501
      # sync_moralis_transfers(mode, data["cursor"]) if data["cursor"].present? && nft_transfers.count < size
    rescue => e
      FetchDataLog.create(fetch_type: mode, source: "Sync Moralis Transfers", url: url, error_msgs: e, event_time: DateTime.now)
      puts "Fetch moralis Error: #{name} can't sync transfers"
    end
  end

  def get_owners(date=Date.yesterday)
    transfers = nft_transfers.where(block_timestamp: [date.at_beginning_of_day..date.at_end_of_day])
    transfers.each do |transfer|
      owner_nfts.includes(:owner).where(owner: {address: transfer.from_address}).take&.destroy
      owner = Owner.where(address: transfer.to_address).first_or_create
      owner_nft = owner.owner_nfts.where(nft_id: self.id).first_or_create(amount: 0, token_ids: [], event_date: date)
      token_ids = owner_nft.token_ids | [transfer.token_id]
      owner_nft.update(amount: token_ids.count, token_ids: token_ids)
    end
  end
end
