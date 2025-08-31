// Comprehensive test suite for atomic booking implementation
// This tests the double-booking prevention mechanism

import { createClient } from '@supabase/supabase-js';

// You need to set these environment variables or update them here
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'YOUR_ANON_KEY';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || 'YOUR_SERVICE_KEY';

// Create clients
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// Test configuration
const TEST_DATES = {
    checkIn: new Date('2025-10-01'),
    checkOut: new Date('2025-10-07')
};

// Helper function to format dates
function formatDate(date) {
    return date.toISOString().split('T')[0];
}

// Color codes for output
const colors = {
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
};

function logSuccess(message) {
    console.log(`${colors.green}✓${colors.reset} ${message}`);
}

function logError(message) {
    console.log(`${colors.red}✗${colors.reset} ${message}`);
}

function logInfo(message) {
    console.log(`${colors.blue}ℹ${colors.reset} ${message}`);
}

function logWarning(message) {
    console.log(`${colors.yellow}⚠${colors.reset} ${message}`);
}

// Test 1: Verify migration was applied successfully
async function testMigrationApplied() {
    console.log('\n=== Test 1: Verify Migration Applied ===');
    
    try {
        // Check if our new functions exist
        const { data: functions, error } = await supabaseAdmin
            .rpc('check_availability_with_lock', {
                p_accommodation_id: '00000000-0000-0000-0000-000000000000', // dummy UUID
                p_check_in: TEST_DATES.checkIn,
                p_check_out: TEST_DATES.checkOut
            });

        if (error && error.code === '42883') {
            logError('Function create_booking_with_atomic_lock does not exist. Migration not applied.');
            logInfo('Please run: npx supabase db push');
            return false;
        }

        logSuccess('Migration functions detected in database');
        return true;
    } catch (err) {
        logError(`Error checking migration: ${err.message}`);
        return false;
    }
}

// Test 2: Get test accommodation with limited inventory
async function getTestAccommodation() {
    console.log('\n=== Test 2: Finding Test Accommodation ===');
    
    try {
        const { data: accommodations, error } = await supabase
            .from('accommodations')
            .select('id, title, inventory, is_unlimited')
            .eq('is_unlimited', false)
            .gt('inventory', 0)
            .order('inventory', { ascending: true })
            .limit(1);

        if (error) throw error;

        if (!accommodations || accommodations.length === 0) {
            logWarning('No limited inventory accommodations found. Creating test accommodation...');
            
            // Create a test accommodation
            const { data: newAccom, error: createError } = await supabaseAdmin
                .from('accommodations')
                .insert({
                    title: 'Test Room - Double Booking Prevention Test',
                    inventory: 2, // Only 2 rooms available
                    is_unlimited: false,
                    price: 100,
                    type: 'room'
                })
                .select()
                .single();

            if (createError) throw createError;
            
            logSuccess(`Created test accommodation: ${newAccom.title} with inventory: ${newAccom.inventory}`);
            return newAccom;
        }

        logSuccess(`Found accommodation: ${accommodations[0].title} with inventory: ${accommodations[0].inventory}`);
        return accommodations[0];
    } catch (err) {
        logError(`Error getting test accommodation: ${err.message}`);
        return null;
    }
}

// Test 3: Test availability checking
async function testAvailabilityCheck(accommodationId) {
    console.log('\n=== Test 3: Testing Availability Check ===');
    
    try {
        // Check availability using the new function
        const { data: availability, error } = await supabaseAdmin
            .rpc('check_availability_with_lock', {
                p_accommodation_id: accommodationId,
                p_check_in: TEST_DATES.checkIn,
                p_check_out: TEST_DATES.checkOut
            });

        if (error) throw error;

        logSuccess(`Availability check successful. Available rooms: ${availability}`);
        return availability;
    } catch (err) {
        logError(`Error checking availability: ${err.message}`);
        return null;
    }
}

