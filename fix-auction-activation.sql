-- Check if auction config exists and its status
SELECT * FROM public.auction_config;

-- If the auction exists but is not active, activate it:
UPDATE public.auction_config 
SET 
  is_active = true,
  auction_start_time = NOW(),
  auction_end_time = '2025-09-14 00:00:00+00'::timestamp with time zone,
  price_drop_interval_hours = 1,
  updated_at = NOW()
WHERE id = (SELECT id FROM public.auction_config LIMIT 1);

-- Verify it's now active
SELECT * FROM public.auction_config;

-- Also check if you have any rooms assigned to tiers
SELECT 
  title,
  auction_tier,
  auction_start_price,
  auction_floor_price,
  auction_current_price,
  is_in_auction
FROM public.accommodations 
WHERE auction_tier IS NOT NULL;

-- If no rooms are assigned to tiers, here's an example to assign some:
-- UPDATE public.accommodations 
-- SET 
--   auction_tier = 'tower_suite',
--   auction_start_price = 15000,
--   auction_floor_price = 800,
--   auction_current_price = 15000,
--   is_in_auction = true
-- WHERE title LIKE '%Suite%' OR title LIKE '%Tower%'
-- LIMIT 8;

-- UPDATE public.accommodations 
-- SET 
--   auction_tier = 'noble_quarter',
--   auction_start_price = 10000,
--   auction_floor_price = 600,
--   auction_current_price = 10000,
--   is_in_auction = true
-- WHERE auction_tier IS NULL AND (title LIKE '%Noble%' OR title LIKE '%Quarter%')
-- LIMIT 12;

-- UPDATE public.accommodations 
-- SET 
--   auction_tier = 'standard_chamber',
--   auction_start_price = 6000,
--   auction_floor_price = 400,
--   auction_current_price = 6000,
--   is_in_auction = true
-- WHERE auction_tier IS NULL
-- LIMIT 8;