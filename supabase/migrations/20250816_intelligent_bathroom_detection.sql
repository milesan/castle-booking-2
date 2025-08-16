-- Intelligent bathroom detection based on accommodation type and characteristics
-- This migration updates bathroom_type based on contextual analysis

BEGIN;

-- First ensure the bathroom_type column exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'accommodations' 
        AND column_name = 'bathroom_type'
    ) THEN
        ALTER TABLE public.accommodations 
        ADD COLUMN bathroom_type text CHECK (bathroom_type IN ('private', 'shared', 'none'));
    END IF;
END $$;

-- Intelligently set bathroom types based on accommodation characteristics
UPDATE public.accommodations
SET bathroom_type = CASE
    -- === PRIVATE BATHROOMS ===
    -- First check if explicitly mentioned in additional_info
    WHEN additional_info ~* '(private|en-suite|ensuite|own).*(bath|shower|tub|toilet|wc)' THEN 'private'
    WHEN additional_info ~* '(bath|shower|tub|toilet|wc).*(private|en-suite|ensuite|own)' THEN 'private'
    WHEN additional_info ~* 'private.*bathroom' THEN 'private'
    WHEN additional_info ~* 'en-suite' THEN 'private'
    
    -- Castle suites and premium rooms (typically €200+ or with "suite", "room" in name)
    WHEN title IN (
        'The Dovecote',           -- Luxury suite with private tub
        'The Hearth',            -- King bed suite with fireplace
        'Writer''s Room',        -- Queen bed with desk
        'Writers Room',          -- Alternative spelling
        'Valleyview Room',       -- Queen bed with valley views
        'Castle Suite',          -- Generic suite name
        'Tower Suite',           -- Tower location implies privacy
        'Master Suite',          -- Master implies private
        'Penthouse',            -- Top floor luxury
        'The Library',          -- Premium room
        'The Observatory',      -- Premium room
        'The Gallery'           -- Premium room
    ) THEN 'private'
    
    -- Renaissance wing rooms (higher floors typically have private bathrooms)
    WHEN title LIKE 'Renaissance%Attic%' THEN 'private'
    WHEN title LIKE 'Renaissance%2nd Floor%' THEN 'private'
    WHEN title LIKE 'Renaissance%Tower%' THEN 'private'
    
    -- Medieval wing rooms (castle rooms often have private facilities when premium)
    WHEN title LIKE 'Medieval%Suite%' THEN 'private'
    WHEN title LIKE 'Medieval%Room%' AND base_price >= 250 THEN 'private'
    WHEN title LIKE 'Medieval%Tower%' THEN 'private'
    
    -- Oriental wing (exotic/themed rooms often premium with private bath)
    WHEN title LIKE 'Oriental%Suite%' THEN 'private'
    WHEN title LIKE 'Oriental%Room%' AND base_price >= 300 THEN 'private'
    WHEN title LIKE 'Oriental%Tower%' THEN 'private'
    
    -- Dovecote area (luxury area)
    WHEN property_location = 'dovecote' AND base_price >= 500 THEN 'private'
    
    -- High-price rooms (€400+ almost certainly have private bathrooms in castles)
    WHEN base_price >= 400 
        AND title LIKE '%Room%' 
        AND title NOT LIKE '%Dorm%' THEN 'private'
    
    -- Mid-high price castle rooms (€250-400 likely private unless noted)
    WHEN base_price >= 250 
        AND base_price < 400
        AND property_location = 'castle'
        AND title LIKE '%Room%' 
        AND title NOT LIKE '%Dorm%'
        AND additional_info NOT LIKE '%shared%' THEN 'private'
    
    -- === SHARED BATHROOMS ===
    -- First check if explicitly mentioned in additional_info
    WHEN additional_info ~* '(shared|communal).*(bath|shower|facilities|toilet|wc)' THEN 'shared'
    WHEN additional_info ~* '(bath|shower|facilities|toilet|wc).*(shared|communal)' THEN 'shared'
    WHEN additional_info ~* 'shared bathroom' THEN 'shared'
    WHEN additional_info ~* 'communal facilities' THEN 'shared'
    
    -- All dormitories always have shared bathrooms
    WHEN title ~* 'dorm' THEN 'shared'
    WHEN title ~* 'hostel' THEN 'shared'
    WHEN title ~* 'bunk' THEN 'shared'
    
    -- Budget accommodations
    WHEN title = 'Le Dorm' THEN 'shared'
    WHEN title LIKE 'Wedding Hall%' THEN 'shared'
    WHEN title LIKE 'Shared%' THEN 'shared'
    WHEN title LIKE '%Bunk%' THEN 'shared'
    WHEN title LIKE 'Communal%' THEN 'shared'
    
    -- All camping/glamping options have shared facilities
    WHEN title ~* '(tent|tipi|yurt|pod|cabin|micro)' THEN 'shared'
    WHEN title LIKE '%Bell Tent%' THEN 'shared'
    WHEN title LIKE '%Tipi%' THEN 'shared'
    WHEN title = 'The Yurt' THEN 'shared'
    WHEN title = 'A-Frame Pod' THEN 'shared'
    WHEN title LIKE 'Microcabin%' THEN 'shared'
    WHEN title LIKE '%Glamping%' THEN 'shared'
    
    -- Van/tent/camping
    WHEN title ~* '(van|rv|camper|tent|camping|byo|bring.?your.?own)' THEN 'shared'
    WHEN title = 'Your Own Tent/Van' THEN 'shared'
    WHEN property_location = 'camping' THEN 'shared'
    WHEN property_location = 'glamping' THEN 'shared'
    
    -- Renaissance lower floors (typically shared in budget castle configurations)
    WHEN title LIKE 'Renaissance%Mezzanine%' AND base_price < 200 THEN 'shared'
    WHEN title LIKE 'Renaissance%1st Floor%' AND base_price < 200 THEN 'shared'
    WHEN title LIKE 'Renaissance%Ground%' THEN 'shared'
    
    -- Palm Grove area (outdoor/garden area likely shared facilities)
    WHEN title LIKE 'Palm Grove%' AND base_price < 200 THEN 'shared'
    WHEN property_location = 'palm grove' AND base_price < 200 THEN 'shared'
    
    -- Medieval wing budget rooms
    WHEN title LIKE 'Medieval%' AND base_price < 200 THEN 'shared'
    WHEN title LIKE 'Medieval%Dorm%' THEN 'shared'
    WHEN title LIKE 'Medieval%Shared%' THEN 'shared'
    
    -- Oriental wing budget rooms
    WHEN title LIKE 'Oriental%' AND base_price < 150 THEN 'shared'
    WHEN title LIKE 'Oriental%Dorm%' THEN 'shared'
    WHEN title LIKE 'Oriental%Shared%' THEN 'shared'
    
    -- Any low-price accommodation (under €100 almost certainly shared)
    WHEN base_price < 100 THEN 'shared'
    
    -- === NO BATHROOM (SPECIAL ARRANGEMENTS) ===
    WHEN title IN (
        'Staying with somebody',
        'Guest of Resident',
        'Garden Decompression (No Castle Accommodation)',
        'Garden Only'
    ) THEN 'none'
    
    -- === DEFAULT LOGIC ===
    -- If price >= €200 and in castle, likely private
    WHEN base_price >= 200 
        AND property_location = 'castle' 
        AND title NOT LIKE '%Dorm%' THEN 'private'
    
    -- Otherwise default to shared (most common for budget options)
    ELSE COALESCE(bathroom_type, 'shared')
