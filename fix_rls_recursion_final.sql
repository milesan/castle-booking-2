-- Final fix for infinite recursion in profiles RLS
-- Run this ENTIRE script in Supabase SQL Editor

-- 1. First, completely disable RLS to reset everything
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- 2. Drop ALL existing policies on profiles
DO $$ 
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename = 'profiles'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
    END LOOP;
END $$;

-- 3. Create a simple function to check if a user is admin
-- This avoids the recursion by using a SECURITY DEFINER function
CREATE OR REPLACE FUNCTION public.is_admin(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = user_id LIMIT 1),
    false
  );
$$;

-- 4. Re-enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 5. Create simple, non-recursive policies using the function

-- Everyone can SELECT from profiles (needed for whitelist check)
CREATE POLICY "Enable read access for all users" 
ON public.profiles 
FOR SELECT 
USING (true);

-- Users can update their own profile (except is_admin)
CREATE POLICY "Enable update for users own profile" 
ON public.profiles 
FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid())
);

-- Admins can insert new profiles
CREATE POLICY "Enable insert for admins" 
ON public.profiles 
FOR INSERT 
WITH CHECK (
  public.is_admin(auth.uid()) = true
);

-- Admins can delete profiles
CREATE POLICY "Enable delete for admins" 
ON public.profiles 
FOR DELETE 
USING (
  public.is_admin(auth.uid()) = true
);

-- Admins can update any profile
CREATE POLICY "Enable admin updates" 
ON public.profiles 
FOR UPDATE 
USING (
  public.is_admin(auth.uid()) = true
)
WITH CHECK (
  public.is_admin(auth.uid()) = true
);

-- 6. Grant execute permission on the helper function
GRANT EXECUTE ON FUNCTION public.is_admin TO authenticated;

-- 7. Test that it works
SELECT 
  'Testing profiles access' as test,
  COUNT(*) as total_users
FROM public.profiles;

-- 8. Verify your admin status
SELECT 
  id,
  email,
  is_admin,
  created_at
FROM public.profiles
WHERE email = 'redis213@gmail.com';