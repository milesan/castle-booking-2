import React, { useState } from 'react';
import { SimpleBookingsList } from '../components/SimpleBookingsList';
import { WhitelistSimple } from '../components/admin/WhitelistSimple';
import { Accommodations } from '../components/admin/Accommodations';
import { ClipboardList, UserPlus, Building2 } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

type AdminView = 'bookings' | 'whitelist' | 'accommodations';

interface AdminPageProps {
  housekeepingOnly?: boolean;
}

export function AdminPage({ housekeepingOnly = false }: AdminPageProps) {
  const navigate = useNavigate();
  const [currentView, setCurrentView] = useState<AdminView>(housekeepingOnly ? 'housekeeping' : 'bookings');
  // Removed housekeeping-only mode - all users use the main admin interface now

  return (
    <div className="min-h-screen bg-black/50">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-display font-light text-[var(--color-text-primary)]">Admin Dashboard</h1>
              <p className="text-[var(--color-text-secondary)] font-mono">Manage applications, bookings, and availability</p>
            </div>
          </div>
        </div>

        <div className="flex gap-4 mb-8 overflow-x-auto pb-2">
          <button
            onClick={() => setCurrentView('bookings')}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-sm transition-colors whitespace-nowrap font-mono text-sm ${
              currentView === 'bookings'
                ? 'bg-emerald-900 text-white'
                : 'bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-surface-hover)] border border-[var(--color-border)]'
            }`}
          >
            <ClipboardList className="w-4 h-4" />
            Bookings
          </button>
          <button
            onClick={() => setCurrentView('whitelist')}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-sm transition-colors whitespace-nowrap font-mono text-sm ${
              currentView === 'whitelist'
                ? 'bg-emerald-900 text-white'
                : 'bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-surface-hover)] border border-[var(--color-border)]'
            }`}
          >
            <UserPlus className="w-4 h-4" />
            Whitelist
          </button>
          <button
            onClick={() => setCurrentView('accommodations')}
            className={`flex items-center gap-2 px-3 py-1.5 rounded-sm transition-colors whitespace-nowrap font-mono text-sm ${
              currentView === 'accommodations'
                ? 'bg-emerald-900 text-white'
                : 'bg-[var(--color-bg-surface)] text-[var(--color-text-secondary)] hover:bg-[var(--color-bg-surface-hover)] border border-[var(--color-border)]'
            }`}
          >
            <Building2 className="w-4 h-4" />
            Accommodations
          </button>
        </div>

        <div className="bg-[var(--color-bg-main)]  shadow-sm">
          {currentView === 'bookings' && <SimpleBookingsList />}
          {currentView === 'whitelist' && <WhitelistSimple />}
          {currentView === 'accommodations' && <Accommodations />}
        </div>
      </div>
    </div>
  );
}
