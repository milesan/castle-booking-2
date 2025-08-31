#!/bin/bash

# Double-Booking Prevention Test Runner
# This script helps you test the atomic booking implementation

echo "================================================"
echo "🧪 ATOMIC BOOKING SYSTEM - TEST RUNNER"
echo "================================================"
echo ""

# Check if environment variables are set
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_SERVICE_KEY" ]; then
    echo "⚠️  Supabase credentials not found in environment"
    echo ""
    echo "Please set the following environment variables:"
    echo "  export SUPABASE_URL='your-project-url'"
    echo "  export SUPABASE_SERVICE_KEY='your-service-role-key'"
    echo ""
    echo "You can find these in your Supabase project settings."
    exit 1
fi

echo "✓ Supabase credentials found"
echo ""

# Menu
echo "Select a test to run:"
echo "1) Quick Test - Node.js concurrent booking simulation"
echo "2) SQL Test - Direct database testing (requires psql)"
echo "3) Full Test Suite - Comprehensive testing"
echo "4) Check for existing double-bookings"
echo "5) Apply migration (if not already applied)"
echo ""
read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo ""
        echo "Running Quick Test..."
        echo "====================="
        node test-double-booking-prevention.mjs
        ;;
    
    2)
        echo ""
        echo "Running SQL Test..."
        echo "==================="
        if [ -z "$DATABASE_URL" ]; then
            echo "❌ DATABASE_URL not set. This test requires direct database access."
            echo "Please set: export DATABASE_URL='postgresql://...'"
            exit 1
        fi
        psql "$DATABASE_URL" -f test-atomic-booking-sql.sql
        ;;
    
    3)
        echo ""
        echo "Running Full Test Suite..."
        echo "=========================="
        node test-atomic-booking-comprehensive.js
        ;;
    
    4)
        echo ""
        echo "Checking for double-bookings..."
        echo "================================"
        node -e "
import { createClient } from '@supabase/supabase-js';
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);

(async () => {
    const { data, error } = await supabase.rpc('check_for_double_bookings');
    if (error) {
        console.error('Error:', error.message);
        process.exit(1);
    }
    if (!data || data.length === 0) {
        console.log('✅ No double-bookings found in the system!');
    } else {
        console.log('⚠️  Found', data.length, 'accommodation(s) with double-bookings:');
        data.forEach(item => {
            console.log('  -', item.accommodation_title);
            console.log('    Overlapping bookings:', item.overlapping_bookings);
        });
    }
})();
        "
        ;;
    
    5)
        echo ""
        echo "Applying migration..."
        echo "====================="
        echo "Attempting to apply the atomic booking migration..."
        npx supabase db push --file supabase/migrations/20250831_improve_booking_atomic_locking.sql
        if [ $? -eq 0 ]; then
            echo "✅ Migration applied successfully!"
        else
            echo "❌ Failed to apply migration. Please check the error above."
        fi
        ;;
    
    *)
        echo "Invalid choice. Please run the script again and select 1-5."
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "Test completed. Check the output above for results."
echo "================================================"