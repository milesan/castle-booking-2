-- Fix admin function and RLS policies for accommodations

-- 1. First check your current user details
SELECT 
    auth.uid() as your_user_id,
    auth.email() as your_email,
    auth.role() as your_role,
    public.is_admin() as currently_admin;

-- 2. Update the is_admin function to include more admin emails
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM auth.users 
    WHERE id = auth.uid() 
    AND email IN (
      'andre@thegarden.pt',
      'redis213@gmail.com',
      'dawn@thegarden.pt',
      'kc@thegarden.pt',
      'rob@thegarden.pt',
      'joe@thegarden.pt',
      'hello@richardwills.com',
      'richard@castles.live',
      'admin@example.com'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Alternative: Create a temporary superuser policy for testing
-- This allows any authenticated user to manage accommodations (TEMPORARY - REMOVE IN PRODUCTION!)
DROP POLICY IF EXISTS "Temporary admin access for testing" ON public.accommodations;

CREATE POLICY "Temporary admin access for testing"
    ON public.accommodations
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- 4. Check which policies are now active
SELECT 
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'accommodations'
ORDER BY policyname;

-- 5. Test if you can now insert
SELECT 
    'Can insert accommodations:' as check,
    CASE 
        WHEN auth.uid() IS NULL THEN 'Not authenticated'
        WHEN public.is_admin() THEN 'Yes - Admin'
        WHEN auth.role() = 'authenticated' THEN 'Yes - Authenticated user'
        ELSE 'No'
    END as result,
    auth.email() as your_email;

-- 6. If you want to add yourself as a permanent admin, 
-- uncomment and modify this with your actual email:
/*
UPDATE auth.users 
SET raw_user_meta_data = 
    CASE 
        WHEN raw_user_meta_data IS NULL THEN '{"is_admin": true}'::jsonb
        ELSE raw_user_meta_data || '{"is_admin": true}'::jsonb
    END
WHERE email = 'YOUR_EMAIL_HERE';
*/