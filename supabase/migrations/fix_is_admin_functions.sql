-- Fix is_admin function conflicts

-- 1. First, check what is_admin functions exist
SELECT 
    proname as function_name,
    pg_get_function_identity_arguments(oid) as arguments
FROM pg_proc
WHERE proname = 'is_admin'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 2. Drop the conflicting versions carefully
DROP FUNCTION IF EXISTS public.is_admin(uuid);  -- Version with user_id parameter
-- Keep the no-argument version that checks auth.uid()

-- 3. Make sure we have the correct is_admin() function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid() LIMIT 1),
    false
  );
$$;

-- 4. Now fix the profiles RLS policies
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

-- Drop ALL policies on profiles table
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

-- 5. Re-enable RLS with fixed policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Anyone can read profiles (needed for login check)
CREATE POLICY "anyone_can_read" 
ON public.profiles FOR SELECT 
USING (true);

-- Users can update their own profile
CREATE POLICY "users_update_own" 
ON public.profiles FOR UPDATE 
USING (auth.uid() = id);

-- Admins can insert (add to whitelist)
CREATE POLICY "admins_can_insert" 
ON public.profiles FOR INSERT 
WITH CHECK (public.is_admin());

-- Admins can delete (remove from whitelist)
CREATE POLICY "admins_can_delete" 
ON public.profiles FOR DELETE 
USING (public.is_admin());

-- 6. Grant permissions
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;

-- 7. Test that everything works
SELECT 
    'Testing is_admin function' as test,
    public.is_admin() as am_i_admin,
    auth.uid() as my_user_id;

SELECT 
    email,
    is_admin,
    created_at
FROM public.profiles
WHERE email = 'redis213@gmail.com';