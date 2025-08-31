import { useMemo } from 'react';
import { getSeasonalDiscount, getDurationDiscount, getSeasonBreakdown } from '../../utils/pricing';
import { calculateTotalNights, calculateDurationDiscountWeeks, calculateTotalWeeksDecimal } from '../../utils/dates';
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
  return useMemo((): PricingDetails => {
    // === Calculate nights and weeks ===
    const totalNights = calculateTotalNights(selectedWeeks);
    const completeWeeks = calculateDurationDiscountWeeks(selectedWeeks); // For duration discount
    const exactWeeksDecimal = calculateTotalWeeksDecimal(selectedWeeks); // For display
    const displayWeeks = selectedWeeks.length > 0 ? Math.round(exactWeeksDecimal * 10) / 10 : 0;
    
    // === Calculate Accommodation Cost using raw base price only ===
    // Use the raw base price without any discounts
    const weeklyAccPrice = selectedAccommodation?.base_price || 0;
    const totalAccommodationCost = parseFloat((weeklyAccPrice * displayWeeks).toFixed(2));

    // No food cost - accommodation only
    const finalFoodCost = 0;
    const foodDiscountAmount = 0;
    const rawDurationDiscountPercent = 0;
    const effectiveWeeklyRate = 0;
    
    // Subtotal includes accommodation and garden addon only
    const gardenAddonCost = gardenAddon?.price || 0;
    const subtotal = totalAccommodationCost + gardenAddonCost;

    // No discount codes - simplified pricing
    let finalTotalAmount = subtotal;
    let discountCodeAmount = 0;

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
      durationDiscountAmount: foodDiscountAmount,
      durationDiscountPercent: rawDurationDiscountPercent * 100,
      seasonalDiscount: 0, // This is calculated elsewhere in the parent component
      vatAmount: 0, // No VAT for nonprofit donations
      totalWithVat: finalTotalAmount, // Same as totalAmount since no VAT
    };


    // --- START TEST ACCOMMODATION OVERRIDE ---
    if (selectedAccommodation?.type === 'test') {
      calculatedPricingDetails.totalFoodAndFacilitiesCost = 0;
      calculatedPricingDetails.subtotal = calculatedPricingDetails.totalAccommodationCost; // Keep accom cost, just zero out food
      calculatedPricingDetails.totalAmount = calculatedPricingDetails.totalAccommodationCost; // Total is just accom cost
      calculatedPricingDetails.durationDiscountAmount = 0; // No food discount applicable
      // No VAT for nonprofit
      calculatedPricingDetails.vatAmount = 0;
      calculatedPricingDetails.totalWithVat = calculatedPricingDetails.totalAmount;
    }
    // --- END TEST ACCOMMODATION OVERRIDE ---

    return calculatedPricingDetails;
  }, [selectedWeeks, calculatedWeeklyAccommodationPrice, foodContribution, selectedAccommodation, gardenAddon]);
}