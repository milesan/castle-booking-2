import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { differenceInDays } from 'date-fns';

// Simplified Dutch Auction hook for integration into existing booking flow
export interface AuctionConfig {
  is_active: boolean;
  auction_end_date: Date;
}

export interface AuctionPricing {
  tier: 'tower_suite' | 'noble_quarter' | 'standard_chamber' | null;
  currentPrice: number;
  dailyDrop: number;
  floorPrice: number;
}

// Price configuration
const TIER_CONFIG = {
  tower_suite: {
    startPrice: 15000,
    floorPrice: 3000,
    dailyDrop: 343, // (15000-3000)/35 days
  },
  noble_quarter: {
    startPrice: 10000,
    floorPrice: 2000,
    dailyDrop: 229, // (10000-2000)/35 days
  },
  standard_chamber: {
    startPrice: 5000,
    floorPrice: 1000,
    dailyDrop: 114, // (5000-1000)/35 days
  },
};

export function useDutchAuctionSimple() {
  const [isActive, setIsActive] = useState(false);
  const [auctionEndDate] = useState(new Date('2025-09-14'));
  const [roomTiers, setRoomTiers] = useState<Record<string, string>>({});
  const [timeToNextDrop, setTimeToNextDrop] = useState<string>('');
  const auctionStartDate = new Date('2025-08-15T00:00:00Z');

  // Calculate current price for a tier
  const calculateCurrentPrice = useCallback((tier: keyof typeof TIER_CONFIG, buyNow: boolean = false): number => {
    const config = TIER_CONFIG[tier];
    
    // If buy now before auction starts, return start price
    if (buyNow) {
      return config.startPrice;
    }
    
    const today = new Date();
    
    // If auction hasn't started yet, return start price
    if (today < auctionStartDate) {
      return config.startPrice;
    }
    
    // Calculate hours elapsed since auction start
    const hoursElapsed = Math.floor((today.getTime() - auctionStartDate.getTime()) / (1000 * 60 * 60));
    
    // Calculate total hours in auction period (30 days = 720 hours)
    const totalHours = 30 * 24; // 720 hours
    
    // Calculate hourly drop rate
    const totalPriceDrop = config.startPrice - config.floorPrice;
    const hourlyDrop = totalPriceDrop / totalHours;
    
    // Calculate current price based on hours elapsed
    const currentDrop = hoursElapsed * hourlyDrop;
    const currentPrice = Math.max(
      config.startPrice - currentDrop,
      config.floorPrice
    );
    
    return Math.round(currentPrice);
  }, [auctionStartDate]);

  // Get auction price for a specific accommodation
  const getAuctionPrice = useCallback((accommodationId: string): number | null => {
    const tier = roomTiers[accommodationId];
    if (!tier || !isActive) return null;
    
    return calculateCurrentPrice(tier as keyof typeof TIER_CONFIG);
  }, [roomTiers, isActive, calculateCurrentPrice]);

  // Get pricing info for a specific accommodation
  const getPricingInfo = useCallback((accommodationId: string): AuctionPricing | null => {
    const tier = roomTiers[accommodationId];
    if (!tier || !isActive) return null;
    
    const tierKey = tier as keyof typeof TIER_CONFIG;
    const config = TIER_CONFIG[tierKey];
    
    return {
      tier: tierKey,
      currentPrice: calculateCurrentPrice(tierKey),
      dailyDrop: config.dailyDrop,
      floorPrice: config.floorPrice,
    };
  }, [roomTiers, isActive, calculateCurrentPrice]);

  // Fetch auction config and room tiers
  const fetchAuctionData = useCallback(async () => {
    try {
      // Check if auction is active
      const { data: configData } = await supabase
        .from('auction_config')
        .select('is_active')
        .single();
      
      setIsActive(configData?.is_active || false);
      
      // Fetch room tier assignments
      const { data: roomsData } = await supabase
        .from('accommodations')
        .select('id, auction_tier')
        .not('auction_tier', 'is', null);
      
      if (roomsData) {
        const tiers: Record<string, string> = {};
        roomsData.forEach(room => {
          if (room.auction_tier) {
            tiers[room.id] = room.auction_tier;
          }
        });
        setRoomTiers(tiers);
      }
    } catch (error) {
      console.error('Error fetching auction data:', error);
    }
  }, []);

  // Update countdown timer (to next hour)
  useEffect(() => {
    const now = new Date();
    
    // If auction hasn't started, show countdown to start
    if (now < auctionStartDate) {
      const diff = auctionStartDate.getTime() - now.getTime();
      const days = Math.floor(diff / (1000 * 60 * 60 * 24));
      const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
      setTimeToNextDrop(`Starts in ${days}d ${hours}h`);
      return;
    }
    
    if (!isActive) {
      setTimeToNextDrop('');
      return;
    }

    const updateCountdown = () => {
      const now = new Date();
      const nextHour = new Date(now);
      nextHour.setHours(nextHour.getHours() + 1, 0, 0, 0);
      
      const diff = nextHour.getTime() - now.getTime();
      const minutes = Math.floor(diff / (1000 * 60));
      const seconds = Math.floor((diff % (1000 * 60)) / 1000);
      
      setTimeToNextDrop(`${minutes}m ${seconds}s`);
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000); // Update every second

    return () => clearInterval(interval);
  }, [isActive, auctionStartDate]);

  // Initial fetch
  useEffect(() => {
    fetchAuctionData();
  }, [fetchAuctionData]);

  // Purchase a room at current auction price
  const purchaseRoom = useCallback(async (accommodationId: string, userId: string): Promise<{ success: boolean; error?: string }> => {
    const pricingInfo = getPricingInfo(accommodationId);
    if (!pricingInfo) {
      return { success: false, error: 'Room not in auction' };
    }

    try {
      // Update room with purchase info
      const { data, error } = await supabase
        .from('accommodations')
        .update({
          auction_buyer_id: userId,
          auction_purchase_price: pricingInfo.currentPrice,
          auction_purchased_at: new Date().toISOString(),
        })
        .eq('id', accommodationId)
        .is('auction_buyer_id', null) // Ensure not already sold
        .select()
        .single();

      if (error || !data) {
        return { success: false, error: 'Room already sold or error occurred' };
      }

      // Log the purchase
      await supabase
        .from('auction_history')
        .insert({
          accommodation_id: accommodationId,
          user_id: userId,
          action_type: 'purchase',
          price_at_action: pricingInfo.currentPrice,
        });

      return { success: true };
    } catch (error) {
      console.error('Error purchasing room:', error);
      return { success: false, error: 'Failed to purchase room' };
    }
  }, [getPricingInfo]);

  return {
    isActive,
    auctionStartDate,
    auctionEndDate,
    timeToNextDrop,
    getAuctionPrice,
    getPricingInfo,
    purchaseRoom,
    refetch: fetchAuctionData,
    hasStarted: new Date() >= auctionStartDate,
  };
}