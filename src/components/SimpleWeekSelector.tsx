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
  
  return (
    <div className="p-8 castle-animate-fade">
      <div className="max-w-md mx-auto">
        <div
          className="castle-card w-full p-6 transition-all relative overflow-hidden castle-animate-glow transform scale-105"
          style={{
            background: 'linear-gradient(135deg, var(--castle-bg-tertiary), var(--castle-accent-gold-dark))',
            border: '2px solid var(--castle-accent-gold)',
            boxShadow: 'var(--castle-shadow-glow)',
            cursor: 'default'
          }}
        >
          <div className="text-xl mb-2" style={{ fontFamily: 'var(--castle-font-primary)', color: 'var(--castle-text-accent)' }}>
            September 21-26, 2025
          </div>
          <div className="text-sm mt-2" style={{ color: 'var(--castle-text-muted)' }}>
            Sunday to Friday (6 days)
          </div>
          <div className="mt-4 font-semibold" style={{ color: 'var(--castle-accent-gold)' }}>
            ✓ Selected
          </div>
        </div>
      </div>
    </div>
  );
}