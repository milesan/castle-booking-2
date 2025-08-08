-- Test Whitelist Setup
-- Run these queries in Supabase SQL Editor to verify everything is working

-- 1. Check your admin status
SELECT 
  'Your Admin Status' as check_type,
  email,
  is_admin,
  CASE 
    WHEN is_admin = true THEN '✅ You are an admin'
    ELSE '❌ You are not an admin'
  END as status
FROM public.profiles
WHERE email = 'redis213@gmail.com';

-- 2. Check if RLS policies are enabled
SELECT 
  'RLS Status' as check_type,
  schemaname,
  tablename,
  CASE 
    WHEN rowsecurity = true THEN '✅ RLS Enabled'
    ELSE '❌ RLS Disabled'
  END as status
FROM pg_tables
WHERE schemaname = 'public' 
AND tablename = 'profiles';

-- 3. Check if whitelist functions exist
SELECT 
  'Whitelist Functions' as check_type,
  proname as function_name,
  '✅ Function exists' as status
FROM pg_proc
WHERE proname IN ('add_user_to_whitelist', 'remove_user_from_whitelist')
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 4. Test adding a user (as admin) - ONLY RUN IF YOU WANT TO ADD A TEST USER
-- SELECT add_user_to_whitelist('test@example.com');

-- 5. View current whitelist
SELECT 
  'Current Whitelist Users' as check_type,
  COUNT(*) as total_users,
  COUNT(CASE WHEN is_admin = true THEN 1 END) as admin_users,
  COUNT(CASE WHEN is_admin = false OR is_admin IS NULL THEN 1 END) as regular_users
FROM public.profiles;

-- 6. List all users in whitelist
SELECT 
  email,
  CASE 
    WHEN is_admin = true THEN '👑 Admin'
    ELSE '👤 User'
  END as role,
  created_at::date as added_date
FROM public.profiles
ORDER BY is_admin DESC NULLS LAST, created_at DESC;