-- Update accommodations with castle-themed image URLs
-- These are placeholder images that should be replaced with actual castle room photos

UPDATE public.accommodations 
SET image_url = CASE 
    WHEN title = 'The Dovecote' THEN 'https://images.unsplash.com/photo-1582268611958-ebfd161ef9cf?w=800&q=80'
    WHEN title = 'Bell Tower Suite' THEN 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800&q=80'
    WHEN title = 'The Gardener''s Quarters' THEN 'https://images.unsplash.com/photo-1584132967334-10e028bd69f7?w=800&q=80'
    WHEN title = 'Knights Hall' THEN 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?w=800&q=80'
    WHEN title = 'The Royal Chamber' THEN 'https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=800&q=80'
    WHEN title = 'Castle Dorm - Mixed' THEN 'https://images.unsplash.com/photo-1555854877-bab0e564b8d5?w=800&q=80'
    WHEN title = 'The Turret Room' THEN 'https://images.unsplash.com/photo-1590381105924-c72589b9ef3f?w=800&q=80'
    WHEN title = 'The Library Loft' THEN 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80'
    ELSE 'https://guquxpxxycfmmlqajdyw.supabase.co/storage/v1/object/public/accommodations/castle-main.jpg'
END
WHERE image_url IS NULL OR image_url = '';

-- Verify the update
SELECT id, title, image_url FROM public.accommodations;