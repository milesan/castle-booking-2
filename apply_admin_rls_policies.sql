-- Run this SQL in your Supabase SQL Editor
-- This creates RLS policies allowing admins to manage bookings

-- 1. Enable RLS on bookings table
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- 2. Clean up any existing admin policies
DROP POLICY IF EXISTS "Admins can update any booking" ON public.bookings;
DROP POLICY IF EXISTS "Admins can delete any booking" ON public.bookings;
DROP POLICY IF EXISTS "Admins can view all bookings" ON public.bookings;
DROP POLICY IF EXISTS "Admins can insert bookings" ON public.bookings;

-- 3. Create admin policies for bookings
-- Allow admins to view all bookings
CREATE POLICY "Admins can view all bookings" 
ON public.bookings
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to update any booking
CREATE POLICY "Admins can update any booking" 
ON public.bookings
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to delete any booking
CREATE POLICY "Admins can delete any booking" 
ON public.bookings
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to insert bookings (for manual entries)
CREATE POLICY "Admins can insert bookings" 
ON public.bookings
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- 4. Enable RLS on payments table
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- 5. Clean up existing payment policies
DROP POLICY IF EXISTS "Admins can delete any payment" ON public.payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON public.payments;
DROP POLICY IF EXISTS "Admins can update any payment" ON public.payments;
DROP POLICY IF EXISTS "Admins can insert payments" ON public.payments;

-- 6. Create admin policies for payments
-- Allow admins to view all payments
CREATE POLICY "Admins can view all payments" 
ON public.payments
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to delete payments (needed when deleting bookings)
CREATE POLICY "Admins can delete any payment" 
ON public.payments
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to update payments
CREATE POLICY "Admins can update any payment" 
ON public.payments
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Allow admins to insert payments
CREATE POLICY "Admins can insert payments" 
ON public.payments
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- 7. Test query - check if current user is admin
SELECT 
  auth.uid() as current_user_id,
  p.email,
  p.is_admin
FROM public.profiles p
WHERE p.id = auth.uid();