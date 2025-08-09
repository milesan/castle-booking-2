-- Fix admin function to use profiles table instead of hardcoded emails

-- 1. Check current admin users in profiles
SELECT 
    p.id,
    p.email,
    p.is_admin,
    u.email as auth_email
FROM public.profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.is_admin = true;

-- 2. Check your own profile status
SELECT 
    p.id,
    p.email,
    p.is_admin,
    auth.uid() as current_user_id,
    auth.email() as current_email
FROM public.profiles p
WHERE p.id = auth.uid();

-- 3. Update the is_admin function to check profiles table
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND is_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Drop all existing accommodation policies
DROP POLICY IF EXISTS "Public read access to accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Admin full access to accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Admins can insert accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Admins can update accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Admins can delete accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Anyone can view accommodations" ON public.accommodations;
DROP POLICY IF EXISTS "Temporary admin access for testing" ON public.accommodations;

-- 5. Create proper RLS policies using the profiles-based is_admin function
-- Allow everyone to read accommodations
CREATE POLICY "Anyone can view accommodations"
    ON public.accommodations
    FOR SELECT
    USING (true);

-- Allow admins to insert accommodations
CREATE POLICY "Admins can insert accommodations"
    ON public.accommodations
    FOR INSERT
    WITH CHECK (public.is_admin());

-- Allow admins to update accommodations
CREATE POLICY "Admins can update accommodations"
    ON public.accommodations
    FOR UPDATE
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Allow admins to delete accommodations
CREATE POLICY "Admins can delete accommodations"
    ON public.accommodations
    FOR DELETE
    USING (public.is_admin());

-- 6. If you need to make yourself an admin, run this with your user ID:
-- First find your user ID
SELECT 
    id,
    email,
    is_admin
FROM public.profiles
WHERE email = auth.email();

-- Then update if needed (uncomment and modify):
/*
UPDATE public.profiles
SET is_admin = true
WHERE id = auth.uid();
*/

-- 7. Verify the setup
SELECT 
    'Admin check results:' as info,
    auth.uid() as user_id,
    auth.email() as email,
    public.is_admin() as is_admin,
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true) as profile_is_admin;