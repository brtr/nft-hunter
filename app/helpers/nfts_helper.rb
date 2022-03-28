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
end
