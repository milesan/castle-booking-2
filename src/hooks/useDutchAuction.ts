import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import { differenceInHours, addHours } from 'date-fns';

export interface AuctionRoom {
  id: string;
  title: string;
  auction_tier: 'tower_suite' | 'noble_quarter' | 'standard_chamber';
  auction_start_price: number;
  auction_floor_price: number;
  auction_current_price: number;
  auction_last_price_update: string | null;
  is_in_auction: boolean;
  auction_buyer_id: string | null;
  auction_purchase_price: number | null;
  auction_purchased_at: string | null;
  base_price: number;
  type: string;
  capacity: number;
  bathroom_type: string;
  additional_info?: string;
  property_location?: string;
  images?: Array<{
    id: string;
    image_url: string;
    display_order: number;
    is_primary: boolean;
  }>;
}

export interface AuctionConfig {
  id: string;
  auction_start_time: string;
  auction_end_time: string;
  price_drop_interval_hours: number;
  is_active: boolean;
}

export function useDutchAuction() {
  const [rooms, setRooms] = useState<AuctionRoom[]>([]);
  const [config, setConfig] = useState<AuctionConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [nextPriceDrop, setNextPriceDrop] = useState<Date | null>(null);
  const [timeToNextDrop, setTimeToNextDrop] = useState<string>('');

  // Calculate next price drop time
  const calculateNextPriceDrop = useCallback((config: AuctionConfig) => {
    if (!config.is_active) return null;
    
    const startTime = new Date(config.auction_start_time);
    const now = new Date();
    const hoursElapsed = differenceInHours(now, startTime);
    const dropsSoFar = Math.floor(hoursElapsed / config.price_drop_interval_hours);
    const nextDropNumber = dropsSoFar + 1;
    const nextDrop = addHours(startTime, nextDropNumber * config.price_drop_interval_hours);
    
    return nextDrop;
  }, []);

  // Calculate current price for a room
  const calculateCurrentPrice = useCallback((
    startPrice: number,
    floorPrice: number,
    startTime: Date,
    endTime: Date,
    intervalHours: number
  ): number => {
    const now = new Date();
    if (now < startTime) return startPrice;
    if (now >= endTime) return floorPrice;
    
    const totalHours = differenceInHours(endTime, startTime);
    const hoursElapsed = differenceInHours(now, startTime);
    const drops = Math.floor(hoursElapsed / intervalHours);
    const totalDrops = Math.floor(totalHours / intervalHours);
    const pricePerDrop = (startPrice - floorPrice) / totalDrops;
    
    const currentPrice = startPrice - (drops * pricePerDrop);
    return Math.max(currentPrice, floorPrice);
  }, []);

  // Fetch rooms and config
  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      // Fetch auction config
      const { data: configData, error: configError } = await supabase
        .from('auction_config')
        .select('*')
        .single();

      if (configError && configError.code !== 'PGRST116') throw configError;
      setConfig(configData);

      // Fetch rooms with images
      const { data: roomsData, error: roomsError } = await supabase
        .from('accommodations')
        .select(`
          *,
          images:accommodation_images(*)
        `)
        .eq('is_in_auction', true)
        .not('auction_tier', 'is', null)
        .order('auction_tier')
        .order('title');

      if (roomsError) throw roomsError;
      
      // Update current prices based on time
      const updatedRooms = (roomsData || []).map(room => {
        if (configData && !room.auction_buyer_id) {
          const currentPrice = calculateCurrentPrice(
            room.auction_start_price,
            room.auction_floor_price,
            new Date(configData.auction_start_time),
            new Date(configData.auction_end_time),
            configData.price_drop_interval_hours
          );
          return { ...room, auction_current_price: currentPrice };
        }
        return room;
      });

      setRooms(updatedRooms);

      // Calculate next price drop
      if (configData) {
        const nextDrop = calculateNextPriceDrop(configData);
        setNextPriceDrop(nextDrop);
      }
    } catch (error) {
      console.error('Error fetching auction data:', error);
    } finally {
      setLoading(false);
    }
  }, [calculateCurrentPrice, calculateNextPriceDrop]);

  // Buy a room instantly at current price
  const buyRoom = useCallback(async (
    roomId: string,
    userId: string
  ): Promise<{ success: boolean; error?: string }> => {
    try {
      const room = rooms.find(r => r.id === roomId);
      if (!room) {
        return { success: false, error: 'Room not found' };
      }

      if (room.auction_buyer_id) {
        return { success: false, error: 'Room already sold' };
      }

      const currentPrice = room.auction_current_price;

      // Purchase the room - use optimistic locking to ensure only one buyer
      const { data, error } = await supabase
        .from('accommodations')
        .update({
          auction_buyer_id: userId,
          auction_purchase_price: currentPrice,
          auction_purchased_at: new Date().toISOString(),
        })
        .eq('id', roomId)
        .is('auction_buyer_id', null) // Critical: only update if not already sold
        .select()
        .single();

      if (error || !data) {
        // Room was already sold by someone else
        return { success: false, error: 'Room was just purchased by another buyer' };
      }

      // Log the purchase
      await supabase
        .from('auction_history')
        .insert({
          accommodation_id: roomId,
          user_id: userId,
          action_type: 'purchase',
          price_at_action: currentPrice,
        });

      // Refresh data
      await fetchData();

      return { success: true };
    } catch (error) {
      console.error('Error buying room:', error);
      return { success: false, error: 'Failed to purchase room' };
    }
  }, [rooms, fetchData]);

  // Update countdown timer
  useEffect(() => {
    if (!nextPriceDrop) {
      setTimeToNextDrop('');
      return;
    }

    const updateCountdown = () => {
      const now = new Date();
      const diff = nextPriceDrop.getTime() - now.getTime();
      
      if (diff <= 0) {
        fetchData(); // Refresh when price drop occurs
        return;
      }

      const hours = Math.floor(diff / (1000 * 60 * 60));
      const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
      const seconds = Math.floor((diff % (1000 * 60)) / 1000);
      
      setTimeToNextDrop(`${hours}h ${minutes}m ${seconds}s`);
    };

    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);

    return () => clearInterval(interval);
  }, [nextPriceDrop, fetchData]);

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Set up real-time subscription for changes
  useEffect(() => {
    const subscription = supabase
      .channel('auction_changes')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'accommodations',
          filter: 'is_in_auction=eq.true',
        },
        () => {
          fetchData();
        }
      )
      .subscribe();

    return () => {
      subscription.unsubscribe();
    };
  }, [fetchData]);

  return {
    rooms,
    config,
    loading,
    timeToNextDrop,
    nextPriceDrop,
    buyRoom,
    refetch: fetchData,
  };
}