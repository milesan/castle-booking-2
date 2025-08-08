-- Test script to verify the bug alert trigger is working
-- Run this in Supabase SQL Editor after running fix-bug-alert-trigger.sql

-- First, check if the trigger exists
SELECT 
  tgname as trigger_name,
  tgrelid::regclass as table_name,
  tgtype as trigger_type,
  tgenabled as enabled
FROM pg_trigger 
WHERE tgname = 'bug_alert_trigger';

-- Check if the function exists
SELECT 
  proname as function_name,
  prosrc as function_source
FROM pg_proc 
WHERE proname = 'notify_bug_alert';

-- Check pg_net extension
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- Check if there are any pending HTTP requests from pg_net
SELECT * FROM net._http_response ORDER BY created DESC LIMIT 5;

-- Now insert a test bug report to trigger the email
INSERT INTO bug_reports (
  description, 
  page_url, 
  status,
  steps_to_reproduce
)
VALUES (
  'Manual test bug report - ' || NOW()::text, 
  'https://example.com/manual-test', 
  'new',
  'This is a manual test from SQL editor to verify email trigger is working'
)
RETURNING *;

-- Check the most recent HTTP requests to see if the trigger fired
SELECT 
  id,
  method,
  url,
  status_code,
  created,
  content_type
FROM net._http_response 
ORDER BY created DESC 
LIMIT 5;

-- Also check for any errors in the response
SELECT 
  id,
  url,
  status_code,
  headers,
  content::text as response_body,
  created
FROM net._http_response 
WHERE url LIKE '%send-bug-alert%'
ORDER BY created DESC 
LIMIT 3;