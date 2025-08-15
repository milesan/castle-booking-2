-- Create user_preferences table to track user-specific settings
-- Including whether they've seen the Dutch auction modal

BEGIN;

-- Create the user_preferences table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.user_preferences (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  has_seen_dutch_auction_modal BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id)
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id 
ON public.user_preferences(user_id);

-- Add RLS policies
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;

-- Users can only view their own preferences
CREATE POLICY "Users can view own preferences" 
ON public.user_preferences 
FOR SELECT 
USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own preferences" 
ON public.user_preferences 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

-- Users can update their own preferences
CREATE POLICY "Users can update own preferences" 
ON public.user_preferences 
FOR UPDATE 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Add comment
COMMENT ON TABLE public.user_preferences IS 'User-specific preferences and settings';
COMMENT ON COLUMN public.user_preferences.has_seen_dutch_auction_modal IS 'Whether user has seen the Dutch auction explanation modal';

COMMIT;