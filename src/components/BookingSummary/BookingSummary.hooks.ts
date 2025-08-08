import { useMemo } from 'react';
import { calculateTotalNights, calculateTotalWeeksDecimal } from '../../utils/dates';
import { calculateBaseFoodCost } from './BookingSummary.utils';
import type { Week } from '../../types/calendar';
import type { Accommodation } from '../../types';
import type { PricingDetails } from './BookingSummary.types';

interface UsePricingProps {
  selectedWeeks: Week[];
  selectedAccommodation: Accommodation | null;
  calculatedWeeklyAccommodationPrice: number | null;
  foodContribution: number | null;
}

export function usePricing({
  selectedWeeks,
  selectedAccommodation,
  calculatedWeeklyAccommodationPrice,
  foodContribution
}: UsePricingProps): PricingDetails {
  return useMemo((): PricingDetails => {
    console.log('[BookingSummary] --- Recalculating Pricing (useMemo) ---');
    console.log('[BookingSummary] useMemo Inputs:', {
      selectedWeeksLength: selectedWeeks.length,
      selectedAccommodationId_Prop: selectedAccommodation?.id,
      calculatedWeeklyAccommodationPrice_Prop: calculatedWeeklyAccommodationPrice,
      foodContribution,
    });
    // --- ADDED LOGGING: Check prop value *inside* memo ---
    console.log('[BookingSummary] useMemo: Using calculatedWeeklyAccommodationPrice PROP:', calculatedWeeklyAccommodationPrice);
    // --- END ADDED LOGGING ---

    // === Calculate nights for display ===
    const totalNights = calculateTotalNights(selectedWeeks);
    const exactWeeksDecimal = calculateTotalWeeksDecimal(selectedWeeks); // For display only
    const displayWeeks = selectedWeeks.length > 0 ? Math.round(exactWeeksDecimal * 10) / 10 : 0;
    
    // === Use accommodation base price directly (castle week fixed price) ===
    const totalAccommodationCost = selectedAccommodation?.base_price || 0;
    console.log('[BookingSummary] Using accommodation base price directly:', totalAccommodationCost);

    // === No food cost or discounts ===
    const finalFoodCost = 0;
    const foodDiscountAmount = 0;
    const effectiveWeeklyRate = 0;
    
    // 4. Subtotal is just accommodation cost
    const subtotal = totalAccommodationCost;
    console.log('[BookingSummary] useMemo: Calculated Subtotal:', { totalAccommodationCost, finalFoodCost, subtotal });

    // No discount codes - simplified pricing
    let finalTotalAmount = subtotal;
    let discountCodeAmount = 0;

    // --- START: Calculate VAT (24%) ---
    const vatRate = 0.24; // 24% VAT
    const vatAmount = parseFloat((finalTotalAmount * vatRate).toFixed(2));
    const totalWithVat = parseFloat((finalTotalAmount + vatAmount).toFixed(2));
    
    console.log('[BookingSummary] useMemo: VAT Calculation:', {
      finalTotalAmount,
      vatRate,
      vatAmount,
      totalWithVat
    });
    // --- END: Calculate VAT ---

    // 5. Construct the final object
    const calculatedPricingDetails: PricingDetails = {
      totalNights,
      totalAccommodationCost,
      totalFoodAndFacilitiesCost: finalFoodCost,
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
      console.log('[BookingSummary] useMemo: OVERRIDING costs for TEST accommodation.');
      calculatedPricingDetails.totalFoodAndFacilitiesCost = 0;
      calculatedPricingDetails.subtotal = calculatedPricingDetails.totalAccommodationCost; // Keep accom cost, just zero out food
      calculatedPricingDetails.totalAmount = calculatedPricingDetails.totalAccommodationCost; // Total is just accom cost
      calculatedPricingDetails.durationDiscountAmount = 0; // No food discount applicable
      // Recalculate VAT for test accommodation
      calculatedPricingDetails.vatAmount = parseFloat((calculatedPricingDetails.totalAmount * vatRate).toFixed(2));
      calculatedPricingDetails.totalWithVat = parseFloat((calculatedPricingDetails.totalAmount + calculatedPricingDetails.vatAmount).toFixed(2));
    }
    // --- END TEST ACCOMMODATION OVERRIDE ---

    console.log('[BookingSummary] useMemo: Pricing calculation COMPLETE. Result:', calculatedPricingDetails);
    console.log('[BookingSummary] --- Finished Pricing Recalculation (useMemo) ---');
    return calculatedPricingDetails;

  }, [selectedWeeks, calculatedWeeklyAccommodationPrice, foodContribution, selectedAccommodation]);
}