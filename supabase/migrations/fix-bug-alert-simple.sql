-- Simplified bug alert trigger that doesn't require vault
-- Run this in the Supabase SQL Editor

-- First, enable pg_net extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Drop the old trigger and function
DROP TRIGGER IF EXISTS bug_alert_trigger ON bug_reports;
DROP FUNCTION IF EXISTS notify_bug_alert();

-- Create a simpler version with the service role key embedded
CREATE OR REPLACE FUNCTION notify_bug_alert()
RETURNS TRIGGER AS $$
DECLARE
  user_email_address TEXT;
  payload JSON;
  request_id BIGINT;
  -- IMPORTANT: This is your service role key from the .env file
  service_key TEXT := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDUwMDYwOCwiZXhwIjoyMDcwMDc2NjA4fQ.xmlTNWk1mgwKQdnfiz1NGTqI3O_lVN9sRH3F_xD7sRc';
  supabase_url TEXT := 'https://ywsbmarhoyxercqatbfy.supabase.co';
BEGIN
  -- Log for debugging
  RAISE NOTICE 'Bug alert triggered for bug ID: %', NEW.id;

  -- Get user email if user_id exists
  IF NEW.user_id IS NOT NULL THEN
    SELECT email INTO user_email_address 
    FROM auth.users 
    WHERE id = NEW.user_id;
    RAISE NOTICE 'User email: %', COALESCE(user_email_address, 'not found');
  END IF;

  -- Build the payload for the email function
  payload := json_build_object(
    'bugId', NEW.id::text,
    'description', NEW.description,
    'steps_to_reproduce', NEW.steps_to_reproduce,
    'page_url', NEW.page_url,
    'status', NEW.status,
    'user_id', COALESCE(NEW.user_id::text, ''),
    'user_email', COALESCE(user_email_address, ''),
    'image_urls', COALESCE(NEW.image_urls, ARRAY[]::text[]),
    'created_at', NEW.created_at::text
  );

  -- Log the payload for debugging
  RAISE NOTICE 'Sending email with payload: %', payload::text;

  -- Call the email function using pg_net
  SELECT INTO request_id
    net.http_post(
      url := supabase_url || '/functions/v1/send-bug-alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := payload::jsonb
    );
  
  RAISE NOTICE 'Bug alert email request sent with ID: %', request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Don't fail the INSERT if email sending fails
    -- Just log the error and continue
    RAISE WARNING 'Bug alert email failed for bug %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER bug_alert_trigger
  AFTER INSERT ON bug_reports
  FOR EACH ROW 
  EXECUTE FUNCTION notify_bug_alert();

-- Add comments for documentation
COMMENT ON FUNCTION notify_bug_alert() IS 'Sends email notification to redis213@gmail.com when new bug reports are created';
COMMENT ON TRIGGER bug_alert_trigger ON bug_reports IS 'Automatically triggers email notification for new bug reports';

-- Verify the setup
SELECT 'Setup complete!' AS status;

-- Check if trigger exists
SELECT 
  'Trigger: ' || tgname || ' on table ' || tgrelid::regclass::text || 
  CASE WHEN tgenabled = 'O' THEN ' (ENABLED)' ELSE ' (DISABLED)' END as trigger_status
FROM pg_trigger 
WHERE tgname = 'bug_alert_trigger';

-- Check if function exists
SELECT 'Function notify_bug_alert exists' AS function_status
WHERE EXISTS (
  SELECT 1 FROM pg_proc 
  WHERE proname = 'notify_bug_alert'
);

-- Test by inserting a bug report
-- This will trigger the email to redis213@gmail.com
INSERT INTO bug_reports (
  description, 
  page_url, 
  status,
  steps_to_reproduce
)
VALUES (
  'Test bug report created at ' || NOW()::text, 
  'https://example.com/sql-test', 
  'new',
  E'1. This is a test from SQL editor\n2. Email should be sent to redis213@gmail.com\n3. Check inbox for bug alert'
)
RETURNING id, description, created_at;

-- Check recent pg_net requests to see if email was sent
SELECT 
  id,
  method,
  url,
  status_code,
  created
FROM net._http_response 
WHERE url LIKE '%send-bug-alert%'
ORDER BY created DESC 
LIMIT 1;