import { createClient } from '@supabase/supabase-js';

// Read environment variables
const supabaseUrl = 'https://ywsbmarhoyxercqatbfy.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3c2JtYXJob3l4ZXJjcWF0YmZ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ1MDA2MDgsImV4cCI6MjA3MDA3NjYwOH0.s9yyutya3lLOhHvvjqPDqvg7v7y2e72KPTFp4ZICiQg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function executeAuctionSetup() {
  console.log('Setting up Dutch Auction with August 15, 2025 start date...\n');

  try {
    // First check if config exists
    console.log('1. Checking auction configuration...');
    const { data: existingConfigs, error: checkError } = await supabase
      .from('auction_config')
      .select('id');

    if (existingConfigs && existingConfigs.length > 0) {
      // Update existing config
      console.log('   Updating existing auction config with ID:', existingConfigs[0].id);
      const { data: configData, error: configError } = await supabase
        .from('auction_config')
        .update({
          auction_start_time: '2025-08-15T00:00:00Z',
          auction_end_time: '2025-09-14T23:59:59Z',
          price_drop_interval_hours: 1,
          is_active: true
        })
        .eq('id', existingConfigs[0].id);

      if (configError) throw configError;
      console.log('   ✓ Auction config updated');
    } else {
      // Create new config
      console.log('   Creating new auction config...');
      const { data: newConfig, error: createError } = await supabase
        .from('auction_config')
        .insert({
          auction_start_time: '2025-08-15T00:00:00Z',
          auction_end_time: '2025-09-14T23:59:59Z',
          price_drop_interval_hours: 1,
          is_active: true
        })
        .select()
        .single();
      
      if (createError) throw createError;
      console.log('   ✓ Auction config created');
    }

    // Update Tower Suites
    console.log('2. Updating Tower Suite prices (€15,000 → €3,000)...');
    const { error: towerError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 15000,
        auction_floor_price: 3000,
        auction_current_price: 15000
      })
      .eq('auction_tier', 'tower_suite')
      .eq('is_in_auction', true);

    if (towerError) throw towerError;
    console.log('   ✓ Tower Suites updated');

    // Update Noble Quarters
    console.log('3. Updating Noble Quarter prices (€10,000 → €2,000)...');
    const { error: nobleError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 10000,
        auction_floor_price: 2000,
        auction_current_price: 10000
      })
      .eq('auction_tier', 'noble_quarter')
      .eq('is_in_auction', true);

    if (nobleError) throw nobleError;
    console.log('   ✓ Noble Quarters updated');

    // Update Standard Chambers
    console.log('4. Updating Standard Chamber prices (€5,000 → €1,000)...');
    const { error: standardError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 5000,
        auction_floor_price: 1000,
        auction_current_price: 5000
      })
      .eq('auction_tier', 'standard_chamber')
      .eq('is_in_auction', true);

    if (standardError) throw standardError;
    console.log('   ✓ Standard Chambers updated');

    // Clear any previous purchases
    console.log('5. Clearing previous purchases...');
    const { error: clearError } = await supabase
      .from('accommodations')
      .update({
        auction_buyer_id: null,
        auction_purchase_price: null,
        auction_purchased_at: null
      })
      .eq('is_in_auction', true);

    if (clearError) throw clearError;
    console.log('   ✓ Previous purchases cleared');

    // Verify the setup
    console.log('\n6. Verifying auction setup...');
    
    // Check config
    const { data: config } = await supabase
      .from('auction_config')
      .select('*')
      .single();
    
    console.log('\n   Auction Configuration:');
    console.log(`   - Start: ${new Date(config.auction_start_time).toLocaleDateString()}`);
    console.log(`   - End: ${new Date(config.auction_end_time).toLocaleDateString()}`);
    console.log(`   - Drop interval: Every ${config.price_drop_interval_hours} hour(s)`);
    console.log(`   - Active: ${config.is_active ? 'Yes' : 'No'}`);

    // Check room counts by tier
    const { data: tiers } = await supabase
      .from('accommodations')
      .select('auction_tier')
      .eq('is_in_auction', true)
      .not('auction_tier', 'is', null);

    const tierCounts = {};
    tiers.forEach(room => {
      tierCounts[room.auction_tier] = (tierCounts[room.auction_tier] || 0) + 1;
    });

    console.log('\n   Room Distribution:');
    console.log(`   - Tower Suites: ${tierCounts['tower_suite'] || 0} rooms`);
    console.log(`   - Noble Quarters: ${tierCounts['noble_quarter'] || 0} rooms`);
    console.log(`   - Standard Chambers: ${tierCounts['standard_chamber'] || 0} rooms`);

    console.log('\n✅ Auction setup complete!');
    console.log('The Dutch auction will start on August 15, 2025 at midnight.');
    console.log('Prices will drop hourly until September 14, 2025.');

  } catch (error) {
    console.error('❌ Error setting up auction:', error);
    process.exit(1);
  }
}

executeAuctionSetup();