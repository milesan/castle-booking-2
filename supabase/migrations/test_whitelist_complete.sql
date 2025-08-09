-- Test the complete whitelist system

-- 1. Test adding a user that doesn't have an auth account (should go to pending)
SELECT 'Test 1: Adding user without auth account' as test;
SELECT whitelist_add_user('testpending@example.com', 'Test', 'Pending', false) as result;

-- 2. Verify it went to pending
SELECT 'Test 2: Check pending whitelist' as test;
SELECT email, first_name, last_name, is_admin, status 
FROM whitelist_all 
WHERE email = 'testpending@example.com';

-- 3. Test toggle admin on pending user
SELECT 'Test 3: Toggle admin on pending user' as test;
SELECT whitelist_toggle_admin('testpending@example.com') as result;

-- 4. Verify admin was toggled
SELECT 'Test 4: Verify admin toggle' as test;
SELECT email, is_admin, status 
FROM whitelist_all 
WHERE email = 'testpending@example.com';

-- 5. Test bulk import
SELECT 'Test 5: Bulk import users' as test;
SELECT whitelist_bulk_import('[
  {"email": "bulk1@example.com", "first_name": "Bulk", "last_name": "One", "is_admin": false},
  {"email": "bulk2@example.com", "first_name": "Bulk", "last_name": "Two", "is_admin": true}
]'::json) as result;

-- 6. Show all whitelist entries
SELECT 'Test 6: Complete whitelist view' as test;
SELECT 
  COALESCE(id::text, 'pending') as id,
  email,
  COALESCE(first_name || ' ' || last_name, 'No name') as name,
  CASE WHEN is_admin THEN '👑 Admin' ELSE '👤 User' END as role,
  status,
  created_at::timestamp(0) as added
FROM whitelist_all
ORDER BY status DESC, created_at DESC;

-- 7. Clean up test data
SELECT 'Test 7: Cleanup' as test;
SELECT whitelist_remove_user('testpending@example.com') as remove1;
SELECT whitelist_remove_user('bulk1@example.com') as remove2;
SELECT whitelist_remove_user('bulk2@example.com') as remove3;

-- 8. Final check
SELECT 'Test 8: Final whitelist state' as test;
SELECT COUNT(*) as total_users,
       COUNT(CASE WHEN status = 'active' THEN 1 END) as active_users,
       COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_users,
       COUNT(CASE WHEN is_admin THEN 1 END) as admins
FROM whitelist_all;