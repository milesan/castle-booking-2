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
  dailyReduction: number;
  floorPrice: number;
  startPrice: number;
}

// Price configuration - 30 days from Aug 15 to Sept 14
const TIER_CONFIG = {
  tower_suite: {
    startPrice: 15000,
    floorPrice: 4000,
    dailyReduction: 367, // (15000-4000)/30 days, rounded
  },
  noble_quarter: {
    startPrice: 10000,
    floorPrice: 2000,
    dailyReduction: 267, // (10000-2000)/30 days, rounded
  },
  standard_chamber: {
    startPrice: 4800,
    floorPrice: 800,
    dailyReduction: 133, // (4800-800)/30 days, rounded
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
    
    // Calculate days elapsed since auction start
    const daysElapsed = Math.floor((today.getTime() - auctionStartDate.getTime()) / (1000 * 60 * 60 * 24));
    
    // Calculate current price based on days elapsed
    const currentDrop = daysElapsed * config.dailyReduction;
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
      dailyReduction: config.dailyReduction,
      floorPrice: config.floorPrice,
      startPrice: config.startPrice,
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

  // Update countdown timer (to next day at midnight UTC)
  useEffect(() => {
    const updateCountdown = () => {
      const now = new Date();
      
      // If auction hasn't started, show countdown to start
      if (now < auctionStartDate) {
        const diff = auctionStartDate.getTime() - now.getTime();
        const days = Math.floor(diff / (1000 * 60 * 60 * 24));
        const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        
        if (days > 0) {
          setTimeToNextDrop(`${days}d ${hours}h ${minutes}m`);
        } else if (hours > 0) {
          setTimeToNextDrop(`${hours}h ${minutes}m`);
        } else {
          setTimeToNextDrop(`${minutes}m`);
        }
        return;
      }
      
      if (!isActive) {
        setTimeToNextDrop('');
        return;
      }

      // Calculate time to next midnight UTC
      const tomorrow = new Date(now);
      tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
      tomorrow.setUTCHours(0, 0, 0, 0);
      
      const diff = tomorrow.getTime() - now.getTime();
      const hours = Math.floor(diff / (1000 * 60 * 60));
      const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
      
      setTimeToNextDrop(`${hours}h ${minutes}m`);
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 60000); // Update every minute

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