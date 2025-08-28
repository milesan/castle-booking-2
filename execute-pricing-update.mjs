import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function updateStandardPricing() {
  console.log('Updating Standard Chamber pricing and auction configuration...');
  
  try {
    // Update auction_config to 24-hour intervals for daily reductions
    const { data: existingConfigs } = await supabase
      .from('auction_config')
      .select('id');
    
    if (existingConfigs && existingConfigs.length > 0) {
      const { error: configError } = await supabase
        .from('auction_config')
        .update({
          price_drop_interval_hours: 24 // Daily reductions instead of hourly
        })
        .eq('id', existingConfigs[0].id);
      
      if (configError) {
        console.error('Error updating auction_config:', configError);
      } else {
        console.log('✅ Updated auction_config to 24-hour price reductions');
      }
    }
    
    // Update Standard Chamber pricing
    const { data: updatedStandard, error: standardError } = await supabase
      .from('accommodations')
      .update({
        auction_start_price: 4800,  // Changed from 5000
        auction_floor_price: 800,   // Changed from 1000
        auction_current_price: 4800, // Reset to new start price
        auction_buyer_id: null,
        auction_purchase_price: null,
        auction_purchased_at: null
      })
      .eq('auction_tier', 'standard_chamber')
      .eq('is_in_auction', true)
      .select();
    
    if (standardError) {
      console.error('Error updating Standard Chamber pricing:', standardError);
    } else {
      console.log(`✅ Updated ${updatedStandard?.length || 0} Standard Chamber accommodations`);
      console.log('  New pricing: €4,800 → €800 (€133/day reduction)');
    }
    
    // Verify the updates
    const { data: verifyConfig } = await supabase
      .from('auction_config')
      .select('price_drop_interval_hours')
      .single();
    
    const { data: verifyStandard } = await supabase
      .from('accommodations')
      .select('auction_start_price, auction_floor_price')
      .eq('auction_tier', 'standard_chamber')
      .eq('is_in_auction', true)
      .limit(1)
      .single();
    
    console.log('\n📊 Verification:');
    console.log('  Price drop interval:', verifyConfig?.price_drop_interval_hours, 'hours');
    console.log('  Standard Chamber start price: €', verifyStandard?.auction_start_price);
    console.log('  Standard Chamber floor price: €', verifyStandard?.auction_floor_price);
    
  } catch (error) {
    console.error('Unexpected error:', error);
  }
}

updateStandardPricing();