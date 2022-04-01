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
    listed = supply * listed_ratio rescue 0
    "#{listed.to_i} / #{supply} (#{listed_ratio.to_f.round(2)}) %"
  end

  def get_rank(idx, page)
    rank = idx + 1
    rank = rank + 50 * (page - 1) if page > 1
    rank
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

  def get_count_ratio(data, nft)
    count = data[nft.nft_id.to_s]
    ratio = (count.to_f / nft.total_supply)
    "#{count} (#{(ratio * 100).round(2)}%)"
  end

  def get_owners_count(nft, d_type="holding")
    if d_type == "purchase"
      NftPurchaseHistory.without_target_nfts.last_24h.where(nft_id: nft.nft_id).pluck(:owner_id).uniq.size
    else
      NftOwnerService.get_target_owners_ratio(nft.nft_id).sum{|r| r[:owners_count]}
    end
  end
end
