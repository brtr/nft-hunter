module NftsHelper
  def logo_path(slug, logo)
    if logo
      logo
    elsif slug
      "https://s3.amazonaws.com/cdn.nftpricefloor/projects/v1/#{slug}.png"
    else
      "default.png"
    end
  end

  def listed_and_supply_radio(supply, listed_ratio)
    listed = supply * listed_ratio / 100 rescue 0
    "#{listed.to_i} / #{supply.to_i} (#{listed_ratio.to_f.round(2)}%)"
  end

  def get_chain_name(chain_id)
    case chain_id
    when 1
      "Ethereum"
    when 56
      "Bsc"
    when 137
      "Polygon"
    when 250
      "Fantom"
    when 43114
      "Avalanche"
    else
      ""
    end
  end

  def change_text_color(num)
    if num > 0
      "success"
    elsif num < 0
      "danger"
    else
      "dark"
    end
  end

  def get_count_ratio(nft)
    count = nft.tokens_count
    ratio = (count.to_f / nft.total_supply)
    "#{count} (#{(ratio * 100).round(2)}%)"
  end

  def get_purchase_data(nft, data)
    owners_count = NftPurchaseHistory.without_target_nfts.last_24h.where(nft_id: nft.nft_id).pluck(:owner_id).uniq.size
    tokens_count = data[nft.nft_id]
    ratio = (tokens_count.to_f / nft.total_supply)
    {
      token_ratio: "#{tokens_count} (#{(ratio * 100).round(2)}%)",
      owners_count: owners_count
    }
  end

  def fetch_purchase_history_data(data)
    result = {total_count: 0, data: []}
    result[:total_count] = data.sum{|d| d[:total_count]}
    result[:data] = data.map{|x| x[:data]}.flatten.reduce({}) do |sums, location|
      sums.merge(location) { |_, a, b| a + b }
    end

    result
  end
end
