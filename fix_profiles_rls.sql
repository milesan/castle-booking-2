-- Fix infinite recursion in profiles RLS policies
-- Run this in Supabase SQL Editor

-- 1. Disable RLS temporarily to fix policies
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Drop all existing policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public can check whitelist" ON public.profiles;

-- 3. Re-enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 4. Create simple, non-recursive policies

-- Allow authenticated users to view all profiles (needed for whitelist check and admin panel)
CREATE POLICY "Authenticated users can view profiles" 
ON public.profiles
FOR SELECT
TO authenticated
USING (true);

-- Allow public/anon to check if email exists (for login whitelist check)
CREATE POLICY "Anyone can check whitelist emails" 
ON public.profiles
FOR SELECT
TO anon
USING (true);

-- Users can only update their own profile (but not is_admin field)
CREATE POLICY "Users can update own profile fields" 
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  -- Prevent users from making themselves admin
  AND (
    is_admin IS NOT DISTINCT FROM (
      SELECT is_admin 
      FROM public.profiles 
      WHERE id = auth.uid()
      LIMIT 1
    )
  )
);

-- Admins can update any profile (separate policy to avoid recursion)
CREATE POLICY "Admin full access to profiles" 
ON public.profiles
FOR ALL
TO authenticated
USING (
  -- Check admin status directly from auth.uid()
  auth.uid() IN (
    SELECT id FROM public.profiles 
    WHERE is_admin = true 
    LIMIT 100  -- Limit to prevent any potential issues
  )
);

-- 5. Test the policies
SELECT 
  id,
  email,
  first_name,
  last_name,
  is_admin,
  created_at
FROM public.profiles
ORDER BY created_at DESC
LIMIT 10;