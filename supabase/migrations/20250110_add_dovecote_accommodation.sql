-- Add or update The Dovecote accommodation with €42,000 price
-- First check if it exists, then insert or update

DO $$
BEGIN
    -- Check if The Dovecote already exists
    IF EXISTS (SELECT 1 FROM public.accommodations WHERE title = 'The Dovecote') THEN
        -- Update existing Dovecote
        UPDATE public.accommodations 
        SET base_price = 42000,
            updated_at = NOW()
        WHERE title = 'The Dovecote';
        
        RAISE NOTICE 'Updated The Dovecote price to €42,000';
    ELSE
        -- Insert new Dovecote accommodation
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
            description,
            created_at,
            updated_at
        ) VALUES (
            'The Dovecote',
            'cabin',
            42000,
            2,  -- Assuming it fits 2 people
            1,  -- Only 1 available
            'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800&q=80',
            true,
            true,
            'dovecote',
            'Exclusive luxury accommodation in the historic Dovecote',
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Created The Dovecote accommodation with €42,000 price';
    END IF;
END $$;