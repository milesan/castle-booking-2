-- Update auction floor prices to new values
-- Tower Suite: €15,000 → €3,000 (was €800)
-- Noble Quarter: €10,000 → €2,000 (was €600)
-- Standard Chamber: €5,000 → €1,000 (was €400)

-- Update auction_config table if needed (set price_drop_interval to 24 hours for daily drops)
UPDATE public.auction_config 
SET 
  price_drop_interval_hours = 24,  -- Daily drops instead of hourly
  updated_at = NOW()
WHERE id = (SELECT id FROM public.auction_config LIMIT 1);

-- Update floor prices for Tower Suite tier
UPDATE public.accommodations 
SET 
  auction_floor_price = 3000,
  updated_at = NOW()
WHERE auction_tier = 'tower_suite';

-- Update floor prices for Noble Quarter tier
UPDATE public.accommodations 
SET 
  auction_floor_price = 2000,
  updated_at = NOW()
WHERE auction_tier = 'noble_quarter';

-- Update floor prices for Standard Chamber tier
UPDATE public.accommodations 
SET 
  auction_floor_price = 1000,
  auction_start_price = 5000,  -- Also fix start price from 6000 to 5000
  auction_current_price = CASE 
    WHEN auction_current_price = 6000 THEN 5000  -- Update current price if it's still at old start price
    ELSE auction_current_price
  END,
  updated_at = NOW()
WHERE auction_tier = 'standard_chamber';

-- Verify the updates
SELECT 
  auction_tier,
  COUNT(*) as room_count,
  MIN(auction_start_price) as min_start_price,
  MAX(auction_start_price) as max_start_price,
  MIN(auction_floor_price) as min_floor_price,
  MAX(auction_floor_price) as max_floor_price
FROM public.accommodations 
WHERE auction_tier IS NOT NULL
GROUP BY auction_tier
ORDER BY auction_tier;

-- Show sample of rooms in each tier
SELECT 
  title,
  auction_tier,
  auction_start_price,
  auction_floor_price,
  auction_current_price,
  is_in_auction
FROM public.accommodations 
WHERE auction_tier IS NOT NULL
ORDER BY auction_tier, title
LIMIT 10;

-- Check auction config
SELECT * FROM public.auction_config;