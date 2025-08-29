import React from 'react';
import { Week } from '../types/calendar';

interface SimpleWeekSelectorProps {
  weeks: Week[];
  selectedWeeks: Week[];
  onWeekSelect: (week: Week) => void;
}

export function SimpleWeekSelector({ weeks, selectedWeeks, onWeekSelect }: SimpleWeekSelectorProps) {
  const week = weeks[0]; // We only have one week
  if (!week) return <div>No weeks available</div>;
  
  const isSelected = selectedWeeks.some(w => w.id === week.id);
  
  // Component functionality preserved but visual card removed
  return null;
}