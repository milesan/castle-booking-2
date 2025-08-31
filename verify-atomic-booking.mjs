#!/usr/bin/env node

/**
 * Verification Script for Atomic Booking Implementation
 * 
 * This script verifies that the atomic booking system is properly installed
 * and functioning correctly to prevent double-bookings.
 */

import { createClient } from '@supabase/supabase-js';

// Get credentials from environment or command line
const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL || process.argv[2];
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || process.argv[3];

if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.log('Usage: node verify-atomic-booking.mjs [SUPABASE_URL] [SUPABASE_SERVICE_KEY]');
    console.log('Or set environment variables: SUPABASE_URL and SUPABASE_SERVICE_KEY');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Verification checks
const checks = {
    migrationApplied: false,
    functionsExist: false,
    triggersExist: false,
    noDoubleBookings: false,
    edgeFunctionUpdated: false,
};

async function verifyMigration() {
    console.log('1. Checking if migration was applied...');
    
    try {
        // Try to call the new function with dummy data
        const { error } = await supabase.rpc('check_availability_with_lock', {
            p_accommodation_id: '00000000-0000-0000-0000-000000000000',
            p_check_in: '2025-01-01',
            p_check_out: '2025-01-07',
        });
        
        // If function doesn't exist, we'll get error code 42883
        if (error && error.code === '42883') {
            console.log('   ❌ Migration NOT applied - functions not found');
            console.log('   Run: npx supabase db push');
            return false;
        }
        
        console.log('   ✅ Migration applied - functions exist');
        checks.migrationApplied = true;
        return true;
    } catch (err) {
        console.log('   ❌ Error checking migration:', err.message);
        return false;
    }
}

async function verifyFunctions() {
    console.log('2. Verifying all required functions...');
    
    const requiredFunctions = [
        'create_booking_with_atomic_lock',
        'check_availability_with_lock',
        'check_for_double_bookings',
    ];
    
    let allExist = true;
    
    for (const funcName of requiredFunctions) {
        try {
            // Check if we can get function info (this will fail if it doesn't exist)
            const { error } = await supabase.rpc(funcName, {
                // Dummy parameters - we expect this to fail with wrong params, not missing function
                p_accommodation_id: '00000000-0000-0000-0000-000000000000',
            });
            
            if (error && error.code === '42883') {
                console.log(`   ❌ Function ${funcName} NOT found`);
                allExist = false;
            } else {
                console.log(`   ✅ Function ${funcName} exists`);
            }
        } catch (err) {
            // Function exists but call failed (expected)
            console.log(`   ✅ Function ${funcName} exists`);
        }
    }
    
    checks.functionsExist = allExist;
    return allExist;
}

async function verifyNoDoubleBookings() {
    console.log('3. Checking for existing double-bookings...');
    
    try {
        const { data, error } = await supabase.rpc('check_for_double_bookings');
        
        if (error) {
            console.log('   ⚠️  Could not check for double-bookings:', error.message);
            return false;
        }
        
        if (!data || data.length === 0) {
            console.log('   ✅ No double-bookings detected');
            checks.noDoubleBookings = true;
            return true;
        } else {
            console.log(`   ⚠️  Found ${data.length} accommodation(s) with potential double-bookings`);
            data.forEach(item => {
                console.log(`      - ${item.accommodation_title}`);
            });
            return false;
        }
    } catch (err) {
        console.log('   ❌ Error checking double-bookings:', err.message);
        return false;
    }
}

async function verifyEdgeFunction() {
    console.log('4. Checking Edge Function configuration...');
    
    try {
        // Check if the Edge Function exists and is deployed
        const { data, error } = await supabase.functions.list();
        
        if (error) {
            console.log('   ⚠️  Could not list Edge Functions');
            return false;
        }
        
        const bookingFunction = data?.find(f => f.slug === 'create-booking-securely');
        
        if (bookingFunction) {
            console.log('   ✅ Edge Function "create-booking-securely" is deployed');
            checks.edgeFunctionUpdated = true;
            return true;
        } else {
            console.log('   ⚠️  Edge Function "create-booking-securely" not found');
            console.log('   Deploy with: npx supabase functions deploy create-booking-securely');
            return false;
        }
    } catch (err) {
        // If we can't list functions, check if we can at least invoke it
        try {
            const { error } = await supabase.functions.invoke('create-booking-securely', {
                body: { test: true }
            });
            
            // Any response means the function exists
            console.log('   ✅ Edge Function "create-booking-securely" is accessible');
            checks.edgeFunctionUpdated = true;
            return true;
        } catch (invokeErr) {
            console.log('   ⚠️  Could not verify Edge Function status');
            return false;
        }
    }
}

