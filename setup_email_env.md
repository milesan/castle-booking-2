# Setting Up Email Confirmation

## Problem
The booking confirmation email is failing with a 400 error because required environment variables are missing.

## Solution

### 1. Set up Resend Account
1. Go to https://resend.com and create an account
2. Get your API key from the dashboard
3. Add and verify your domain (thegarden.pt) or use Resend's test domain

### 2. Set Environment Variables
Run these commands to add the missing secrets to your Supabase project:

```bash
# Set RESEND_API_KEY (replace with your actual Resend API key)
npx supabase secrets set RESEND_API_KEY="re_YOUR_API_KEY_HERE"

# Set BACKEND_URL (use your Supabase project URL)
npx supabase secrets set BACKEND_URL="https://ywsbmarhoyxercqatbfy.supabase.co"

# Optional: Set FRONTEND_URL for email links
npx supabase secrets set FRONTEND_URL="http://localhost:5173"
```

### 3. Deploy the Updated Function
After setting the secrets, redeploy the edge function:

```bash
npx supabase functions deploy send-booking-confirmation
```

### 4. Test the Email
Try making a booking again. The confirmation email should now work.

## Alternative: Disable Email Temporarily
If you don't need email confirmations right now, you can modify the edge function to skip the Resend part and just return success. This would prevent the 400 error from appearing.