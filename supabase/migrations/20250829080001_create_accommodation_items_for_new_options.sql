-- Create accommodation items for new accommodation options
-- Date: 2025-08-29

DO $$
DECLARE
  castle_view_id UUID;
  near_castle_id UUID;
  ramparts_view_id UUID;
  garden_tipi_id UUID;
  i INT;
BEGIN
  -- Get accommodation IDs
  SELECT id INTO castle_view_id FROM accommodations WHERE title = '4M Bell Tent, Castle View' LIMIT 1;
  SELECT id INTO near_castle_id FROM accommodations WHERE title = '4M Bell Tent, Near Castle' LIMIT 1;
  SELECT id INTO ramparts_view_id FROM accommodations WHERE title = 'Tipi, Ramparts View' LIMIT 1;
  SELECT id INTO garden_tipi_id FROM accommodations WHERE title = 'Tipi, Garden Location' LIMIT 1;
  
  -- Create items for 4M Bell Tent, Castle View (3 items)
  IF castle_view_id IS NOT NULL THEN
    FOR i IN 1..3 LOOP
      INSERT INTO accommodation_items (accommodation_id, item_number, display_name)
      VALUES (castle_view_id, i, '4M Bell Tent Castle View #' || i)
      ON CONFLICT (accommodation_id, item_number) DO NOTHING;
    END LOOP;
  END IF;

  -- Create items for 4M Bell Tent, Near Castle (12 items)
  IF near_castle_id IS NOT NULL THEN
    FOR i IN 1..12 LOOP
      INSERT INTO accommodation_items (accommodation_id, item_number, display_name)
      VALUES (near_castle_id, i, '4M Bell Tent Near Castle #' || i)
      ON CONFLICT (accommodation_id, item_number) DO NOTHING;
    END LOOP;
  END IF;

  -- Create items for Tipi, Ramparts View (15 items)
  IF ramparts_view_id IS NOT NULL THEN
    FOR i IN 1..15 LOOP
      INSERT INTO accommodation_items (accommodation_id, item_number, display_name)
      VALUES (ramparts_view_id, i, 'Tipi Ramparts View #' || i)
      ON CONFLICT (accommodation_id, item_number) DO NOTHING;
    END LOOP;
  END IF;

  -- Create items for Tipi, Garden Location (2 items)
  IF garden_tipi_id IS NOT NULL THEN
    FOR i IN 1..2 LOOP
      INSERT INTO accommodation_items (accommodation_id, item_number, display_name)
      VALUES (garden_tipi_id, i, 'Tipi Garden #' || i)
      ON CONFLICT (accommodation_id, item_number) DO NOTHING;
    END LOOP;
  END IF;

END $$;