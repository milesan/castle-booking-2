-- Add new 4M Bell Tent, Castle View accommodation
-- Using only columns that actually exist in the accommodations table

-- First, add the new Bell Tent with Castle View
INSERT INTO accommodations (
  title,
  type,
  base_price,
  capacity,
  inventory,
  image_url,
  has_wifi,
  has_electricity,
  bathroom_type,
  is_fungible
) VALUES (
  '4M Bell Tent, Castle View',
  'bell-tent',
  1000, -- €1000 price
  2,
  3, -- Only 3 available
  'https://storage.tally.so/f385d036-6b48-4a0b-b119-2e334c0bc1f0/photo_2023-09-07_18-55-18.jpg',
  false,
  false,
  'shared',
  true
) ON CONFLICT (title) DO UPDATE SET
  base_price = EXCLUDED.base_price,
  inventory = EXCLUDED.inventory;

-- Update inventory for regular 4M Bell Tents to 35
UPDATE accommodations 
SET inventory = 35
WHERE (title = '4 Meter Bell Tent' OR title = '4m Bell Tent')
  AND type = 'bell-tent';

-- Update inventory for Tipis to 20
UPDATE accommodations 
SET inventory = 20
WHERE (title = 'Single Tipi' OR title LIKE '%Tipi%')
  AND type = 'tipi';

-- Create accommodation items for the new Castle View Bell Tent
DO $$
DECLARE
  acc_id UUID;
  item_count INT;
BEGIN
  -- Get the accommodation ID
  SELECT id INTO acc_id 
  FROM accommodations 
  WHERE title = '4M Bell Tent, Castle View'
  LIMIT 1;
  
  IF acc_id IS NOT NULL THEN
    -- Check if items already exist
    SELECT COUNT(*) INTO item_count
    FROM accommodation_items
    WHERE accommodation_id = acc_id;
    
    -- Only create if they don't exist
    IF item_count = 0 THEN
      -- Create 3 accommodation items for the Castle View Bell Tent
      INSERT INTO accommodation_items (accommodation_id, item_number, display_name)
      VALUES 
        (acc_id, 1, '4M Bell Tent Castle View #1'),
        (acc_id, 2, '4M Bell Tent Castle View #2'),
        (acc_id, 3, '4M Bell Tent Castle View #3');
    END IF;
  END IF;
END $$;