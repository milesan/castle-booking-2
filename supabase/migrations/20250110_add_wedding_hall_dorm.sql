-- Add Indoor Castle Wedding Hall Dorm accommodation
DO $$
BEGIN
    -- Check if the Wedding Hall Dorm already exists
    IF EXISTS (SELECT 1 FROM public.accommodations WHERE title = 'Indoor Castle Wedding Hall Dorm') THEN
        -- Update existing dorm
        UPDATE public.accommodations 
        SET base_price = 150,
            type = 'dorm',
            description = 'Sleep in the grand wedding hall. Includes 90x200 bed, sheets, and pillow. Bring your own duvet/sleeping bag or add one for €50.',
            capacity = 1,
            inventory = 20, -- Assuming multiple beds available in the hall
            bathrooms = 0,
            bathroom_type = 'shared',
            has_wifi = true,
            has_electricity = true,
            property_location = 'renaissance', -- Wedding halls are typically in main building
            property_section = 'first_floor',
            bed_size = '90x200',
            additional_info = 'Bring your own duvet/cover/sleeping bag',
            updated_at = NOW()
        WHERE title = 'Indoor Castle Wedding Hall Dorm';
        
        RAISE NOTICE 'Updated Indoor Castle Wedding Hall Dorm';
    ELSE
        -- Insert new Wedding Hall Dorm accommodation
        INSERT INTO public.accommodations (
            title,
            type,
            base_price,
            capacity,
            inventory,
            description,
            bathrooms,
            bathroom_type,
            has_wifi,
            has_electricity,
            property_location,
            property_section,
            bed_size,
            additional_info,
            is_fungible,
            created_at,
            updated_at
        ) VALUES (
            'Indoor Castle Wedding Hall Dorm',
            'dorm',
            150,
            1, -- Per bed
            20, -- Number of beds available
            'Sleep in the grand wedding hall. Includes 90x200 bed, sheets, and pillow. Bring your own duvet/sleeping bag or add one for €50.',
            0,
            'shared',
            true,
            true,
            'renaissance',
            'first_floor', 
            '90x200',
            'Bring your own duvet/cover/sleeping bag',
            true, -- Fungible since all beds are the same
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Created Indoor Castle Wedding Hall Dorm accommodation';
    END IF;
END $$;

-- Add or update the duvet addon
DO $$
DECLARE
    v_accommodation_id UUID;
BEGIN
    -- Get the accommodation ID for the Wedding Hall Dorm
    SELECT id INTO v_accommodation_id 
    FROM public.accommodations 
    WHERE title = 'Indoor Castle Wedding Hall Dorm'
    LIMIT 1;
    
    IF v_accommodation_id IS NOT NULL THEN
        -- Check if duvet addon already exists
        IF EXISTS (
            SELECT 1 FROM public.addons 
            WHERE name = 'Duvet for Wedding Hall Dorm'
            AND accommodation_id = v_accommodation_id
        ) THEN
            -- Update existing addon
            UPDATE public.addons
            SET price = 50,
                description = 'Add a warm duvet to your Wedding Hall Dorm bed',
                updated_at = NOW()
            WHERE name = 'Duvet for Wedding Hall Dorm'
            AND accommodation_id = v_accommodation_id;
            
            RAISE NOTICE 'Updated duvet addon for Wedding Hall Dorm';
        ELSE
            -- Create new duvet addon
            INSERT INTO public.addons (
                name,
                price,
                description,
                accommodation_id,
                is_per_person,
                is_per_night,
                max_quantity,
                created_at,
                updated_at
            ) VALUES (
                'Duvet for Wedding Hall Dorm',
                50,
                'Add a warm duvet to your Wedding Hall Dorm bed',
                v_accommodation_id,
                true, -- Per person/bed
                false, -- One-time fee, not per night
                1, -- Max 1 duvet per bed
                NOW(),
                NOW()
            );
            
            RAISE NOTICE 'Created duvet addon for Wedding Hall Dorm';
        END IF;
    ELSE
        RAISE WARNING 'Wedding Hall Dorm accommodation not found, cannot create addon';
    END IF;
END $$;