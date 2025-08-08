# Bug Report System Setup

## What's Been Done

✅ **Edge Functions Deployed:**
- `submit-bug-report` - Handles bug report submissions and saves to database
- `send-bug-alert` - Sends email notifications to redis213@gmail.com

✅ **Migration Files Created:**
- `20250808000001_create_bug_reports_table.sql` - Creates the bug_reports table
- `20250808000002_create_bug_report_storage.sql` - Creates storage bucket for screenshots

## Manual Setup Required

Since we couldn't connect to the database via CLI, you need to run the SQL script manually:

### Step 1: Run the Database Setup

1. Go to your Supabase Dashboard: https://supabase.com/dashboard/project/ywsbmarhoyxercqatbfy/editor
2. Open the SQL Editor
3. Copy and paste the contents of `scripts/setup-bug-reports.sql`
4. Click "Run" to execute the script

### Step 2: Set the Service Role Key (for email triggers)

In the SQL Editor, run this command with your actual service role key:

```sql
SELECT set_config('app.settings.supabase_service_role_key', 'YOUR_SERVICE_ROLE_KEY_HERE', false);
```

You can find your service role key in:
- Dashboard > Settings > API > Service role key

### Step 3: Verify the Setup

Check that everything is working:

1. **Database Table**: Go to Table Editor and verify `bug_reports` table exists
2. **Storage Bucket**: Go to Storage and verify `bug-report-attachments` bucket exists
3. **Edge Functions**: Go to Functions and verify both functions show as "Active"

## How It Works

1. **User submits bug report** → Frontend calls `submit-bug-report` edge function
2. **Edge function saves to database** → Bug report stored in `bug_reports` table
3. **Database trigger fires** → Calls `send-bug-alert` edge function
4. **Email sent** → Notification sent to redis213@gmail.com with bug details

## Testing

To test the bug submission:

1. Open your app and look for the bug report button (usually a floating action button)
2. Fill in the description and optional steps to reproduce
3. Optionally add screenshots (up to 5 images, max 5MB each)
4. Submit the report
5. Check redis213@gmail.com for the email notification

## Troubleshooting

### If emails aren't being sent:

1. Check that RESEND_API_KEY is set in Supabase secrets:
   ```bash
   npx supabase secrets list
   ```

2. Check edge function logs in the dashboard:
   - Functions > send-bug-alert > Logs

### If bug reports aren't saving:

1. Check edge function logs:
   - Functions > submit-bug-report > Logs

2. Verify the user is authenticated when submitting

### If images aren't uploading:

1. Check storage bucket permissions in the dashboard
2. Verify file size is under 5MB
3. Check that file type is an image (jpeg, jpg, png, gif, webp)

## Environment Variables

The following are already configured:
- `RESEND_API_KEY` - For sending emails via Resend
- `SUPABASE_URL` - Your project URL
- `SUPABASE_ANON_KEY` - Public anon key
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key (for triggers)