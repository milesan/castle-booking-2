-- Fix the bug alert trigger to properly use secrets
-- Run this in the Supabase SQL Editor

-- First, let's check if pg_net extension is enabled
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Drop the old trigger and function
DROP TRIGGER IF EXISTS bug_alert_trigger ON bug_reports;
DROP FUNCTION IF EXISTS notify_bug_alert();

-- Create an improved version that uses vault for the service role key
CREATE OR REPLACE FUNCTION notify_bug_alert()
RETURNS TRIGGER AS $$
DECLARE
  user_email_address TEXT;
  payload JSON;
  supabase_url TEXT;
  service_key TEXT;
  request_id BIGINT;
BEGIN
  -- Get configuration
  supabase_url := 'https://ywsbmarhoyxercqatbfy.supabase.co';
  
  -- Get service role key from vault
  SELECT decrypted_secret INTO service_key
  FROM vault.decrypted_secrets
  WHERE name = 'SUPABASE_SERVICE_ROLE_KEY'
  LIMIT 1;
  
  -- If not found in vault, try environment setting
  IF service_key IS NULL THEN
    service_key := current_setting('app.settings.supabase_service_role_key', true);
  END IF;
  
  -- Log for debugging
  RAISE LOG 'Bug alert triggered for bug ID: %', NEW.id;
  RAISE LOG 'Service key found: %', (service_key IS NOT NULL);

  -- Get user email if user_id exists
  IF NEW.user_id IS NOT NULL THEN
    SELECT email INTO user_email_address 
    FROM auth.users 
    WHERE id = NEW.user_id;
    RAISE LOG 'User email: %', user_email_address;
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
  RAISE LOG 'Payload: %', payload::text;

  -- Call the email function asynchronously using pg_net
  IF service_key IS NOT NULL AND service_key != 'dummy-key' THEN
    SELECT INTO request_id
      net.http_post(
        url := supabase_url || '/functions/v1/send-bug-alert',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || service_key
        ),
        body := payload::jsonb
      );
    
    RAISE LOG 'Bug alert email request sent with ID: %', request_id;
  ELSE
    RAISE LOG 'Service key not found, skipping email notification';
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Don't fail the INSERT if email sending fails
    -- Just log the error and continue
    RAISE LOG 'Bug alert email failed for bug %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
CREATE TRIGGER bug_alert_trigger
  AFTER INSERT ON bug_reports
  FOR EACH ROW 
  EXECUTE FUNCTION notify_bug_alert();

-- Test: Insert the service role key into vault if not already there
-- You need to replace YOUR_SERVICE_ROLE_KEY with the actual key from your dashboard
DO $$
BEGIN
  -- Check if the secret already exists
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets 
    WHERE name = 'SUPABASE_SERVICE_ROLE_KEY'
  ) THEN
    -- Insert the secret (replace with your actual service role key)
    INSERT INTO vault.secrets (name, secret)
    VALUES (
      'SUPABASE_SERVICE_ROLE_KEY',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDUwMDYwOCwiZXhwIjoyMDcwMDc2NjA4fQ.xmlTNWk1mgwKQdnfiz1NGTqI3O_lVN9sRH3F_xD7sRc'
    );
    RAISE NOTICE 'Service role key added to vault';
  ELSE
    -- Update the existing secret
    UPDATE vault.secrets 
    SET secret = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NDUwMDYwOCwiZXhwIjoyMDcwMDc2NjA4fQ.xmlTNWk1mgwKQdnfiz1NGTqI3O_lVN9sRH3F_xD7sRc'
    WHERE name = 'SUPABASE_SERVICE_ROLE_KEY';
    RAISE NOTICE 'Service role key updated in vault';
  END IF;
END;
$$;

-- Verify the setup
SELECT 'Trigger function recreated' AS status
WHERE EXISTS (
  SELECT FROM pg_proc 
  WHERE proname = 'notify_bug_alert'
);

SELECT 'Trigger exists' AS status
WHERE EXISTS (
  SELECT FROM pg_trigger 
  WHERE tgname = 'bug_alert_trigger'
);

-- Check if service key is in vault
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM vault.secrets WHERE name = 'SUPABASE_SERVICE_ROLE_KEY') 
    THEN 'Service role key is configured in vault'
    ELSE 'Service role key NOT found in vault - please configure it'
  END AS vault_status;

-- Test the trigger by inserting a test bug report
-- Uncomment this to test:
/*
INSERT INTO bug_reports (description, page_url, status)
VALUES ('Test bug report for email trigger', 'https://example.com/test', 'new')
RETURNING id;
*/