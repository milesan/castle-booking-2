import { useMemo } from 'react';
import { calculateTotalNights, calculateTotalWeeksDecimal } from '../../utils/dates';
import { calculateBaseFoodCost } from './BookingSummary.utils';
import type { Week } from '../../types/calendar';
import type { Accommodation } from '../../types';
import type { PricingDetails, GardenAddon } from './BookingSummary.types';

interface UsePricingProps {
  selectedWeeks: Week[];
  selectedAccommodation: Accommodation | null;
  calculatedWeeklyAccommodationPrice: number | null;
  foodContribution: number | null;
  gardenAddon?: GardenAddon | null;
}

export function usePricing({
  selectedWeeks,
  selectedAccommodation,
  calculatedWeeklyAccommodationPrice,
  foodContribution,
  gardenAddon
}: UsePricingProps): PricingDetails {
  return useMemo(() => {
    // === Calculate nights for display ===
    const totalNights = calculateTotalNights(selectedWeeks);
    const exactWeeksDecimal = calculateTotalWeeksDecimal(selectedWeeks); // For display only
    const displayWeeks = selectedWeeks.length > 0 ? Math.round(exactWeeksDecimal * 10) / 10 : 0;
    
    // === Use accommodation base price directly (The Castle fixed price) ===
    const totalAccommodationCost = selectedAccommodation?.base_price || 0;

    // === No food cost or discounts ===
    const finalFoodCost = 0;
    const foodDiscountAmount = 0;
    const effectiveWeeklyRate = 0;
    
    // 4. Subtotal is accommodation cost + garden addon
    const gardenAddonCost = gardenAddon?.price || 0;
    const subtotal = totalAccommodationCost + gardenAddonCost;

    // No discount codes - simplified pricing
    let finalTotalAmount = subtotal;
    let discountCodeAmount = 0;

    // --- START: Calculate VAT (24%) ---
    const vatRate = 0.24; // 24% VAT
    const vatAmount = parseFloat((finalTotalAmount * vatRate).toFixed(2));
    const totalWithVat = parseFloat((finalTotalAmount + vatAmount).toFixed(2));
    // --- END: Calculate VAT ---

    // 5. Construct the final object
    const calculatedPricingDetails: PricingDetails = {
      totalNights,
      totalAccommodationCost,
      totalFoodAndFacilitiesCost: finalFoodCost,
      gardenAddonCost,
      subtotal,
      totalAmount: finalTotalAmount,
      appliedCodeDiscountValue: discountCodeAmount,
      weeksStaying: displayWeeks,
      effectiveBaseRate: effectiveWeeklyRate,
      nightlyAccommodationRate: totalNights > 0 ? +(totalAccommodationCost / totalNights).toFixed(2) : 0,
      baseAccommodationRate: selectedAccommodation?.base_price || 0,
      durationDiscountAmount: 0,
      durationDiscountPercent: 0,
      seasonalDiscount: 0,
      vatAmount,
      totalWithVat,
    };


    // --- START TEST ACCOMMODATION OVERRIDE ---
    if (selectedAccommodation?.type === 'test') {
      calculatedPricingDetails.totalFoodAndFacilitiesCost = 0;
      calculatedPricingDetails.subtotal = calculatedPricingDetails.totalAccommodationCost; // Keep accom cost, just zero out food
      calculatedPricingDetails.totalAmount = calculatedPricingDetails.totalAccommodationCost; // Total is just accom cost
      calculatedPricingDetails.durationDiscountAmount = 0; // No food discount applicable
      // Recalculate VAT for test accommodation
      calculatedPricingDetails.vatAmount = parseFloat((calculatedPricingDetails.totalAmount * vatRate).toFixed(2));
      calculatedPricingDetails.totalWithVat = parseFloat((calculatedPricingDetails.totalAmount + calculatedPricingDetails.vatAmount).toFixed(2));
    }
    // --- END TEST ACCOMMODATION OVERRIDE ---

    return calculatedPricingDetails;
  }, [selectedWeeks, calculatedWeeklyAccommodationPrice, foodContribution, selectedAccommodation, gardenAddon]);
}