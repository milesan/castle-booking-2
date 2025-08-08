-- Test script to verify the whitelist system works correctly
-- This will test both active and pending user scenarios

-- 1. First, check current state
SELECT 'Current profiles (active whitelist):' as test_step;
SELECT id, email, first_name, last_name, is_admin, created_at::date 
FROM public.profiles 
ORDER BY created_at DESC;

-- 2. Check pending whitelist
SELECT 'Current pending whitelist:' as test_step;
SELECT email, first_name, last_name, is_admin, created_at::date 
FROM public.whitelist_pending 
ORDER BY created_at DESC;

-- 3. Test adding a user without auth account (should go to pending)
SELECT 'Testing add user without auth account:' as test_step;
SELECT public.whitelist_add_user(
  'pending_user@test.com', 
  'Pending', 
  'User', 
  false
) as add_pending_result;

-- 4. Test adding another pending user as admin
SELECT 'Testing add pending admin:' as test_step;
SELECT public.whitelist_add_user(
  'pending_admin@test.com', 
  'Pending', 
  'Admin', 
  true
) as add_pending_admin_result;

-- 5. Check the unified view
SELECT 'Unified whitelist view (active + pending):' as test_step;
SELECT email, first_name, last_name, is_admin, status, created_at::date
FROM public.whitelist_all
ORDER BY status DESC, created_at DESC;

-- 6. Test toggle admin status on pending user
SELECT 'Testing toggle admin on pending user:' as test_step;
SELECT public.whitelist_toggle_admin('pending_user@test.com') as toggle_result;

-- 7. Verify the change
SELECT 'After toggle - pending user should now be admin:' as test_step;
SELECT email, is_admin, status 
FROM public.whitelist_all 
WHERE email = 'pending_user@test.com';

-- 8. Test removing a pending user
SELECT 'Testing remove pending user:' as test_step;
SELECT public.whitelist_remove_user('pending_admin@test.com') as remove_result;

-- 9. Final state
SELECT 'Final unified whitelist:' as test_step;
SELECT email, first_name || ' ' || last_name as name, 
       CASE WHEN is_admin THEN '👑 Admin' ELSE '👤 User' END as role,
       status,
       created_at::date as added
FROM public.whitelist_all
ORDER BY status DESC, created_at DESC;

-- 10. Clean up test data
DELETE FROM public.whitelist_pending WHERE email IN ('pending_user@test.com', 'pending_admin@test.com');
SELECT 'Test cleanup complete' as test_step;