END
WHERE title IS NOT NULL;

-- Create a detailed report of bathroom assignments
DO $$
DECLARE
    private_rooms TEXT;
    shared_rooms TEXT;
    uncertain_rooms TEXT;
BEGIN
    -- Get private bathroom rooms
    SELECT STRING_AGG(
        title || ' (€' || base_price || ')', 
        E'\n  • ' 
        ORDER BY base_price DESC
    ) INTO private_rooms
    FROM public.accommodations 
    WHERE bathroom_type = 'private';
    
    -- Get shared bathroom rooms (sample)
    SELECT STRING_AGG(
        title || ' (€' || base_price || ')', 
        E'\n  • ' 
        ORDER BY base_price ASC
    ) INTO shared_rooms
    FROM (
        SELECT title, base_price 
        FROM public.accommodations 
        WHERE bathroom_type = 'shared'
        ORDER BY base_price ASC
        LIMIT 15
    ) t;
    
    -- Get rooms that might need manual review (mid-price range without clear indicators)
    SELECT STRING_AGG(
        title || ' (€' || base_price || ')', 
        E'\n  • ' 
        ORDER BY base_price DESC
    ) INTO uncertain_rooms
    FROM public.accommodations 
    WHERE bathroom_type = 'shared' 
        AND base_price BETWEEN 150 AND 250
        AND title LIKE '%Room%';
    
    RAISE NOTICE E'\n=== BATHROOM TYPE ASSIGNMENT REPORT ===\n';
    RAISE NOTICE E'PRIVATE BATHROOMS:\n  • %', COALESCE(private_rooms, '(none)');
    RAISE NOTICE E'\nSHARED BATHROOMS (sample):\n  • %', COALESCE(shared_rooms, '(none)');
    
    IF uncertain_rooms IS NOT NULL THEN
        RAISE NOTICE E'\nROOMS TO REVIEW (mid-price, might need adjustment):\n  • %', uncertain_rooms;
    END IF;
    
    RAISE NOTICE E'\nSummary:';
    RAISE NOTICE '  Private: % rooms', (SELECT COUNT(*) FROM public.accommodations WHERE bathroom_type = 'private');
    RAISE NOTICE '  Shared: % rooms', (SELECT COUNT(*) FROM public.accommodations WHERE bathroom_type = 'shared');
    RAISE NOTICE '  None/Special: % rooms', (SELECT COUNT(*) FROM public.accommodations WHERE bathroom_type = 'none');
    RAISE NOTICE E'\n========================================';
END $$;

-- Add helpful comments
COMMENT ON COLUMN public.accommodations.bathroom_type IS 
'Bathroom type: private (en-suite), shared (communal facilities), or none (special arrangements)';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_accommodations_bathroom_type 
ON public.accommodations(bathroom_type) 
WHERE bathroom_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_accommodations_price_location 
ON public.accommodations(base_price, property_location) 
WHERE base_price IS NOT NULL;

COMMIT;