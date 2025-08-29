-- Add accommodation_items for all castle rooms
-- Each room gets one item since they are unique accommodations

BEGIN;

-- ========================================
-- RENAISSANCE ROOMS
-- ========================================

-- Mezzanine Level
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'REN-MEZ' as size,
  1 as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Épis', 'Fauconnier', 'Louis XIII')
ON CONFLICT DO NOTHING;

-- First Floor
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'REN-1F' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Grand Condé', 'Lierre I', 'Lierre II', 'Restauration', 'Tulipe')
ON CONFLICT DO NOTHING;

-- Second Floor
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'REN-2F' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Biche', 'Petit Condé', 'Saint André I', 'Saint André II', 'Saint André III')
ON CONFLICT DO NOTHING;

-- Attic
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'REN-ATT' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Charlotte de Montmorency', 'Henri IV', 'Pierre Lescot')
ON CONFLICT DO NOTHING;

-- ========================================
-- MEDIEVAL ROOMS
-- ========================================
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'MED' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Chouette', 'Dame Blanche', 'Grand Duc', 'Petit Duc')
ON CONFLICT DO NOTHING;

-- ========================================
-- ORIENTAL ROOMS
-- ========================================
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'ORI' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Levant room', 'Loft nuptial suite', 'Sahara room')
ON CONFLICT DO NOTHING;

-- ========================================
-- PALM GROVE ROOMS
-- ========================================
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'PALM' as size,
  row_number() OVER (ORDER BY title) as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title IN ('Darjeeling', 'Figuier', 'Nirvana', 'Samsara')
ON CONFLICT DO NOTHING;

-- ========================================
-- DOVECOTE (if it exists)
-- ========================================
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  id,
  NULL as zone,
  'ROOM' as type,
  'DOVE' as size,
  1 as item_id,
  1 as item_number,
  title as display_name
FROM accommodations 
WHERE title = 'The Dovecote'
ON CONFLICT DO NOTHING;

-- ========================================
-- Additional Bell Tents and Tipis (if not already added)
-- ========================================

-- 5m Bell Tents (if they exist and don't have items)
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  a.id,
  NULL as zone,
  'BT' as type,
  '5' as size,
  generate_series(1, COALESCE(a.inventory, 1)),
  generate_series(1, COALESCE(a.inventory, 1)),
  '5m Bell Tent #' || generate_series(1, COALESCE(a.inventory, 1))::text
FROM accommodations a
LEFT JOIN accommodation_items ai ON a.id = ai.accommodation_id
WHERE a.title LIKE '%5%Bell Tent%' 
  AND ai.id IS NULL -- Only if no items exist yet
ON CONFLICT DO NOTHING;

-- Double Tipis (if they exist and don't have items)  
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  a.id,
  NULL as zone,
  'TP' as type,
  '3' as size,
  generate_series(1, COALESCE(a.inventory, 1)),
  generate_series(1, COALESCE(a.inventory, 1)),
  'Double Tipi #' || generate_series(1, COALESCE(a.inventory, 1))::text
FROM accommodations a
LEFT JOIN accommodation_items ai ON a.id = ai.accommodation_id
WHERE a.title LIKE '%Double Tipi%' 
  AND ai.id IS NULL -- Only if no items exist yet
ON CONFLICT DO NOTHING;

-- ========================================
-- LE DORM (if it exists)
-- ========================================
INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
SELECT 
  a.id,
  NULL as zone,
  'DORM' as type,
  'LE' as size,
  generate_series(1, COALESCE(a.capacity, 8)), -- Assume 8 beds if capacity not set
  generate_series(1, COALESCE(a.capacity, 8)),
  'Le Dorm Bed #' || generate_series(1, COALESCE(a.capacity, 8))::text
FROM accommodations a
LEFT JOIN accommodation_items ai ON a.id = ai.accommodation_id
WHERE a.title = 'Le Dorm'
  AND ai.id IS NULL -- Only if no items exist yet
ON CONFLICT DO NOTHING;

-- ========================================
-- Additional items for high-inventory bell tents (now that we're setting to 35)
-- ========================================
DO $$
DECLARE
  bell_tent_id UUID;
  current_items INT;
  needed_items INT;
BEGIN
  -- Find 4m bell tents
  FOR bell_tent_id IN 
    SELECT id FROM accommodations 
    WHERE (title = '4 Meter Bell Tent' OR title = '4m Bell Tent')
      AND type = 'bell-tent'
  LOOP
    -- Count existing items
    SELECT COUNT(*) INTO current_items
    FROM accommodation_items
    WHERE accommodation_id = bell_tent_id;
    
    -- Calculate how many more we need (target is 35)
    needed_items := 35 - current_items;
    
    IF needed_items > 0 THEN
      -- Add the missing items
      INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
      SELECT 
        bell_tent_id,
        NULL as zone,
        'BT' as type,
        '4' as size,
        current_items + generate_series(1, needed_items),
        current_items + generate_series(1, needed_items),
        '4m Bell Tent #' || (current_items + generate_series(1, needed_items))::text;
    END IF;
  END LOOP;
END $$;

-- ========================================
-- Additional items for tipis (now that we're setting to 20)
-- ========================================
DO $$
DECLARE
  tipi_id UUID;
  current_items INT;
  needed_items INT;
BEGIN
  -- Find single tipis
  FOR tipi_id IN 
    SELECT id FROM accommodations 
    WHERE title LIKE '%Single Tipi%'
      AND type = 'tipi'
  LOOP
    -- Count existing items
    SELECT COUNT(*) INTO current_items
    FROM accommodation_items
    WHERE accommodation_id = tipi_id;
    
    -- Calculate how many more we need (target is 20)
    needed_items := 20 - current_items;
    
    IF needed_items > 0 THEN
      -- Add the missing items
      INSERT INTO accommodation_items (accommodation_id, zone, type, size, item_id, item_number, display_name)
      SELECT 
        tipi_id,
        NULL as zone,
        'TP' as type,
        '2' as size,
        current_items + generate_series(1, needed_items),
        current_items + generate_series(1, needed_items),
        'Single Tipi #' || (current_items + generate_series(1, needed_items))::text;
    END IF;
  END LOOP;
END $$;

COMMIT;