-- Fix Row Level Security policies for payments table
-- Run this in Supabase SQL Editor

-- First, check what RLS policies exist
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'payments';

-- Drop existing policies if they exist (we'll recreate them)
DROP POLICY IF EXISTS "Users can view own payments" ON public.payments;
DROP POLICY IF EXISTS "Users can insert own payments" ON public.payments;
DROP POLICY IF EXISTS "Users can update own payments" ON public.payments;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.payments;
DROP POLICY IF EXISTS "Enable read access for users" ON public.payments;
DROP POLICY IF EXISTS "Enable update for users" ON public.payments;

-- Create new RLS policies for payments table

-- Policy: Users can view their own payments
CREATE POLICY "Users can view own payments" 
ON public.payments FOR SELECT 
TO authenticated 
USING (
    auth.uid() = user_id 
    OR 
    auth.uid() IN (
        SELECT user_id FROM public.profiles WHERE is_admin = true
    )
);

-- Policy: Authenticated users can insert payments (for pending payments)
CREATE POLICY "Users can insert own payments" 
ON public.payments FOR INSERT 
TO authenticated 
WITH CHECK (
    auth.uid() = user_id
);

-- Policy: Users can update their own pending payments
CREATE POLICY "Users can update own payments" 
ON public.payments FOR UPDATE 
TO authenticated 
USING (
    auth.uid() = user_id 
    AND 
    status = 'pending'
)
WITH CHECK (
    auth.uid() = user_id
);

-- Policy: Service role and authenticated users can update payment status
-- This is needed for the booking flow to update payment after Stripe confirmation
CREATE POLICY "System can update payment status" 
ON public.payments FOR UPDATE 
TO authenticated, service_role
USING (true)
WITH CHECK (true);

-- Ensure RLS is enabled on the table
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Verify the policies were created
SELECT 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'payments'
ORDER BY policyname;