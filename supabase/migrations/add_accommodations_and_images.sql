-- Add accommodation_images table and sample data for Castle Booking

-- Create accommodation_images table
CREATE TABLE IF NOT EXISTS public.accommodation_images (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    accommodation_id uuid REFERENCES public.accommodations(id) ON DELETE CASCADE,
    image_url text NOT NULL,
    display_order integer DEFAULT 0,
    caption text,
    created_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.accommodation_images ENABLE ROW LEVEL SECURITY;

-- Create policy for viewing images
CREATE POLICY "Images are viewable by everyone" ON public.accommodation_images
    FOR SELECT USING (true);

-- Insert sample accommodations if they don't exist
INSERT INTO public.accommodations (id, title, base_price, type, inventory, capacity, has_wifi, has_electricity, is_unlimited)
VALUES 
    ('a1111111-1111-1111-1111-111111111111', 'Castle Room - Single', 120, 'cabin', 5, 1, true, true, false),
    ('a2222222-2222-2222-2222-222222222222', 'Castle Room - Double', 180, 'cabin', 3, 2, true, true, false),
    ('a3333333-3333-3333-3333-333333333333', 'Castle Suite', 250, 'cabin', 2, 2, true, true, false),
    ('a4444444-4444-4444-4444-444444444444', 'Garden Camping', 50, 'camping', 10, 1, false, false, false),
    ('a5555555-5555-5555-5555-555555555555', 'Shared Dorm', 60, 'dorm', 8, 1, true, true, false)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    base_price = EXCLUDED.base_price;

-- Grant permissions
GRANT SELECT ON public.accommodation_images TO authenticated, anon;