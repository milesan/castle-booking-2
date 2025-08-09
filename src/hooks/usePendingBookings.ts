import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

interface PendingBooking {
  accommodation_id: string;
  created_at: string;
  check_in: string;
  check_out: string;
}

interface PendingBookingStatus {
  [accommodationId: string]: {
    count: number;
    oldestPendingTime: Date | null;
    minutesRemaining: number;
  };
}

export function usePendingBookings(selectedWeeks: any[]) {
  const [pendingBookings, setPendingBookings] = useState<PendingBookingStatus>({});
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!selectedWeeks || selectedWeeks.length === 0) {
      setPendingBookings({});
      return;
    }

    let channel: RealtimeChannel;
    let intervalId: NodeJS.Timeout;

    const fetchPendingBookings = async () => {
      setLoading(true);
      try {
        const checkIn = selectedWeeks[0].startDate;
        const checkOut = selectedWeeks[selectedWeeks.length - 1].endDate;
        
        // Get all pending bookings for the selected date range
        const { data, error } = await supabase
          .from('bookings')
          .select('accommodation_id, created_at, check_in, check_out')
          .eq('status', 'pending')
          .gte('check_out', checkIn.toISOString())
          .lte('check_in', checkOut.toISOString());

        if (error) {
          console.error('Error fetching pending bookings:', error);
          return;
        }

        // Group by accommodation and calculate time remaining
        const grouped: PendingBookingStatus = {};
        const now = new Date();
        
        (data || []).forEach((booking: PendingBooking) => {
          const createdAt = new Date(booking.created_at);
          const minutesElapsed = Math.floor((now.getTime() - createdAt.getTime()) / (1000 * 60));
          const minutesRemaining = Math.max(0, 5 - minutesElapsed); // 5 minute timeout
          
          if (!grouped[booking.accommodation_id]) {
            grouped[booking.accommodation_id] = {
              count: 0,
              oldestPendingTime: null,
              minutesRemaining: 0
            };
          }
          
          grouped[booking.accommodation_id].count++;
          
          // Track the oldest pending booking for this accommodation
          if (!grouped[booking.accommodation_id].oldestPendingTime || 
              createdAt < grouped[booking.accommodation_id].oldestPendingTime!) {
            grouped[booking.accommodation_id].oldestPendingTime = createdAt;
            grouped[booking.accommodation_id].minutesRemaining = minutesRemaining;
          }
        });
        
        setPendingBookings(grouped);
      } catch (error) {
        console.error('Error in fetchPendingBookings:', error);
      } finally {
        setLoading(false);
      }
    };

    // Initial fetch
    fetchPendingBookings();

    // Subscribe to real-time changes
    channel = supabase
      .channel('pending-bookings')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'bookings',
          filter: 'status=eq.pending'
        },
        () => {
          // Refetch when any pending booking changes
          fetchPendingBookings();
        }
      )
      .subscribe();

    // Update countdown every 30 seconds
    intervalId = setInterval(() => {
      fetchPendingBookings();
    }, 30000);

    return () => {
      if (channel) {
        supabase.removeChannel(channel);
      }
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }, [selectedWeeks]);

  return { pendingBookings, loading };
}