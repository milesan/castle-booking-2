import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Save, Settings, Play, Pause, RefreshCw, DollarSign } from 'lucide-react';
import { format } from 'date-fns';

interface AccommodationAuction {
  id: string;
  title: string;
  auction_tier: string | null;
  auction_start_price: number | null;
  auction_floor_price: number | null;
  auction_current_price: number | null;
  is_in_auction: boolean;
  auction_buyer_id: string | null;
  auction_purchase_price: number | null;
  auction_purchased_at: string | null;
}

interface AuctionConfig {
  id: string;
  auction_start_time: string;
  auction_end_time: string;
  price_drop_interval_hours: number;
  is_active: boolean;
}

const TIERS = [
  { value: 'tower_suite', label: 'Tower Suite', defaultStart: 15000, defaultFloor: 800 },
  { value: 'noble_quarter', label: 'Noble Quarter', defaultStart: 10000, defaultFloor: 600 },
  { value: 'standard_chamber', label: 'Standard Chamber', defaultStart: 6000, defaultFloor: 400 },
];

export function DutchAuctionAdmin() {
  const [accommodations, setAccommodations] = useState<AccommodationAuction[]>([]);
  const [config, setConfig] = useState<AuctionConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [selectedTier, setSelectedTier] = useState<string>('');
  const [tierPrices, setTierPrices] = useState<Record<string, { start: number; floor: number }>>({
    tower_suite: { start: 15000, floor: 800 },
    noble_quarter: { start: 10000, floor: 600 },
    standard_chamber: { start: 6000, floor: 400 },
  });

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    setLoading(true);
    try {
      // Fetch accommodations
      const { data: accData, error: accError } = await supabase
        .from('accommodations')
        .select('*')
        .order('title');

      if (accError) throw accError;
      setAccommodations(accData || []);

      // Fetch auction config
      const { data: configData, error: configError } = await supabase
        .from('auction_config')
        .select('*')
        .single();

      if (configError && configError.code !== 'PGRST116') throw configError;
      setConfig(configData);
    } catch (error) {
      console.error('Error fetching data:', error);
    } finally {
      setLoading(false);
    }
  };

  const updateAccommodation = async (id: string, updates: Partial<AccommodationAuction>) => {
    setSaving(true);
    try {
      const { error } = await supabase
        .from('accommodations')
        .update(updates)
        .eq('id', id);

      if (error) throw error;

      // Update local state
      setAccommodations(prev =>
        prev.map(acc => (acc.id === id ? { ...acc, ...updates } : acc))
      );
    } catch (error) {
      console.error('Error updating accommodation:', error);
      alert('Failed to update accommodation');
    } finally {
      setSaving(false);
    }
  };

  const assignTier = async (accId: string, tier: string | null) => {
    const tierConfig = tier ? tierPrices[tier] : null;
    await updateAccommodation(accId, {
      auction_tier: tier,
      auction_start_price: tierConfig?.start || null,
      auction_floor_price: tierConfig?.floor || null,
      auction_current_price: tierConfig?.start || null,
      is_in_auction: tier !== null,
    });
  };

  const updateTierPrices = async () => {
    setSaving(true);
    try {
      // Update all accommodations in the selected tier
      const updates = accommodations
        .filter(acc => acc.auction_tier === selectedTier)
        .map(acc =>
          supabase
            .from('accommodations')
            .update({
              auction_start_price: tierPrices[selectedTier].start,
              auction_floor_price: tierPrices[selectedTier].floor,
              auction_current_price: tierPrices[selectedTier].start,
            })
            .eq('id', acc.id)
        );

      await Promise.all(updates);
      await fetchData();
      alert('Tier prices updated successfully');
    } catch (error) {
      console.error('Error updating tier prices:', error);
      alert('Failed to update tier prices');
    } finally {
      setSaving(false);
    }
  };

  const toggleAuction = async () => {
    if (!config) return;
    
    setSaving(true);
    try {
      const { error } = await supabase
        .from('auction_config')
        .update({ is_active: !config.is_active })
        .eq('id', config.id);

      if (error) throw error;
      
      setConfig({ ...config, is_active: !config.is_active });
      
      // If activating, reset all current prices to start prices
      if (!config.is_active) {
        const updates = accommodations
          .filter(acc => acc.is_in_auction && acc.auction_tier)
          .map(acc =>
            supabase
              .from('accommodations')
              .update({
                auction_current_price: acc.auction_start_price,
                auction_buyer_id: null,
                auction_purchase_price: null,
                auction_purchased_at: null,
              })
              .eq('id', acc.id)
          );
        
        await Promise.all(updates);
        await fetchData();
      }
    } catch (error) {
      console.error('Error toggling auction:', error);
      alert('Failed to toggle auction');
    } finally {
      setSaving(false);
    }
  };

  const updatePricesNow = async () => {
    setSaving(true);
    try {
      const { error } = await supabase.rpc('update_auction_prices');
      if (error) throw error;
      await fetchData();
      alert('Prices updated successfully');
    } catch (error) {
      console.error('Error updating prices:', error);
      alert('Failed to update prices');
    } finally {
      setSaving(false);
    }
  };

  const excludeFromAuction = async (accId: string) => {
    await updateAccommodation(accId, {
      is_in_auction: false,
      auction_tier: null,
      auction_start_price: null,
      auction_floor_price: null,
      auction_current_price: null,
    });
  };

  if (loading) {
    return <div className="p-8 text-center">Loading auction settings...</div>;
  }

  const tierGroups = {
    tower_suite: accommodations.filter(a => a.auction_tier === 'tower_suite'),
    noble_quarter: accommodations.filter(a => a.auction_tier === 'noble_quarter'),
    standard_chamber: accommodations.filter(a => a.auction_tier === 'standard_chamber'),
    unassigned: accommodations.filter(a => !a.auction_tier),
    excluded: accommodations.filter(a => !a.is_in_auction),
  };

  return (
    <div className="max-w-7xl mx-auto p-6 space-y-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-2xl font-bold flex items-center gap-2">
            <Settings className="w-6 h-6" />
            Dutch Auction Configuration
          </h2>
          <div className="flex gap-3">
            <button
              onClick={updatePricesNow}
              disabled={saving || !config?.is_active}
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              <RefreshCw className="w-4 h-4" />
              Update Prices Now
            </button>
            <button
              onClick={toggleAuction}
              disabled={saving}
              className={`px-6 py-2 rounded-lg font-medium flex items-center gap-2 ${
                config?.is_active
                  ? 'bg-red-600 text-white hover:bg-red-700'
                  : 'bg-green-600 text-white hover:bg-green-700'
              } disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              {config?.is_active ? (
                <>
                  <Pause className="w-4 h-4" />
                  Pause Auction
                </>
              ) : (
                <>
                  <Play className="w-4 h-4" />
                  Start Auction
                </>
              )}
            </button>
          </div>
        </div>

        {config && (
          <div className="grid grid-cols-3 gap-4 p-4 bg-gray-50 rounded-lg">
            <div>
              <p className="text-sm text-gray-600">Status</p>
              <p className="font-semibold">
                {config.is_active ? (
                  <span className="text-green-600">Active</span>
                ) : (
                  <span className="text-gray-500">Inactive</span>
                )}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">End Date</p>
              <p className="font-semibold">
                {format(new Date(config.auction_end_time), 'MMM dd, yyyy')}
              </p>
            </div>
            <div>
              <p className="text-sm text-gray-600">Price Drop Interval</p>
              <p className="font-semibold">Every {config.price_drop_interval_hours} hour(s)</p>
            </div>
          </div>
        )}
      </div>

      <div className="bg-white rounded-lg shadow-lg p-6">
        <h3 className="text-xl font-bold mb-4">Tier Pricing</h3>
        <div className="space-y-4">
          <div className="flex gap-2">
            <select
              value={selectedTier}
              onChange={e => setSelectedTier(e.target.value)}
              className="px-3 py-2 border border-gray-300 rounded-lg"
            >
              <option value="">Select a tier to configure</option>
              {TIERS.map(tier => (
                <option key={tier.value} value={tier.value}>
                  {tier.label}
                </option>
              ))}
            </select>
          </div>
          
          {selectedTier && (
            <div className="flex gap-4 items-end">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Start Price (€)
                </label>
                <input
                  type="number"
                  value={tierPrices[selectedTier].start}
                  onChange={e =>
                    setTierPrices(prev => ({
                      ...prev,
                      [selectedTier]: {
                        ...prev[selectedTier],
                        start: Number(e.target.value),
                      },
                    }))
                  }
                  className="px-3 py-2 border border-gray-300 rounded-lg w-32"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Floor Price (€)
                </label>
                <input
                  type="number"
                  value={tierPrices[selectedTier].floor}
                  onChange={e =>
                    setTierPrices(prev => ({
                      ...prev,
                      [selectedTier]: {
                        ...prev[selectedTier],
                        floor: Number(e.target.value),
                      },
                    }))
                  }
                  className="px-3 py-2 border border-gray-300 rounded-lg w-32"
                />
              </div>
              <button
                onClick={updateTierPrices}
                disabled={saving}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                <Save className="w-4 h-4" />
                Update Tier
              </button>
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {TIERS.map(tier => (
          <div key={tier.value} className="bg-white rounded-lg shadow-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold">{tier.label}</h3>
              <span className="text-sm text-gray-500">
                {tierGroups[tier.value].length} rooms
              </span>
            </div>
            <div className="space-y-2">
              {tierGroups[tier.value].map(acc => (
                <div
                  key={acc.id}
                  className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                >
                  <div>
                    <p className="font-medium">{acc.title}</p>
                    <p className="text-sm text-gray-600">
                      €{acc.auction_current_price?.toLocaleString() || '—'} 
                      {acc.auction_buyer_id && (
                        <span className="ml-2 text-green-600 font-medium">Sold</span>
                      )}
                    </p>
                  </div>
                  <button
                    onClick={() => excludeFromAuction(acc.id)}
                    className="text-sm text-red-600 hover:text-red-700"
                  >
                    Remove
                  </button>
                </div>
              ))}
            </div>
          </div>
        ))}

        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-bold mb-4">Unassigned Rooms</h3>
          <div className="space-y-2">
            {tierGroups.unassigned
              .filter(acc => acc.is_in_auction)
              .map(acc => (
                <div
                  key={acc.id}
                  className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
                >
                  <p className="font-medium">{acc.title}</p>
                  <select
                    onChange={e => assignTier(acc.id, e.target.value)}
                    className="px-3 py-1 border border-gray-300 rounded text-sm"
                    defaultValue=""
                  >
                    <option value="">Assign to tier</option>
                    {TIERS.map(tier => (
                      <option key={tier.value} value={tier.value}>
                        {tier.label}
                      </option>
                    ))}
                  </select>
                </div>
              ))}
          </div>
        </div>

        <div className="bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-bold mb-4">Excluded from Auction</h3>
          <div className="space-y-2">
            {tierGroups.excluded.map(acc => (
              <div
                key={acc.id}
                className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <p className="font-medium">{acc.title}</p>
                <button
                  onClick={() =>
                    updateAccommodation(acc.id, { is_in_auction: true })
                  }
                  className="text-sm text-blue-600 hover:text-blue-700"
                >
                  Include in Auction
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}