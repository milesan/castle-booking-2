-- Add image for Indoor Castle Wedding Hall Dorm
DO $$
DECLARE
    v_accommodation_id UUID;
BEGIN
    -- Get the accommodation ID
    SELECT id INTO v_accommodation_id 
    FROM public.accommodations 
    WHERE title = 'Indoor Castle Wedding Hall Dorm'
    LIMIT 1;
    
    IF v_accommodation_id IS NOT NULL THEN
        -- Check if images already exist
        IF NOT EXISTS (
            SELECT 1 FROM public.accommodation_images 
            WHERE accommodation_id = v_accommodation_id
        ) THEN
            -- Insert primary image for the wedding hall dorm
            INSERT INTO public.accommodation_images (
                accommodation_id,
                image_url,
                display_order,
                is_primary,
                created_at
            ) VALUES (
                v_accommodation_id,
                'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&q=80', -- Grand hall image
                1,
                true,
                NOW()
            );
            
            -- Add a second image showing the bed setup
            INSERT INTO public.accommodation_images (
                accommodation_id,
                image_url,
                display_order,
                is_primary,
                created_at
            ) VALUES (
                v_accommodation_id,
                'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=800&q=80', -- Dorm bed image
                2,
                false,
                NOW()
            );
            
            RAISE NOTICE 'Added images for Indoor Castle Wedding Hall Dorm';
        ELSE
            RAISE NOTICE 'Images already exist for Indoor Castle Wedding Hall Dorm';
        END IF;
    ELSE
        RAISE WARNING 'Indoor Castle Wedding Hall Dorm not found';
    END IF;
END $$;