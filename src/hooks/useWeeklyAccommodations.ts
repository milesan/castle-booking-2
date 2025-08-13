import { useState, useCallback, useEffect } from 'react';
import { bookingService } from '../services/BookingService';
import type { Accommodation, AccommodationType } from '../types';
import type { AvailabilityResult } from '../types/availability';
import { addDays } from 'date-fns';

interface WeeklyAvailabilityMap {
  [accommodationId: string]: {
    isAvailable: boolean;
    availableCapacity: number | null;
  };
}

export function useWeeklyAccommodations() {
  const [accommodations, setAccommodations] = useState<Accommodation[]>([]);
  const [availabilityMap, setAvailabilityMap] = useState<WeeklyAvailabilityMap>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const checkWeekAvailability = useCallback(async (
    accommodation: Accommodation,
    checkInDate: Date | null | undefined,
    checkOutDate: Date | null | undefined
  ): Promise<boolean> => {
    if (accommodation.is_unlimited) {
      setAvailabilityMap(prev => {
        const existingData = prev[accommodation.id];
        
        // Only update if data actually changed
        if (!existingData || 
            existingData.isAvailable !== true ||
            existingData.availableCapacity !== null) {
          return {
            ...prev,
            [accommodation.id]: {
              isAvailable: true,
              availableCapacity: null
            }
          };
        }
        
        // No changes needed, return existing reference
        return prev;
      });
      return true;
    }
    
    if (!checkInDate || !checkOutDate) {
      return true;
    }
    
    try {
      const startDate = checkInDate;
      const endDate = checkOutDate;
      
      const availability = await bookingService.getAvailability(startDate, endDate);
      
      const newAvailabilityMap: WeeklyAvailabilityMap = {};
      availability.forEach(result => {
        newAvailabilityMap[result.accommodation_id] = {
          isAvailable: result.is_available,
          availableCapacity: result.available_capacity
        };
      });
      
      setAvailabilityMap(prev => {
        // Check if we actually need to update the availability map
        let hasChanges = false;
        const updated = { ...prev };
        
        // Only update properties that have actually changed
        Object.entries(newAvailabilityMap).forEach(([accommodationId, newData]) => {
          const existingData = prev[accommodationId];
          
          // Check if data actually changed
          if (!existingData || 
              existingData.isAvailable !== newData.isAvailable ||
              existingData.availableCapacity !== newData.availableCapacity) {
            updated[accommodationId] = newData;
            hasChanges = true;
          }
        });
        
        // Only return new object if there were actual changes
        if (hasChanges) {
          return updated;
        } else {
          return prev; // Return existing reference to prevent unnecessary re-renders
        }
      });
      
      const result = availability.find(a => a.accommodation_id === accommodation.id);
      return result?.is_available ?? false;
    } catch (err) {
      console.error('[useWeeklyAccommodations] Error checking weekly availability:', err);
      return false;
    }
  }, []);

  const fetchAccommodations = useCallback(async () => {
    try {
      setLoading(true);
      const data = await bookingService.getAccommodations();
      
      const rootAccommodations = data.filter(acc => !(acc as any).parent_accommodation_id);
      
      setAccommodations(rootAccommodations as Accommodation[]);
    } catch (err) {
      console.error('[useWeeklyAccommodations] Error fetching accommodations:', err);
      setError(err instanceof Error ? err : new Error('Failed to fetch accommodations'));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAccommodations();
  }, [fetchAccommodations]);

  return {
    accommodations,
    availabilityMap,
    loading,
    error,
    checkWeekAvailability,
    refresh: fetchAccommodations
  };
}