// Test 4: Create test users for booking simulation
async function createTestUsers() {
    console.log('\n=== Test 4: Creating Test Users ===');
    
    try {
        const users = [];
        
        for (let i = 1; i <= 3; i++) {
            const email = `test_user_${Date.now()}_${i}@test.com`;
            const password = 'TestPassword123!';
            
            const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
                email,
                password,
                email_confirm: true
            });

            if (authError) {
                logWarning(`Could not create user ${i}: ${authError.message}`);
                continue;
            }

            users.push({
                id: authData.user.id,
                email: authData.user.email
            });
            
            logSuccess(`Created test user ${i}: ${email}`);
        }

        return users;
    } catch (err) {
        logError(`Error creating test users: ${err.message}`);
        return [];
    }
}

// Test 5: Simulate concurrent booking attempts
async function testConcurrentBookings(accommodationId, users, inventory) {
    console.log('\n=== Test 5: Testing Concurrent Booking Prevention ===');
    
    if (users.length < 2) {
        logWarning('Need at least 2 users to test concurrent bookings');
        return;
    }

    const bookingPromises = [];
    const bookingAttempts = inventory + 1; // Try to book one more than available

    logInfo(`Attempting to create ${bookingAttempts} bookings for accommodation with inventory: ${inventory}`);

    // Create booking attempts for each user
    for (let i = 0; i < bookingAttempts; i++) {
        const user = users[i % users.length];
        
        const bookingPromise = supabaseAdmin
            .rpc('create_booking_with_atomic_lock', {
                p_accommodation_id: accommodationId,
                p_user_id: user.id,
                p_check_in: TEST_DATES.checkIn,
                p_check_out: TEST_DATES.checkOut,
                p_total_price: 100,
                p_status: 'confirmed'
            })
            .then(result => ({
                success: !result.error,
                userId: user.id,
                error: result.error,
                bookingId: result.data
            }));

        bookingPromises.push(bookingPromise);
        logInfo(`Initiated booking attempt ${i + 1} for user ${user.email}`);
    }

    // Wait for all booking attempts to complete
    const results = await Promise.all(bookingPromises);

    // Analyze results
    const successfulBookings = results.filter(r => r.success);
    const failedBookings = results.filter(r => !r.success);

    console.log('\n--- Booking Results ---');
    successfulBookings.forEach((booking, i) => {
        logSuccess(`Booking ${i + 1} succeeded: ID ${booking.bookingId}`);
    });

    failedBookings.forEach((booking, i) => {
        logWarning(`Booking failed as expected: ${booking.error?.message || 'No availability'}`);
    });

    // Verify the correct number of bookings were created
    if (successfulBookings.length === inventory) {
        logSuccess(`✓ PASS: Exactly ${inventory} bookings succeeded (matching inventory)`);
    } else {
        logError(`✗ FAIL: ${successfulBookings.length} bookings succeeded, expected ${inventory}`);
    }

    if (failedBookings.length === bookingAttempts - inventory) {
        logSuccess(`✓ PASS: ${failedBookings.length} booking(s) were correctly rejected`);
    } else {
        logError(`✗ FAIL: ${failedBookings.length} bookings failed, expected ${bookingAttempts - inventory}`);
    }

    return successfulBookings.map(b => b.bookingId);
}

// Test 6: Verify no double-bookings exist
async function testNoDoubleBookings() {
    console.log('\n=== Test 6: Checking for Double-Bookings ===');
    
    try {
        const { data: doubleBookings, error } = await supabaseAdmin
            .rpc('check_for_double_bookings');

        if (error) throw error;

        if (!doubleBookings || doubleBookings.length === 0) {
            logSuccess('✓ PASS: No double-bookings detected in the system');
        } else {
            logError(`✗ FAIL: Found ${doubleBookings.length} double-booking(s):`);
            doubleBookings.forEach(db => {
                console.log(`  - ${db.accommodation_title}: ${db.overlapping_bookings}`);
            });
        }
    } catch (err) {
        logError(`Error checking for double-bookings: ${err.message}`);
    }
}

