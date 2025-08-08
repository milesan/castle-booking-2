-- Setup User Access Control via user_status in profiles table
-- Run this in Supabase SQL Editor

-- 1. Ensure user_status_enum exists
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_status_enum') THEN
    CREATE TYPE public.user_status_enum AS ENUM ('pending', 'approved', 'rejected');
  END IF;
END $$;

-- 2. Ensure user_status column exists in profiles table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'user_status'
  ) THEN
    ALTER TABLE public.profiles 
    ADD COLUMN user_status public.user_status_enum DEFAULT 'pending'::user_status_enum;
  END IF;
END $$;

-- 3. Create a function to check if user is approved for login
CREATE OR REPLACE FUNCTION public.is_user_approved_for_login(user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = user_id
    AND user_status = 'approved'::user_status_enum
  );
$$;

-- 4. Create RLS policy for profiles table to allow users to see their own profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON public.profiles;

-- Users can view their own profile
CREATE POLICY "Users can view own profile" 
ON public.profiles
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Users can update their own profile (but not user_status or is_admin)
CREATE POLICY "Users can update own profile" 
ON public.profiles
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND (
    -- Check that user_status and is_admin are not being changed
    -- or user is admin
    (user_status = (SELECT user_status FROM public.profiles WHERE id = auth.uid()))
    AND (is_admin = (SELECT is_admin FROM public.profiles WHERE id = auth.uid()))
  )
  OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles" 
ON public.profiles
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- Admins can update all profiles (including user_status)
CREATE POLICY "Admins can update all profiles" 
ON public.profiles
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

-- 5. Create a view to see user access status
CREATE OR REPLACE VIEW public.user_access_status AS
SELECT 
  p.id,
  p.email,
  p.first_name,
  p.last_name,
  p.user_status,
  p.is_admin,
  p.created_at,
  CASE 
    WHEN p.user_status = 'approved' THEN 'Can Login'
    WHEN p.user_status = 'rejected' THEN 'Blocked'
    ELSE 'Pending Approval'
  END as access_status,
  CASE 
    WHEN p.user_status = 'approved' THEN true
    ELSE false
  END as can_login
FROM public.profiles p
ORDER BY p.created_at DESC;

-- Grant access to the view
GRANT SELECT ON public.user_access_status TO authenticated;

-- 6. Update any existing users to approved if needed (optional)
-- Uncomment the line below to approve all existing users
-- UPDATE public.profiles SET user_status = 'approved' WHERE user_status IS NULL;

-- 7. Test queries to verify setup
SELECT 
  'Total Users' as metric,
  COUNT(*) as count
FROM public.profiles
UNION ALL
SELECT 
  'Approved Users' as metric,
  COUNT(*) as count
FROM public.profiles
WHERE user_status = 'approved'
UNION ALL
SELECT 
  'Pending Users' as metric,
  COUNT(*) as count
FROM public.profiles
WHERE user_status = 'pending'
UNION ALL
SELECT 
  'Rejected Users' as metric,
  COUNT(*) as count
FROM public.profiles
WHERE user_status = 'rejected';