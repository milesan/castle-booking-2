import { createClient } from '@supabase/supabase-js';
import 'dotenv/config';

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseKey = process.env.VITE_SUPABASE_ANON_KEY;

const supabase = createClient(supabaseUrl, supabaseKey);

async function debugAuctionData() {
  console.log('Fetching auction data...\n');
  
  // Check auction_config
  const { data: configs } = await supabase
    .from('auction_config')
    .select('*');
  
  console.log('Auction Configs:', configs?.length || 0, 'records');
  configs?.forEach(config => {
    console.log('  Config ID:', config.id);
    console.log('  Start:', config.auction_start_time);
    console.log('  End:', config.auction_end_time);
    console.log('  Interval hours:', config.price_drop_interval_hours);
    console.log('  Active:', config.is_active);
    console.log('---');
  });
  
  // Check Standard Chamber accommodations
  const { data: standardRooms } = await supabase
    .from('accommodations')
    .select('id, title, auction_tier, is_in_auction, auction_start_price, auction_floor_price, auction_current_price')
    .eq('auction_tier', 'standard_chamber');
  
  console.log('\nStandard Chamber Accommodations:', standardRooms?.length || 0, 'records');
  standardRooms?.forEach(room => {
    console.log('  Title:', room.title);
    console.log('  In Auction:', room.is_in_auction);
    console.log('  Start Price:', room.auction_start_price);
    console.log('  Floor Price:', room.auction_floor_price);
    console.log('  Current Price:', room.auction_current_price);
    console.log('---');
  });
}

debugAuctionData();