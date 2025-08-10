// Run this script to set up the Dutch auction tables in Supabase
// Usage: node scripts/setup-dutch-auction.js

console.log(`
========================================
Dutch Auction Setup Instructions
========================================

Please run the following SQL in your Supabase SQL editor 
(Dashboard -> SQL Editor -> New Query):

----------------------------------------
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

-- Create auction configuration table
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
) 
SELECT 
  '2025-09-14 00:00:00+00',
  1,
  false
WHERE NOT EXISTS (SELECT 1 FROM public.auction_config);

-- Create auction history table
CREATE TABLE IF NOT EXISTS public.auction_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  accommodation_id UUID REFERENCES public.accommodations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  action_type TEXT NOT NULL,
  price_at_action DECIMAL(10,2) NOT NULL,
  max_bid DECIMAL(10,2),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS policies
ALTER TABLE public.auction_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auction_history ENABLE ROW LEVEL SECURITY;

-- Allow public to read auction config
CREATE POLICY IF NOT EXISTS "Allow public to read auction config" ON public.auction_config
  FOR SELECT USING (true);

-- Allow public to read auction history
CREATE POLICY IF NOT EXISTS "Allow public to read auction history" ON public.auction_history
  FOR SELECT USING (true);

----------------------------------------

After running the SQL above, the Dutch auction system will be ready to use!

Features:
- 3 tiers of rooms (Tower Suites, Noble Quarters, Standard Chambers)
- Hourly price drops
- Admin panel to configure tiers and pricing
- User-facing auction page with real-time price updates
- Ability to exclude specific rooms (like Dovecot) from the auction

Access the features at:
- Admin Panel: /admin -> Dutch Auction tab
- User Auction Page: /dutch-auction
`);