import type { Week } from '../../types/calendar';
import type { Accommodation } from '../../types';

// Define the season breakdown type (simplified - no seasons/discounts)
export interface SeasonBreakdown {
  hasMultipleSeasons: boolean;
  seasons: Array<{
    name: string;
    discount: number;
    nights: number;
  }>;
}

export interface BookingSummaryProps {
  selectedWeeks: Week[];
  selectedAccommodation: Accommodation | null;
  onClearWeeks: () => void;
  onClearAccommodation: () => void;
  seasonBreakdown?: SeasonBreakdown; // Optional for backward compatibility
  calculatedWeeklyAccommodationPrice: number | null;
}

// Helper function to calculate pricing details
export interface PricingDetails {
  totalNights: number;
  nightlyAccommodationRate: number;
  baseAccommodationRate: number;
  effectiveBaseRate: number;
  totalAccommodationCost: number;
  totalFoodAndFacilitiesCost: number;
  subtotal: number;
  durationDiscountAmount: number; // Always 0 now
  durationDiscountPercent: number; // Always 0 now
  weeksStaying: number; // For display only
  totalAmount: number;
  appliedCodeDiscountValue: number; // Always 0 now
  seasonalDiscount: number; // Always 0 now
  vatAmount: number;
  totalWithVat: number;
}

// AppliedDiscount type removed - no longer using discount codes