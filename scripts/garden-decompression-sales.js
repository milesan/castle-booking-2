import { config } from 'dotenv';
import { createClient } from '@supabase/supabase-js';

// Load environment variables
config();

// Initialize Supabase client
const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
);

async function getGardenDecompressionSales() {
  try {
    console.log('Fetching Garden Decompression sales data...\n');

    // Query bookings with garden addon details
    const { data: gardenBookings, error: gardenError } = await supabase
      .from('bookings')
      .select('*, auth.users(email, raw_user_meta_data)')
      .not('garden_addon_details', 'is', null)
      .eq('status', 'confirmed');

    if (gardenError) {
      console.error('Error fetching garden bookings:', gardenError);
      return;
    }

    // Query Garden-only bookings (special accommodation)
    const { data: gardenOnlyBookings, error: gardenOnlyError } = await supabase
      .from('bookings')
      .select('*, accommodations(title), auth.users(email, raw_user_meta_data)')
      .eq('accommodations.title', 'Garden Decompression (No Castle Accommodation)')
      .eq('status', 'confirmed');

    if (gardenOnlyError) {
      console.error('Error fetching garden-only bookings:', gardenOnlyError);
    }

    // Process results
    const gardenAddonCount = gardenBookings ? gardenBookings.length : 0;
    const gardenOnlyCount = gardenOnlyBookings ? gardenOnlyBookings.length : 0;
    const totalGardenSales = gardenAddonCount + gardenOnlyCount;

    console.log('=== GARDEN DECOMPRESSION SALES REPORT ===\n');
    console.log(`Total Garden Decompression Sales: ${totalGardenSales}`);
    console.log(`- Garden Add-ons (with Castle booking): ${gardenAddonCount}`);
    console.log(`- Garden-Only bookings: ${gardenOnlyCount}`);

    if (gardenBookings && gardenBookings.length > 0) {
      console.log('\n--- Garden Add-on Details ---');
      let totalAddonRevenue = 0;
      
      gardenBookings.forEach((booking, index) => {
        const gardenDetails = booking.garden_addon_details;
        const price = gardenDetails?.price || 0;
        totalAddonRevenue += parseFloat(price);
        
        console.log(`\n${index + 1}. Booking ID: ${booking.id}`);
        console.log(`   Guest: ${booking.auth?.users?.email || 'Unknown'}`);
        console.log(`   Option: ${gardenDetails?.option_name || 'N/A'}`);
        console.log(`   Dates: ${gardenDetails?.start_date || 'N/A'} to ${gardenDetails?.end_date || 'N/A'}`);
        console.log(`   Price: €${price}`);
        console.log(`   Booking Created: ${new Date(booking.created_at).toLocaleDateString()}`);
      });
      
      console.log(`\nTotal Garden Add-on Revenue: €${totalAddonRevenue.toFixed(2)}`);
    }

    if (gardenOnlyBookings && gardenOnlyBookings.length > 0) {
      console.log('\n--- Garden-Only Booking Details ---');
      let totalGardenOnlyRevenue = 0;
      
      gardenOnlyBookings.forEach((booking, index) => {
        const price = booking.total_price || 0;
        totalGardenOnlyRevenue += price;
        
        console.log(`\n${index + 1}. Booking ID: ${booking.id}`);
        console.log(`   Guest: ${booking.auth?.users?.email || 'Unknown'}`);
        console.log(`   Check-in: ${booking.check_in}`);
        console.log(`   Check-out: ${booking.check_out}`);
        console.log(`   Total Price: €${price}`);
        console.log(`   Booking Created: ${new Date(booking.created_at).toLocaleDateString()}`);
      });
      
      console.log(`\nTotal Garden-Only Revenue: €${totalGardenOnlyRevenue.toFixed(2)}`);
    }

    // Also check for any pending/processing garden bookings
    const { data: pendingGarden, error: pendingError } = await supabase
      .from('bookings')
      .select('id')
      .not('garden_addon_details', 'is', null)
      .in('status', ['pending', 'processing']);

    if (!pendingError && pendingGarden && pendingGarden.length > 0) {
      console.log(`\nNote: There are ${pendingGarden.length} pending/processing Garden bookings not included in this count.`);
    }

  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

// Run the report
getGardenDecompressionSales();