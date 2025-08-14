#!/bin/bash

echo "🔧 Dutch Auction Setup Helper"
echo "=============================="
echo ""
echo "This script will help you set up your Supabase credentials."
echo ""

# Check if .env exists
if [ -f .env ]; then
    echo "✅ .env file found"
    
    # Check if credentials are still placeholders
    if grep -q "your-supabase-project-url" .env; then
        echo ""
        echo "⚠️  You need to add your Supabase credentials!"
        echo ""
        echo "Please enter your Supabase credentials:"
        echo "(You can find these in your Supabase Dashboard > Settings > API)"
        echo ""
        
        read -p "Enter your Supabase Project URL (e.g., https://abc123.supabase.co): " SUPABASE_URL
        read -p "Enter your Supabase Anon Key (starts with 'eyJ...'): " SUPABASE_KEY
        
        # Update the .env file
        sed -i.bak "s|your-supabase-project-url.supabase.co|$SUPABASE_URL|g" .env
        sed -i.bak "s|your-supabase-anon-key-here|$SUPABASE_KEY|g" .env
        
        echo ""
        echo "✅ Credentials saved to .env file!"
        rm .env.bak
    else
        echo "✅ Supabase credentials already configured"
    fi
else
    echo "❌ .env file not found. Creating one now..."
    exit 1
fi

echo ""
echo "Starting the development server..."
echo ""
npm run dev