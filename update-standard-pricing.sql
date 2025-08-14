-- Update Standard Chamber pricing for Dutch Auction
-- Changes: Start price from €5,000 to €4,800, Floor price from €1,000 to €800
-- Daily reduction: €133/day over 30 days

-- Update auction_config to reflect daily price drops (24 hours instead of 1 hour)
UPDATE auction_config 
SET 
  price_drop_interval_hours = 24  -- Changed from 1 hour to 24 hours for daily reductions
WHERE id = (SELECT id FROM auction_config LIMIT 1);

-- Update Standard Chamber accommodations with new pricing
UPDATE accommodations 
SET 
  auction_start_price = 4800,   -- Changed from 5000
  auction_floor_price = 800,    -- Changed from 1000
  auction_current_price = 4800  -- Reset to new start price
WHERE 
  auction_tier = 'standard_chamber' 
  AND is_in_auction = true;

-- Clear any existing purchases for Standard Chamber to reset the auction
UPDATE accommodations 
SET 
  auction_buyer_id = NULL,
  auction_purchase_price = NULL,
  auction_purchased_at = NULL
WHERE 
  auction_tier = 'standard_chamber' 
  AND is_in_auction = true;

-- Log the changes
INSERT INTO auction_history (
  accommodation_id,
  action_type,
  price_at_action,
  created_at
)
SELECT 
  id,
  'price_adjustment',
  4800,
  NOW()
FROM accommodations
WHERE 
  auction_tier = 'standard_chamber' 
  AND is_in_auction = true;