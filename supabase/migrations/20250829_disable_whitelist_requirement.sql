-- Disable whitelist requirement - allow all authenticated users with magic link
-- This migration updates policies to allow any authenticated user to book

BEGIN;

-- Update or create a function that always returns true for authenticated users
CREATE OR REPLACE FUNCTION public.is_whitelisted()
RETURNS boolean AS $$
BEGIN
  -- WHITELIST DISABLED - All authenticated users are allowed
  -- If you have a valid auth.uid(), you're approved
  RETURN auth.uid() IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing restrictive policies that might check whitelist
DROP POLICY IF EXISTS "Users can only book if whitelisted" ON bookings;
DROP POLICY IF EXISTS "Whitelisted users can create bookings" ON bookings;
DROP POLICY IF EXISTS "Only whitelisted users can book" ON bookings;

-- Create new permissive policy for bookings
CREATE POLICY "Authenticated users can create bookings"
  ON bookings FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can view their own bookings"
  ON bookings FOR SELECT
  USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Users can update their own bookings"
  ON bookings FOR UPDATE
  USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "Users can delete their own bookings"
  ON bookings FOR DELETE
  USING (auth.uid() = user_id OR public.is_admin());

-- Update user_status to auto-approve authenticated users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Auto-approve all authenticated users
  INSERT INTO public.user_status (
    user_id,
    status,
    welcome_screen_seen,
    whitelist_signup_completed
  ) VALUES (
    new.id,
    'whitelisted', -- Auto-approve as "whitelisted"
    false,
    true -- Mark signup as completed
  ) ON CONFLICT (user_id) DO NOTHING;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure trigger exists for auto-approval
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Update existing user_status records to approve all authenticated users
UPDATE public.user_status
SET status = 'whitelisted',
    whitelist_signup_completed = true
WHERE status NOT IN ('whitelisted', 'admin');

COMMIT;