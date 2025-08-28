import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function forceUpdateAuction() {
  console.log('Force updating all auction settings...\n');
  
  try {
    // Force update auction_config
    const { error: configError } = await supabase
      .from('auction_config')
      .update({
        auction_start_time: '2025-08-15T00:00:00Z',
        auction_end_time: '2025-09-14T23:59:59Z',
        price_drop_interval_hours: 24,  // Daily reductions
        is_active: true
      })
      .eq('id', 'fd02b8f0-daa8-466b-b788-3f42f97d843f');
    
    if (configError) {
      console.error('Error updating config:', configError);
    } else {
      console.log('✅ Updated auction_config');
    }
    
    // Update ALL Standard Chamber rooms
    const { error: standardError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 4800,
        auction_floor_price: 800,
        auction_current_price: 4800,
        auction_buyer_id: null,
        auction_purchase_price: null,
        auction_purchased_at: null
      })
      .eq('auction_tier', 'standard_chamber');
    
    if (standardError) {
      console.error('Error updating Standard Chambers:', standardError);
    } else {
      console.log('✅ Updated Standard Chamber pricing to €4,800 → €800');
    }
    
    // Update Tower Suite rooms
    const { error: towerError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 15000,
        auction_floor_price: 4000,
        auction_current_price: 15000,
        auction_buyer_id: null,
        auction_purchase_price: null,
        auction_purchased_at: null
      })
      .eq('auction_tier', 'tower_suite');
    
    if (towerError) {
      console.error('Error updating Tower Suites:', towerError);
    } else {
      console.log('✅ Updated Tower Suite pricing to €15,000 → €4,000');
    }
    
    // Update Noble Quarter rooms
    const { error: nobleError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 10000,
        auction_floor_price: 2000,
        auction_current_price: 10000,
        auction_buyer_id: null,
        auction_purchase_price: null,
        auction_purchased_at: null
      })
      .eq('auction_tier', 'noble_quarter');
    
    if (nobleError) {
      console.error('Error updating Noble Quarters:', nobleError);
    } else {
      console.log('✅ Updated Noble Quarter pricing to €10,000 → €2,000');
    }
    
    // Verify all updates
    console.log('\n📊 Verification:');
    
    const { data: verifyConfig } = await supabase
      .from('auction_config')
      .select('*')
      .single();
    
    console.log('Auction Config:');
    console.log('  Start:', verifyConfig?.auction_start_time);
    console.log('  End:', verifyConfig?.auction_end_time);
    console.log('  Interval:', verifyConfig?.price_drop_interval_hours, 'hours');
    
    const { data: verifyStandard } = await supabase
      .from('accommodations')
      .select('auction_start_price, auction_floor_price')
      .eq('auction_tier', 'standard_chamber')
      .limit(1)
      .single();
    
    console.log('\nStandard Chamber:');
    console.log('  Start: €', verifyStandard?.auction_start_price);
    console.log('  Floor: €', verifyStandard?.auction_floor_price);
    
    const { data: verifyTower } = await supabase
      .from('accommodations')
      .select('auction_start_price, auction_floor_price')
      .eq('auction_tier', 'tower_suite')
      .limit(1)
      .single();
    
    console.log('\nTower Suite:');
    console.log('  Start: €', verifyTower?.auction_start_price);
    console.log('  Floor: €', verifyTower?.auction_floor_price);
    
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

forceUpdateAuction();