-- Update auction configuration to start August 15th, 2025
UPDATE auction_config 
SET 
  auction_start_time = '2025-08-15T00:00:00Z',
  auction_end_time = '2025-09-14T23:59:59Z',
  price_drop_interval_hours = 1,
  is_active = true
WHERE id = (SELECT id FROM auction_config LIMIT 1);

-- Ensure all rooms have the correct tier assignments and starting prices
-- Tower Suites: €15,000 → €3,000
UPDATE accommodations 
SET 
  auction_start_price = 15000,
  auction_floor_price = 3000,
  auction_current_price = 15000
WHERE auction_tier = 'tower_suite' AND is_in_auction = true;

-- Noble Quarters: €10,000 → €2,000  
UPDATE accommodations
SET 
  auction_start_price = 10000,
  auction_floor_price = 2000,
  auction_current_price = 10000
WHERE auction_tier = 'noble_quarter' AND is_in_auction = true;

-- Standard Chambers: €5,000 → €1,000
UPDATE accommodations
SET 
  auction_start_price = 5000,
  auction_floor_price = 1000,
  auction_current_price = 5000  
WHERE auction_tier = 'standard_chamber' AND is_in_auction = true;

-- Clear any previous purchases to reset the auction
UPDATE accommodations
SET 
  auction_buyer_id = NULL,
  auction_purchase_price = NULL,
  auction_purchased_at = NULL
WHERE is_in_auction = true;

-- Verify the settings
SELECT 
  'Auction Config' as type,
  auction_start_time::date as start_date,
  auction_end_time::date as end_date,
  price_drop_interval_hours as drop_interval,
  is_active
FROM auction_config;

SELECT 
  auction_tier as tier,
  COUNT(*) as room_count,
  MIN(auction_start_price) as min_start,
  MAX(auction_start_price) as max_start,
  MIN(auction_floor_price) as min_floor,
  MAX(auction_floor_price) as max_floor
FROM accommodations
WHERE is_in_auction = true AND auction_tier IS NOT NULL
GROUP BY auction_tier
ORDER BY MIN(auction_start_price) DESC;