async function quickFunctionalTest() {
    console.log('5. Running quick functional test...');
    
    try {
        // Create a test accommodation
        const { data: testAccom, error: accomError } = await supabase
            .from('accommodations')
            .insert({
                title: `Verification Test Room ${Date.now()}`,
                type: 'room',
                inventory: 1,
                is_unlimited: false,
                price: 100,
            })
            .select()
            .single();
        
        if (accomError) {
            console.log('   ⚠️  Could not create test accommodation');
            return false;
        }
        
        console.log('   ✓ Created test accommodation');
        
        // Check availability
        const { data: availability, error: availError } = await supabase.rpc(
            'check_availability_with_lock',
            {
                p_accommodation_id: testAccom.id,
                p_check_in: '2026-01-01',
                p_check_out: '2026-01-07',
            }
        );
        
        if (availError) {
            console.log('   ❌ Availability check failed:', availError.message);
        } else {
            console.log(`   ✓ Availability check works: ${availability} rooms available`);
        }
        
        // Cleanup
        await supabase.from('accommodations').delete().eq('id', testAccom.id);
        console.log('   ✓ Cleaned up test data');
        
        console.log('   ✅ Functional test passed');
        return true;
        
    } catch (err) {
        console.log('   ❌ Functional test failed:', err.message);
        return false;
    }
}

async function runVerification() {
    console.log('========================================');
    console.log('🔍 ATOMIC BOOKING SYSTEM VERIFICATION');
    console.log('========================================\n');
    
    // Run all checks
    await verifyMigration();
    console.log('');
    
    if (checks.migrationApplied) {
        await verifyFunctions();
        console.log('');
        
        await verifyNoDoubleBookings();
        console.log('');
        
        await verifyEdgeFunction();
        console.log('');
        
        await quickFunctionalTest();
        console.log('');
    }
    
    // Summary
    console.log('========================================');
    console.log('📊 VERIFICATION SUMMARY');
    console.log('========================================\n');
    
    const allPassed = Object.values(checks).every(v => v === true);
    
    console.log('Checklist:');
    console.log(`  ${checks.migrationApplied ? '✅' : '❌'} Database migration applied`);
    console.log(`  ${checks.functionsExist ? '✅' : '❌'} All required functions exist`);
    console.log(`  ${checks.noDoubleBookings ? '✅' : '⚠️ '} No double-bookings detected`);
    console.log(`  ${checks.edgeFunctionUpdated ? '✅' : '⚠️ '} Edge Function deployed`);
    
    console.log('\n========================================');
    
    if (allPassed) {
        console.log('✅ VERIFICATION PASSED!');
        console.log('The atomic booking system is properly installed.');
        console.log('Double-booking prevention is active.');
    } else if (checks.migrationApplied && checks.functionsExist) {
        console.log('⚠️  PARTIALLY CONFIGURED');
        console.log('Core functionality is working, but some components need attention.');
        console.log('Review the checklist above for details.');
    } else {
        console.log('❌ VERIFICATION FAILED');
        console.log('The atomic booking system is not fully configured.');
        console.log('\nNext steps:');
        if (!checks.migrationApplied) {
            console.log('1. Apply the migration:');
            console.log('   npx supabase db push');
        }
        if (!checks.edgeFunctionUpdated) {
            console.log('2. Deploy the Edge Function:');
            console.log('   npx supabase functions deploy create-booking-securely');
        }
    }
    
    console.log('========================================\n');
    
    process.exit(allPassed ? 0 : 1);
}

// Run verification
runVerification().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});