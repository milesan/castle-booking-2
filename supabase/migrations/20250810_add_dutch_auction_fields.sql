-- Add Dutch auction fields to accommodations table
ALTER TABLE public.accommodations
ADD COLUMN IF NOT EXISTS auction_tier TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_start_price DECIMAL(10,2) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_floor_price DECIMAL(10,2) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_current_price DECIMAL(10,2) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_last_price_update TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS is_in_auction BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS auction_buyer_id UUID DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS auction_max_bid DECIMAL(10,2) DEFAULT NULL;

-- Add check constraints
ALTER TABLE public.accommodations
ADD CONSTRAINT auction_tier_check CHECK (auction_tier IN ('tower_suite', 'noble_quarter', 'standard_chamber') OR auction_tier IS NULL),
ADD CONSTRAINT auction_price_check CHECK (
  (auction_start_price IS NULL AND auction_floor_price IS NULL) OR
  (auction_start_price >= auction_floor_price AND auction_floor_price > 0)
),
ADD CONSTRAINT auction_current_price_check CHECK (
  auction_current_price IS NULL OR
  (auction_current_price >= auction_floor_price AND auction_current_price <= auction_start_price)
);

-- Create index for auction queries
CREATE INDEX IF NOT EXISTS idx_accommodations_auction ON public.accommodations(is_in_auction, auction_tier, auction_current_price);
CREATE INDEX IF NOT EXISTS idx_accommodations_auction_buyer ON public.accommodations(auction_buyer_id);

-- Create auction configuration table for global settings
CREATE TABLE IF NOT EXISTS public.auction_config (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  auction_start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  auction_end_time TIMESTAMP WITH TIME ZONE,
  price_drop_interval_hours INTEGER DEFAULT 1,
  price_drop_amount DECIMAL(10,2) DEFAULT NULL,
  is_active BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default auction config
INSERT INTO public.auction_config (
  auction_end_time,
  price_drop_interval_hours,
  is_active
) VALUES (
  '2025-09-14 00:00:00+00',
  1,
  false
);

-- Create auction history table for tracking all bids and price changes
CREATE TABLE IF NOT EXISTS public.auction_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  accommodation_id UUID REFERENCES public.accommodations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL CHECK (action_type IN ('price_drop', 'reservation', 'cancellation', 'purchase')),
  price_at_action DECIMAL(10,2) NOT NULL,
  max_bid DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for auction history queries
CREATE INDEX IF NOT EXISTS idx_auction_history_accommodation ON public.auction_history(accommodation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_auction_history_user ON public.auction_history(user_id, created_at DESC);

-- Function to calculate current auction price based on time elapsed
CREATE OR REPLACE FUNCTION calculate_auction_price(
  start_price DECIMAL,
  floor_price DECIMAL,
  auction_start TIMESTAMP WITH TIME ZONE,
  drop_interval_hours INTEGER
) RETURNS DECIMAL AS $$
DECLARE
  hours_elapsed INTEGER;
  drops_count INTEGER;
  price_per_drop DECIMAL;
  current_price DECIMAL;
BEGIN
  -- Calculate hours elapsed since auction start
  hours_elapsed := EXTRACT(EPOCH FROM (NOW() - auction_start)) / 3600;
  
  -- Calculate number of price drops
  drops_count := FLOOR(hours_elapsed / drop_interval_hours);
  
  -- Calculate price drop per interval to reach floor price by Sept 14
  -- Assuming linear decrease
  price_per_drop := (start_price - floor_price) / ((EXTRACT(EPOCH FROM ('2025-09-14 00:00:00+00'::TIMESTAMP WITH TIME ZONE - auction_start)) / 3600) / drop_interval_hours);
  
  -- Calculate current price
  current_price := start_price - (drops_count * price_per_drop);
  
  -- Ensure price doesn't go below floor
  IF current_price < floor_price THEN
    current_price := floor_price;
  END IF;
  
  RETURN current_price;
END;
$$ LANGUAGE plpgsql;

-- Function to update all auction prices (to be called by cron job)
CREATE OR REPLACE FUNCTION update_auction_prices() RETURNS void AS $$
DECLARE
  config RECORD;
  acc RECORD;
  new_price DECIMAL;
BEGIN
  -- Get active auction config
  SELECT * INTO config FROM public.auction_config WHERE is_active = true LIMIT 1;
  
  IF config IS NULL THEN
    RETURN;
  END IF;
  
  -- Update prices for all accommodations in auction
  FOR acc IN 
    SELECT * FROM public.accommodations 
    WHERE is_in_auction = true 
    AND auction_tier IS NOT NULL 
    AND auction_buyer_id IS NULL
  LOOP
    new_price := calculate_auction_price(
      acc.auction_start_price,
      acc.auction_floor_price,
      config.auction_start_time,
      config.price_drop_interval_hours
    );
    
    -- Only update if price has changed
    IF new_price != acc.auction_current_price THEN
      UPDATE public.accommodations
      SET 
        auction_current_price = new_price,
        auction_last_price_update = NOW()
      WHERE id = acc.id;
      
      -- Log price drop in history
      INSERT INTO public.auction_history (
        accommodation_id,
        action_type,
        price_at_action
      ) VALUES (
        acc.id,
        'price_drop',
        new_price
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create a cron job to update prices every hour (requires pg_cron extension)
-- This will be set up separately in the Supabase dashboard or via SQL command:
-- SELECT cron.schedule('update-auction-prices', '0 * * * *', 'SELECT update_auction_prices();');

-- Add RLS policies for auction tables
ALTER TABLE public.auction_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auction_history ENABLE ROW LEVEL SECURITY;

-- Allow public to read auction config
CREATE POLICY "Allow public to read auction config" ON public.auction_config
  FOR SELECT USING (true);

-- Allow admins to update auction config
CREATE POLICY "Allow admins to update auction config" ON public.auction_config
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'admin'
    )
  );

-- Allow public to read auction history
CREATE POLICY "Allow public to read auction history" ON public.auction_history
  FOR SELECT USING (true);

-- Allow authenticated users to see their own auction history details
CREATE POLICY "Users can see their own auction history" ON public.auction_history
  FOR SELECT USING (auth.uid() = user_id);