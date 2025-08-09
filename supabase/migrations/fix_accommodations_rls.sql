-- Fix Row Level Security policies for accommodations table

-- 1. First, check current RLS policies
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
WHERE tablename = 'accommodations'
ORDER BY policyname;

-- 2. Check if user is admin
SELECT 
    auth.uid() as current_user_id,
    auth.email() as current_email,
    auth.role() as current_role,
    public.is_admin() as is_admin;

-- 3. Drop existing restrictive policies and create proper ones
-- First, let's see what policies exist
DO $$
BEGIN
    -- Drop all existing policies on accommodations
    DROP POLICY IF EXISTS "Public read access to accommodations" ON public.accommodations;
    DROP POLICY IF EXISTS "Admin full access to accommodations" ON public.accommodations;
    DROP POLICY IF EXISTS "Admins can insert accommodations" ON public.accommodations;
    DROP POLICY IF EXISTS "Admins can update accommodations" ON public.accommodations;
    DROP POLICY IF EXISTS "Admins can delete accommodations" ON public.accommodations;
    DROP POLICY IF EXISTS "Anyone can view accommodations" ON public.accommodations;
    
    RAISE NOTICE 'Dropped existing policies';
END $$;

-- 4. Create new comprehensive policies
-- Allow everyone to read accommodations
CREATE POLICY "Anyone can view accommodations"
    ON public.accommodations
    FOR SELECT
    USING (true);

-- Allow admins to insert accommodations
CREATE POLICY "Admins can insert accommodations"
    ON public.accommodations
    FOR INSERT
    WITH CHECK (
        auth.uid() IN (
            SELECT id FROM auth.users 
            WHERE email IN (
                'hello@richardwills.com',
                'admin@example.com',
                'richard@castles.live'
            )
        )
        OR
        public.is_admin() = true
    );

-- Allow admins to update accommodations
CREATE POLICY "Admins can update accommodations"
    ON public.accommodations
    FOR UPDATE
    USING (
        auth.uid() IN (
            SELECT id FROM auth.users 
            WHERE email IN (
                'hello@richardwills.com',
                'admin@example.com',
                'richard@castles.live'
            )
        )
        OR
        public.is_admin() = true
    )
    WITH CHECK (
        auth.uid() IN (
            SELECT id FROM auth.users 
            WHERE email IN (
                'hello@richardwills.com',
                'admin@example.com',
                'richard@castles.live'
            )
        )
        OR
        public.is_admin() = true
    );

-- Allow admins to delete accommodations
CREATE POLICY "Admins can delete accommodations"
    ON public.accommodations
    FOR DELETE
    USING (
        auth.uid() IN (
            SELECT id FROM auth.users 
            WHERE email IN (
                'hello@richardwills.com',
                'admin@example.com',
                'richard@castles.live'
            )
        )
        OR
        public.is_admin() = true
    );

-- 5. Verify the new policies
SELECT 
    'New policies created' as status,
    count(*) as policy_count
FROM pg_policies
WHERE tablename = 'accommodations';

-- 6. Test if current user can insert (for debugging)
SELECT 
    CASE 
        WHEN auth.uid() IS NULL THEN 'Not authenticated'
        WHEN auth.uid() IN (
            SELECT id FROM auth.users 
            WHERE email IN (
                'hello@richardwills.com',
                'admin@example.com',
                'richard@castles.live'
            )
        ) THEN 'Admin by email'
        WHEN public.is_admin() THEN 'Admin by function'
        ELSE 'Regular user'
    END as user_status,
    auth.email() as email,
    auth.uid() as user_id;