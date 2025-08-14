# 🚨 SETUP REQUIRED: Add Your Supabase Credentials

The app is showing a white screen because it needs your Supabase credentials to work.

## Quick Setup (2 minutes)

### Step 1: Get Your Supabase Credentials

1. Go to your **Supabase Dashboard**: https://app.supabase.com
2. Select your project (or create one if you don't have one)
3. Go to **Settings** → **API** (in the left sidebar)
4. You'll see two important values:
   - **Project URL**: Something like `https://abcdefghijk.supabase.co`
   - **Anon Key**: A long string starting with `eyJ...`

### Step 2: Add Credentials to .env File

I've created a `.env` file for you. You need to edit it:

1. Open the file: `/Users/mc/conductor/castle-booking-2/.conductor/hamburg/.env`
2. Replace the placeholder values:
   ```
   VITE_SUPABASE_URL=https://your-project-id.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...your-actual-anon-key-here...
   ```

### Step 3: Run Database Migration

In your Supabase Dashboard:
1. Go to **SQL Editor**
2. Click **New Query**
3. Copy the SQL from `DUTCH_AUCTION_FINAL.md`
4. Click **Run**

### Step 4: Restart the App

After adding your credentials, restart the development server:

```bash
# Press Ctrl+C to stop the current server
# Then run:
npm run dev
```

## Example .env File

Your `.env` file should look like this (with your actual values):

```env
VITE_SUPABASE_URL=https://xyzabc123456.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh5emFiYzEyMzQ1NiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ2MjM5MDIyLCJleHAiOjE5NjE4MTUwMjJ9.abcdef123456789
VITE_APP_URL=http://localhost:5173
```

## Need a Supabase Project?

If you don't have a Supabase project yet:
1. Go to https://supabase.com
2. Sign up for free
3. Create a new project
4. Wait ~2 minutes for it to be ready
5. Then follow the steps above

---

Once you've added your credentials and restarted the server, the Dutch Auction will work! 🚀