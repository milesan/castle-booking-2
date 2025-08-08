-- Create RLS policies for admin users to manage bookings

-- First, ensure RLS is enabled on bookings table
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Drop existing update/delete policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Admins can update any booking" ON public.bookings;
DROP POLICY IF EXISTS "Admins can delete any booking" ON public.bookings;
DROP POLICY IF EXISTS "Users can update own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Users can delete own bookings" ON public.bookings;

-- Create policy for admins to UPDATE any booking
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

-- Create policy for admins to DELETE any booking
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

-- Optional: Allow users to update their own bookings (for cancellation)
CREATE POLICY "Users can update own bookings" 
ON public.bookings
FOR UPDATE
TO authenticated
USING (
  auth.uid() = user_id
)
WITH CHECK (
  auth.uid() = user_id
  -- Only allow updating status to cancelled, not other fields
  AND (
    -- Admin can update any field
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
    OR 
    -- Regular users can only cancel
    (status = 'cancelled' OR status IS NULL)
  )
);

-- Create policy for admins to SELECT all bookings (if not exists)
DROP POLICY IF EXISTS "Admins can view all bookings" ON public.bookings;
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

-- Create policy for admins to INSERT bookings (for manual entries)
DROP POLICY IF EXISTS "Admins can insert bookings" ON public.bookings;
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

-- Also ensure admins can manage payments table
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can delete any payment" ON public.payments;
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

DROP POLICY IF EXISTS "Admins can view all payments" ON public.payments;
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

DROP POLICY IF EXISTS "Admins can update any payment" ON public.payments;
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

DROP POLICY IF EXISTS "Admins can insert payments" ON public.payments;
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

-- Grant necessary permissions to authenticated users (Supabase handles this but being explicit)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.bookings TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO authenticated;

-- Ensure the bookings_with_emails view has proper permissions
GRANT SELECT ON public.bookings_with_emails TO authenticated;