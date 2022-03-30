DROP MATERIALIZED VIEW IF EXISTS nfts_view;
CREATE MATERIALIZED VIEW nfts_view AS
    WITH histories_24h AS (
      SELECT 
        nft_id, 
        event_date, 
        floor_price,
        volume,
        sales
      FROM nft_histories
      WHERE event_date = CURRENT_DATE - interval '1 day'
    ), results AS (
      SELECT 
      n.id::INTEGER as nft_id,
      n.chain_id,
      n.name,
      n.slug,
      n.logo,
      n.address,
      n.opensea_url,
      n.total_supply,
      n.floor_cap,
      n.listed_ratio,
      ROUND(n.variation, 2) as variation,
      n2.sales as sales_24h,
      n2.floor_price as floor_price_24h,
      n2.volume as volume_24h
      FROM nfts as n
      LEFT JOIN histories_24h as n2 on n2.nft_id = n.id
    )
    SELECT * FROM results;

CREATE INDEX nft_id_on_nfts_view             ON nfts_view USING BTREE(nft_id);
CREATE INDEX name_on_nfts_view               ON nfts_view USING BTREE(name);
CREATE UNIQUE INDEX unique_id_name_nfts_view ON nfts_view USING BTREE(nft_id, name);
