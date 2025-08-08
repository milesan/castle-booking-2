-- Create bug_reports table for storing user-submitted bug reports
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
CREATE TRIGGER bug_reports_updated_at_trigger
  BEFORE UPDATE ON bug_reports
  FOR EACH ROW
  EXECUTE FUNCTION update_bug_reports_updated_at();

-- Add comments for documentation
COMMENT ON TABLE bug_reports IS 'Stores user-submitted bug reports with optional screenshots';
COMMENT ON COLUMN bug_reports.user_id IS 'ID of the user who submitted the report';
COMMENT ON COLUMN bug_reports.description IS 'Description of the bug';
COMMENT ON COLUMN bug_reports.steps_to_reproduce IS 'Optional steps to reproduce the bug';
COMMENT ON COLUMN bug_reports.page_url IS 'URL of the page where the bug was encountered';
COMMENT ON COLUMN bug_reports.status IS 'Current status of the bug report (new, in_progress, resolved, closed)';
COMMENT ON COLUMN bug_reports.image_urls IS 'Array of URLs for uploaded screenshots';