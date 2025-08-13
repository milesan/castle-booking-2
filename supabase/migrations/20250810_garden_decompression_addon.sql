-- Enable Garden Decompression add-on bookings
-- This migration allows bookings for just the Garden decompression without requiring Castle accommodation

BEGIN;

-- Create a special accommodation entry for Garden-only bookings
DO $$
BEGIN
    -- Check if Garden Only accommodation already exists
    IF NOT EXISTS (SELECT 1 FROM public.accommodations WHERE title = 'Garden Decompression (No Castle Accommodation)') THEN
        INSERT INTO public.accommodations (
            title,
            type,
            base_price,
            capacity,
            inventory,
            image_url,
            has_wifi,
            has_electricity,
            property_location,
            additional_info,
            bathroom_type,
            is_unlimited,
            created_at,
            updated_at
        ) VALUES (
            'Garden Decompression (No Castle Accommodation)',
            'addon',
            0, -- Price is handled by the addon selection
            999, -- High capacity since it's just the Garden
            999, -- High inventory
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&q=80', -- Garden/nature image
            true,
            true,
            'garden',
            'Garden-only booking • Accommodation at The Garden in Portugal • Travel separately from The Castle',
            'shared',
            false,
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Created Garden Decompression accommodation entry';
    END IF;
END $$;

-- Add a column to track Garden addon details in bookings
ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS garden_addon_details JSONB;

COMMENT ON COLUMN public.bookings.garden_addon_details IS 'JSON details for Garden decompression addon (option type, dates, price)';

-- Create an index for Garden addon bookings
CREATE INDEX IF NOT EXISTS idx_bookings_garden_addon 
ON public.bookings((garden_addon_details IS NOT NULL))
WHERE garden_addon_details IS NOT NULL;

-- Create a view for Garden addon bookings
CREATE OR REPLACE VIEW garden_addon_bookings AS
SELECT 
    b.*,
    u.email as user_email,
    u.raw_user_meta_data->>'full_name' as guest_name,
    b.garden_addon_details->>'option_name' as garden_option,
    b.garden_addon_details->>'start_date' as garden_start,
    b.garden_addon_details->>'end_date' as garden_end,
    (b.garden_addon_details->>'price')::numeric as garden_price
FROM bookings b
JOIN auth.users u ON b.user_id = u.id
WHERE b.garden_addon_details IS NOT NULL;

-- Grant permissions on the view
GRANT SELECT ON garden_addon_bookings TO authenticated;

-- Log the migration completion
DO $$
DECLARE
    garden_id UUID;
BEGIN
    SELECT id INTO garden_id 
    FROM public.accommodations 
    WHERE title = 'Garden Decompression (No Castle Accommodation)';
    
    IF garden_id IS NOT NULL THEN
        RAISE NOTICE 'Garden Decompression addon setup complete. Special accommodation ID: %', garden_id;
    END IF;
END $$;

COMMIT;