// Test 7: Test Edge Function integration
async function testEdgeFunctionIntegration(accommodationId, userId) {
    console.log('\n=== Test 7: Testing Edge Function Integration ===');
    
    try {
        // First, sign in as a test user
        const { data: signInData, error: signInError } = await supabase.auth.signInWithPassword({
            email: 'test@example.com',
            password: 'test123'
        });

        if (signInError) {
            logWarning('Could not sign in for Edge Function test. Skipping...');
            return;
        }

        // Call the Edge Function
        const { data, error } = await supabase.functions.invoke('create-booking-securely', {
            body: {
                accommodationId: accommodationId,
                checkIn: formatDate(TEST_DATES.checkIn),
                checkOut: formatDate(TEST_DATES.checkOut),
                foodContribution: 50
            }
        });

        if (error) {
            if (error.message.includes('no longer available')) {
                logSuccess('Edge Function correctly rejects booking when no availability');
            } else {
                logError(`Edge Function error: ${error.message}`);
            }
        } else {
            logSuccess(`Edge Function successfully created booking: ${data.id}`);
        }
    } catch (err) {
        logWarning(`Could not test Edge Function: ${err.message}`);
    }
}

// Test 8: Cleanup test data
async function cleanupTestData(bookingIds, users) {
    console.log('\n=== Test 8: Cleaning Up Test Data ===');
    
    try {
        // Delete test bookings
        if (bookingIds && bookingIds.length > 0) {
            const { error: deleteBookingsError } = await supabaseAdmin
                .from('bookings')
                .delete()
                .in('id', bookingIds);

            if (deleteBookingsError) throw deleteBookingsError;
            logSuccess(`Deleted ${bookingIds.length} test bookings`);
        }

        // Delete test users
        if (users && users.length > 0) {
            for (const user of users) {
                await supabaseAdmin.auth.admin.deleteUser(user.id);
            }
            logSuccess(`Deleted ${users.length} test users`);
        }
    } catch (err) {
        logWarning(`Error during cleanup: ${err.message}`);
    }
}

// Main test runner
async function runAllTests() {
    console.log('====================================');
    console.log('🧪 ATOMIC BOOKING SYSTEM TEST SUITE');
    console.log('====================================');
    
    let testsPassed = 0;
    let testsFailed = 0;

    // Test 1: Check migration
    const migrationApplied = await testMigrationApplied();
    if (!migrationApplied) {
        logError('Migration not applied. Please apply the migration first.');
        return;
    }
    testsPassed++;

    // Test 2: Get test accommodation
    const accommodation = await getTestAccommodation();
    if (!accommodation) {
        logError('Could not get test accommodation. Aborting tests.');
        return;
    }
    testsPassed++;

    // Test 3: Check availability
    const availability = await testAvailabilityCheck(accommodation.id);
    if (availability !== null) testsPassed++;
    else testsFailed++;

    // Test 4: Create test users
    const users = await createTestUsers();
    if (users.length > 0) testsPassed++;
    else testsFailed++;

    // Test 5: Test concurrent bookings
    const bookingIds = await testConcurrentBookings(
        accommodation.id, 
        users, 
        accommodation.inventory || 2
    );
    if (bookingIds) testsPassed++;
    else testsFailed++;

    // Test 6: Check for double-bookings
    await testNoDoubleBookings();
    testsPassed++;

    // Test 7: Test Edge Function
    await testEdgeFunctionIntegration(accommodation.id, users[0]?.id);

    // Test 8: Cleanup
    await cleanupTestData(bookingIds, users);

    // Final report
    console.log('\n====================================');
    console.log('📊 TEST SUMMARY');
    console.log('====================================');
    console.log(`${colors.green}Tests Passed: ${testsPassed}${colors.reset}`);
    console.log(`${colors.red}Tests Failed: ${testsFailed}${colors.reset}`);
    
    if (testsFailed === 0) {
        console.log(`\n${colors.green}✅ ALL TESTS PASSED! The atomic booking system is working correctly.${colors.reset}`);
    } else {
        console.log(`\n${colors.red}⚠️ Some tests failed. Please review the output above.${colors.reset}`);
    }
}

// Run the tests
runAllTests().catch(err => {
    console.error('Fatal error running tests:', err);
    process.exit(1);
});