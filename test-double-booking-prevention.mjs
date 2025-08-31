#!/usr/bin/env node

/**
 * Test Script for Double-Booking Prevention
 * 
 * This script simulates multiple concurrent users trying to book the same room
 * to verify that the atomic locking mechanism prevents double-bookings.
 * 
 * Usage:
 * 1. Set your Supabase credentials as environment variables:
 *    export SUPABASE_URL="your-project-url"
 *    export SUPABASE_SERVICE_KEY="your-service-role-key"
 * 
 * 2. Run the test:
 *    node test-double-booking-prevention.mjs
 */

import { createClient } from '@supabase/supabase-js';

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error('❌ Error: Missing Supabase credentials');
    console.error('Please set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Test configuration
const TEST_CONFIG = {
    checkInDate: '2025-12-01',
    checkOutDate: '2025-12-07',
    numberOfConcurrentBookings: 5,  // Try to create 5 bookings simultaneously
    accommodationInventory: 2,      // But only 2 rooms are available
};

// Helper functions
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

const createTestUser = async (index) => {
    const email = `test_${Date.now()}_${index}@example.com`;
    const { data, error } = await supabase.auth.admin.createUser({
        email,
        password: 'TestPassword123!',
        email_confirm: true,
    });
    
    if (error) throw error;
    return data.user;
};

const createTestAccommodation = async () => {
    const { data, error } = await supabase
        .from('accommodations')
        .insert({
            title: `Test Room ${Date.now()} - Double Booking Test`,
            type: 'room',
            inventory: TEST_CONFIG.accommodationInventory,
            is_unlimited: false,
            price: 100,
            description: 'Test accommodation for verifying atomic booking',
        })
        .select()
        .single();
    
    if (error) throw error;
    return data;
};

const attemptBooking = async (accommodationId, userId, attemptNumber) => {
    const startTime = Date.now();
    
    try {
        console.log(`  🔄 Attempt ${attemptNumber}: Starting booking for user ${userId.substring(0, 8)}...`);
        
        const { data, error } = await supabase.rpc('create_booking_with_atomic_lock', {
            p_accommodation_id: accommodationId,
            p_user_id: userId,
            p_check_in: TEST_CONFIG.checkInDate,
            p_check_out: TEST_CONFIG.checkOutDate,
            p_total_price: 600,
            p_status: 'confirmed',
        });
        
        const duration = Date.now() - startTime;
        
        if (error) {
            if (error.message.includes('No availability')) {
                console.log(`  ❌ Attempt ${attemptNumber}: REJECTED (no availability) - ${duration}ms`);
                return { success: false, reason: 'no_availability', duration };
            }
            throw error;
        }
        
        console.log(`  ✅ Attempt ${attemptNumber}: SUCCESS! Booking ID: ${data} - ${duration}ms`);
        return { success: true, bookingId: data, duration };
        
    } catch (error) {
        const duration = Date.now() - startTime;
        console.log(`  ❌ Attempt ${attemptNumber}: ERROR - ${error.message} - ${duration}ms`);
        return { success: false, reason: 'error', error: error.message, duration };
    }
};

const runTest = async () => {
    console.log('🧪 Double-Booking Prevention Test');
    console.log('==================================\n');
    
    let testUsers = [];
    let testAccommodation = null;
    let bookingResults = [];
    
    try {
        // Step 1: Setup test data
        console.log('📋 Step 1: Setting up test data...');
        
        // Create test accommodation
        testAccommodation = await createTestAccommodation();
        console.log(`  ✓ Created test accommodation: ${testAccommodation.title}`);
        console.log(`    Inventory: ${testAccommodation.inventory} rooms`);
        
        // Create test users
        console.log('  Creating test users...');
        for (let i = 0; i < TEST_CONFIG.numberOfConcurrentBookings; i++) {
            const user = await createTestUser(i);
            testUsers.push(user);
        }
        console.log(`  ✓ Created ${testUsers.length} test users\n`);
        
        // Step 2: Check initial availability
        console.log('📋 Step 2: Checking initial availability...');
        const { data: availabilityBefore } = await supabase.rpc('check_availability_with_lock', {
            p_accommodation_id: testAccommodation.id,
            p_check_in: TEST_CONFIG.checkInDate,
            p_check_out: TEST_CONFIG.checkOutDate,
        });
        console.log(`  ✓ Initial availability: ${availabilityBefore} rooms\n`);
        
        // Step 3: Simulate concurrent bookings
        console.log('📋 Step 3: Simulating concurrent booking attempts...');
        console.log(`  Attempting ${TEST_CONFIG.numberOfConcurrentBookings} bookings for ${TEST_CONFIG.accommodationInventory} available rooms...\n`);
        
        // Create all booking promises to run concurrently
        const bookingPromises = testUsers.map((user, index) => 
            attemptBooking(testAccommodation.id, user.id, index + 1)
        );
        
        // Execute all bookings simultaneously
        bookingResults = await Promise.all(bookingPromises);
        
        // Step 4: Analyze results
        console.log('\n📋 Step 4: Analyzing results...');
        
        const successfulBookings = bookingResults.filter(r => r.success);
        const rejectedBookings = bookingResults.filter(r => !r.success && r.reason === 'no_availability');
        const erroredBookings = bookingResults.filter(r => !r.success && r.reason === 'error');
        
        console.log(`  Successful bookings: ${successfulBookings.length}`);
        console.log(`  Rejected (no availability): ${rejectedBookings.length}`);
        console.log(`  Errors: ${erroredBookings.length}`);
        
        // Step 5: Verify final state
        console.log('\n📋 Step 5: Verifying final state...');
        
        // Check final availability
        const { data: availabilityAfter } = await supabase.rpc('check_availability_with_lock', {
            p_accommodation_id: testAccommodation.id,
            p_check_in: TEST_CONFIG.checkInDate,
            p_check_out: TEST_CONFIG.checkOutDate,
        });
        console.log(`  Final availability: ${availabilityAfter} rooms`);
        
        // Check for double-bookings
        const { data: doubleBookings } = await supabase.rpc('check_for_double_bookings');
        const hasDoubleBookings = doubleBookings && doubleBookings.length > 0;
        
        // Step 6: Test results
        console.log('\n==================================');
        console.log('📊 TEST RESULTS');
        console.log('==================================\n');
        
        let testPassed = true;
        
        // Check 1: Correct number of successful bookings
        if (successfulBookings.length === TEST_CONFIG.accommodationInventory) {
            console.log(`✅ PASS: Exactly ${TEST_CONFIG.accommodationInventory} bookings succeeded (matching inventory)`);
        } else {
            console.log(`❌ FAIL: ${successfulBookings.length} bookings succeeded, expected ${TEST_CONFIG.accommodationInventory}`);
            testPassed = false;
        }
        
        // Check 2: Correct number of rejections
        const expectedRejections = TEST_CONFIG.numberOfConcurrentBookings - TEST_CONFIG.accommodationInventory;
        if (rejectedBookings.length === expectedRejections) {
            console.log(`✅ PASS: ${rejectedBookings.length} bookings were correctly rejected`);
        } else {
            console.log(`❌ FAIL: ${rejectedBookings.length} bookings rejected, expected ${expectedRejections}`);
            testPassed = false;
        }
        
        // Check 3: No double-bookings
        if (!hasDoubleBookings) {
            console.log('✅ PASS: No double-bookings detected');
        } else {
            console.log(`❌ FAIL: Double-bookings detected!`);
            testPassed = false;
        }
        
        // Check 4: Final availability is correct
        if (availabilityAfter === 0) {
            console.log('✅ PASS: Final availability is 0 (fully booked)');
        } else {
            console.log(`⚠️  WARNING: Final availability is ${availabilityAfter} (expected 0)`);
        }
        
        // Performance stats
        console.log('\n📈 Performance Statistics:');
        const avgDuration = bookingResults.reduce((sum, r) => sum + r.duration, 0) / bookingResults.length;
        console.log(`  Average booking attempt duration: ${avgDuration.toFixed(2)}ms`);
        console.log(`  Fastest: ${Math.min(...bookingResults.map(r => r.duration))}ms`);
        console.log(`  Slowest: ${Math.max(...bookingResults.map(r => r.duration))}ms`);
        
        // Final verdict
        console.log('\n==================================');
        if (testPassed) {
            console.log('🎉 ALL TESTS PASSED!');
            console.log('The atomic booking system successfully prevents double-bookings.');
        } else {
            console.log('⚠️  SOME TESTS FAILED');
            console.log('Please review the results above.');
        }
        console.log('==================================');
        
    } catch (error) {
        console.error('\n❌ Test failed with error:', error.message);
        console.error(error);
    } finally {
        // Cleanup
        console.log('\n🧹 Cleaning up test data...');
        
        try {
            // Delete test bookings
            if (testAccommodation) {
                await supabase
                    .from('bookings')
                    .delete()
                    .eq('accommodation_id', testAccommodation.id);
                console.log('  ✓ Deleted test bookings');
                
                // Delete test accommodation
                await supabase
                    .from('accommodations')
                    .delete()
                    .eq('id', testAccommodation.id);
                console.log('  ✓ Deleted test accommodation');
            }
            
            // Delete test users
            for (const user of testUsers) {
                await supabase.auth.admin.deleteUser(user.id);
            }
            console.log(`  ✓ Deleted ${testUsers.length} test users`);
            
        } catch (cleanupError) {
            console.error('  ⚠️  Cleanup error:', cleanupError.message);
        }
    }
};

// Run the test
console.clear();
runTest().then(() => {
    process.exit(0);
}).catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
});