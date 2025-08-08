-- Run this script in the Supabase SQL Editor to set up bug reporting
-- Dashboard: https://supabase.com/dashboard/project/ywsbmarhoyxercqatbfy/editor

-- 1. Create bug_reports table
CREATE TABLE IF NOT EXISTS bug_reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  steps_to_reproduce TEXT,
  page_url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in_progress', 'resolved', 'closed')),
  image_urls TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_bug_reports_user_id ON bug_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON bug_reports(status);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON bug_reports(created_at DESC);

-- Enable Row Level Security
ALTER TABLE bug_reports ENABLE ROW LEVEL SECURITY;

-- Policy: Users can create bug reports (authenticated users)
CREATE POLICY "Users can create bug reports" ON bug_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can view their own bug reports
CREATE POLICY "Users can view own bug reports" ON bug_reports
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy: Admins can view all bug reports
CREATE POLICY "Admins can view all bug reports" ON bug_reports
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Policy: Admins can update bug reports (for status changes)
CREATE POLICY "Admins can update bug reports" ON bug_reports
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.is_admin = true
    )
  );

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_bug_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS bug_reports_updated_at_trigger ON bug_reports;
CREATE TRIGGER bug_reports_updated_at_trigger
  BEFORE UPDATE ON bug_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_bug_reports_updated_at();

-- 2. Create storage bucket for bug report attachments
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'bug-report-attachments',
  'bug-report-attachments',
  true, -- Public bucket so images can be viewed
  5242880, -- 5MB limit per file
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies for bug report attachments

-- Policy: Authenticated users can upload files
CREATE POLICY "Authenticated users can upload bug report attachments"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'bug-report-attachments' 
  AND (storage.foldername(name))[1] = 'public'
);

-- Policy: Anyone can view bug report attachments (public bucket)
CREATE POLICY "Anyone can view bug report attachments"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'bug-report-attachments');

-- Policy: Users can delete their own uploaded attachments
CREATE POLICY "Users can delete own bug report attachments"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'bug-report-attachments'
  AND auth.uid()::text = (storage.foldername(name))[2]
);

-- Policy: Admins can delete any bug report attachments
CREATE POLICY "Admins can delete any bug report attachments"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'bug-report-attachments'
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE profiles.id = auth.uid()
    AND profiles.is_admin = true
  )
);

-- 3. Create the email trigger function
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
  
  -- Note: You'll need to set the service role key as a secret
  -- Run this in SQL Editor: SELECT set_config('app.settings.supabase_service_role_key', 'YOUR_SERVICE_ROLE_KEY_HERE', false);
  service_key := COALESCE(
    current_setting('app.settings.service_role_key', true),
    current_setting('app.settings.supabase_service_role_key', true),
    'dummy-key'
  );

  -- Get user email if user_id exists
  IF NEW.user_id IS NOT NULL THEN
    SELECT email INTO user_email_address 
    FROM auth.users 
    WHERE id = NEW.user_id;
  END IF;

  -- Build the payload for the email function
  payload := json_build_object(
    'bugId', NEW.id::text,
    'description', NEW.description,
    'steps_to_reproduce', NEW.steps_to_reproduce,
    'page_url', NEW.page_url,
    'status', NEW.status,
    'user_id', NEW.user_id::text,
    'user_email', user_email_address,
    'image_urls', NEW.image_urls,
    'created_at', NEW.created_at::text
  );

  -- Call the email function asynchronously using pg_net
  SELECT INTO request_id
    net.http_post(
      url := supabase_url || '/functions/v1/send-bug-alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_key
      ),
      body := payload::jsonb
    );

  -- Optionally log the request ID for debugging
  RAISE LOG 'Bug alert email triggered for bug % with request ID %', NEW.id, request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Don't fail the INSERT if email sending fails
    -- Just log the error and continue
    RAISE LOG 'Bug alert email failed for bug %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger that fires after every INSERT on bug_reports
DROP TRIGGER IF EXISTS bug_alert_trigger ON bug_reports;

CREATE TRIGGER bug_alert_trigger
  AFTER INSERT ON bug_reports
  FOR EACH ROW 
  EXECUTE FUNCTION notify_bug_alert();

-- Add comments for documentation
COMMENT ON TABLE bug_reports IS 'Stores user-submitted bug reports with optional screenshots';
COMMENT ON TRIGGER bug_alert_trigger ON bug_reports IS 'Automatically sends email alerts to redis213@gmail.com when new bugs are reported';

-- Verify the setup
SELECT 'Bug reports table created' AS status
WHERE EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'bug_reports');

SELECT 'Storage bucket created' AS status  
WHERE EXISTS (SELECT FROM storage.buckets WHERE id = 'bug-report-attachments');

SELECT 'Edge functions deployed - Check dashboard' AS status;