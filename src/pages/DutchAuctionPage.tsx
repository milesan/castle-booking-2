import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Clock, TrendingDown, Users, Lock, ChevronLeft, ChevronRight, Crown, Shield, Home } from 'lucide-react';
import { useDutchAuction } from '../hooks/useDutchAuction';
import { useSession } from '../hooks/useSession';
import { useNavigate } from 'react-router-dom';
import { format } from 'date-fns';

const TIER_CONFIG = {
  tower_suite: {
    name: 'Tower Suites',
    icon: Crown,
    color: 'from-amber-500 to-yellow-600',
    bgColor: 'bg-gradient-to-br from-amber-50 to-yellow-50',
    borderColor: 'border-amber-300',
    description: 'Luxurious suites with panoramic views',
  },
  noble_quarter: {
    name: 'Noble Quarters',
    icon: Shield,
    color: 'from-purple-500 to-indigo-600',
    bgColor: 'bg-gradient-to-br from-purple-50 to-indigo-50',
    borderColor: 'border-purple-300',
    description: 'Sophisticated rooms with premium amenities',
  },
  standard_chamber: {
    name: 'Standard Chambers',
    icon: Home,
    color: 'from-green-500 to-emerald-600',
    bgColor: 'bg-gradient-to-br from-green-50 to-emerald-50',
    borderColor: 'border-green-300',
    description: 'Comfortable rooms in the heart of the castle',
  },
};

export function DutchAuctionPage() {
  const navigate = useNavigate();
  const { session } = useSession();
  const { rooms, config, loading, timeToNextDrop, reserveRoom, cancelReservation } = useDutchAuction();
  
  const [selectedTier, setSelectedTier] = useState<keyof typeof TIER_CONFIG>('tower_suite');
  const [currentRoomIndex, setCurrentRoomIndex] = useState(0);
  const [showingRoom, setShowingRoom] = useState<string | null>(null);
  const [maxBid, setMaxBid] = useState<number>(0);
  const [isReserving, setIsReserving] = useState(false);

  // Filter rooms by tier
  const tierRooms = rooms.filter(room => room.auction_tier === selectedTier);
  const availableRooms = tierRooms.filter(room => !room.auction_buyer_id);
  const reservedRooms = tierRooms.filter(room => room.auction_buyer_id);
  
  // Get current batch of 4 rooms
  const roomsPerPage = 4;
  const totalPages = Math.ceil(availableRooms.length / roomsPerPage);
  const currentBatch = availableRooms.slice(
    currentRoomIndex * roomsPerPage,
    (currentRoomIndex + 1) * roomsPerPage
  );

  // Get user's reservations
  const userReservations = rooms.filter(room => room.auction_buyer_id === session?.user?.id);

  const handleReserveRoom = async (roomId: string) => {
    if (!session?.user) {
      navigate('/login');
      return;
    }

    setIsReserving(true);
    const result = await reserveRoom(roomId, maxBid, session.user.id);
    
    if (result.success) {
      alert('Room reserved successfully! You will pay the final auction price plus €100.');
      setShowingRoom(null);
      setMaxBid(0);
    } else {
      alert(result.error || 'Failed to reserve room');
    }
    setIsReserving(false);
  };

  const handleCancelReservation = async (roomId: string) => {
    if (!session?.user) return;
    
    if (confirm('Are you sure you want to cancel this reservation?')) {
      const result = await cancelReservation(roomId, session.user.id);
      if (!result.success) {
        alert(result.error || 'Failed to cancel reservation');
      }
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading auction...</p>
        </div>
      </div>
    );
  }

  if (!config?.is_active) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center">
        <div className="text-center max-w-md">
          <h1 className="text-3xl font-bold mb-4">Auction Not Active</h1>
          <p className="text-gray-600">The Dutch auction is currently paused. Please check back later.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header with countdown */}
      <div className="bg-white shadow-lg sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <h1 className="text-2xl font-bold">Castle Room Auction</h1>
            <div className="flex items-center gap-6">
              <div className="text-center">
                <p className="text-sm text-gray-500">Next Price Drop</p>
                <div className="flex items-center gap-2 text-lg font-mono font-bold text-red-600">
                  <Clock className="w-5 h-5" />
                  {timeToNextDrop || 'Calculating...'}
                </div>
              </div>
              <div className="text-center">
                <p className="text-sm text-gray-500">Auction Ends</p>
                <p className="font-semibold">Sept 14, 2025</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Your Reservations */}
      {userReservations.length > 0 && (
        <div className="max-w-7xl mx-auto px-4 py-6">
          <div className="bg-green-50 border border-green-200 rounded-lg p-4">
            <h2 className="font-bold text-green-800 mb-2">Your Reservations</h2>
            <div className="space-y-2">
              {userReservations.map(room => (
                <div key={room.id} className="flex items-center justify-between">
                  <div>
                    <span className="font-medium">{room.title}</span>
                    <span className="ml-2 text-sm text-gray-600">
                      Max bid: €{room.auction_max_bid?.toLocaleString()}
                    </span>
                  </div>
                  <button
                    onClick={() => handleCancelReservation(room.id)}
                    className="text-red-600 hover:text-red-700 text-sm"
                  >
                    Cancel
                  </button>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Tier Selection */}
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {Object.entries(TIER_CONFIG).map(([tier, config]) => {
            const Icon = config.icon;
            const tierData = tierRooms.filter(r => r.auction_tier === tier);
            const available = tierData.filter(r => !r.auction_buyer_id).length;
            const reserved = tierData.filter(r => !!r.auction_buyer_id).length;
            const lowestPrice = Math.min(...tierData.filter(r => !r.auction_buyer_id).map(r => r.auction_current_price || Infinity));
            
            return (
              <motion.button
                key={tier}
                onClick={() => {
                  setSelectedTier(tier as keyof typeof TIER_CONFIG);
                  setCurrentRoomIndex(0);
                }}
                className={`p-6 rounded-xl transition-all ${
                  selectedTier === tier
                    ? `${config.bgColor} ${config.borderColor} border-2 shadow-lg`
                    : 'bg-white hover:shadow-md border border-gray-200'
                }`}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
              >
                <div className="flex items-center justify-between mb-3">
                  <Icon className={`w-8 h-8 bg-gradient-to-r ${config.color} text-white p-1.5 rounded`} />
                  <div className="text-right">
                    <p className="text-2xl font-bold">€{lowestPrice.toLocaleString()}</p>
                    <p className="text-xs text-gray-500">Current price</p>
                  </div>
                </div>
                <h3 className="text-lg font-bold mb-1">{config.name}</h3>
                <p className="text-sm text-gray-600 mb-3">{config.description}</p>
                <div className="flex justify-between text-sm">
                  <span className="text-green-600">{available} available</span>
                  <span className="text-gray-500">{reserved} reserved</span>
                </div>
              </motion.button>
            );
          })}
        </div>
      </div>

      {/* Room Grid */}
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-xl font-bold flex items-center gap-2">
              {(() => {
                const Icon = TIER_CONFIG[selectedTier].icon;
                return <Icon className="w-6 h-6" />;
              })()}
              {TIER_CONFIG[selectedTier].name} - Available Rooms
            </h2>
            {totalPages > 1 && (
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentRoomIndex(Math.max(0, currentRoomIndex - 1))}
                  disabled={currentRoomIndex === 0}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <span className="text-sm text-gray-600">
                  {currentRoomIndex + 1} / {totalPages}
                </span>
                <button
                  onClick={() => setCurrentRoomIndex(Math.min(totalPages - 1, currentRoomIndex + 1))}
                  disabled={currentRoomIndex === totalPages - 1}
                  className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            )}
          </div>

          {currentBatch.length === 0 ? (
            <div className="text-center py-12 text-gray-500">
              <Lock className="w-12 h-12 mx-auto mb-3 opacity-50" />
              <p>All rooms in this tier have been reserved</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {currentBatch.map(room => (
                <motion.div
                  key={room.id}
                  className="border border-gray-200 rounded-lg overflow-hidden hover:shadow-lg transition-shadow"
                  whileHover={{ y: -2 }}
                >
                  {room.images?.[0] && (
                    <div className="h-48 bg-gray-200">
                      <img
                        src={room.images[0].image_url}
                        alt={room.title}
                        className="w-full h-full object-cover"
                      />
                    </div>
                  )}
                  <div className="p-4">
                    <h3 className="font-bold text-lg mb-2">{room.title}</h3>
                    <div className="space-y-1 text-sm text-gray-600 mb-3">
                      {room.property_location && <p>📍 {room.property_location}</p>}
                      <p>👥 Capacity: {room.capacity}</p>
                      {room.additional_info && <p>✨ {room.additional_info}</p>}
                    </div>
                    <div className="flex items-center justify-between mb-3">
                      <div>
                        <p className="text-2xl font-bold">€{room.auction_current_price?.toLocaleString()}</p>
                        <p className="text-xs text-gray-500">
                          <TrendingDown className="w-3 h-3 inline mr-1" />
                          Next: €{(room.auction_current_price - 14).toLocaleString()}
                        </p>
                      </div>
                      <div className="text-right text-sm">
                        <p className="text-gray-500">Floor price</p>
                        <p className="font-semibold">€{room.auction_floor_price?.toLocaleString()}</p>
                      </div>
                    </div>
                    <button
                      onClick={() => {
                        setShowingRoom(room.id);
                        setMaxBid(room.auction_current_price || 0);
                      }}
                      className="w-full py-2 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-lg hover:from-blue-600 hover:to-blue-700 transition-colors"
                    >
                      Reserve Room
                    </button>
                  </div>
                </motion.div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Commitment Board */}
      <div className="max-w-7xl mx-auto px-4 py-6">
        <div className="bg-white rounded-xl shadow-lg p-6">
          <h2 className="text-xl font-bold mb-4">🏆 Commitment Board</h2>
          <div className="space-y-2">
            {reservedRooms.slice(0, 10).map(room => (
              <div key={room.id} className="flex items-center justify-between py-2 border-b border-gray-100">
                <span className="font-medium">{room.title}</span>
                <span className="text-sm text-gray-600">
                  Reserved at €{room.auction_current_price?.toLocaleString()} tier
                </span>
              </div>
            ))}
            {reservedRooms.length === 0 && (
              <p className="text-gray-500 text-center py-4">No reservations yet</p>
            )}
          </div>
        </div>
      </div>

      {/* Reservation Modal */}
      <AnimatePresence>
        {showingRoom && (() => {
          const room = rooms.find(r => r.id === showingRoom);
          if (!room) return null;
          
          return (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
              onClick={() => setShowingRoom(null)}
            >
              <motion.div
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.9, opacity: 0 }}
                className="bg-white rounded-xl max-w-md w-full p-6"
                onClick={e => e.stopPropagation()}
              >
                <h3 className="text-xl font-bold mb-4">Secure {room.title}</h3>
                
                <div className="space-y-3 mb-6">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Current Auction Price</span>
                    <span className="font-bold">€{room.auction_current_price?.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Next Drop In</span>
                    <span className="font-mono">{timeToNextDrop}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Floor Price</span>
                    <span>€{room.auction_floor_price?.toLocaleString()}</span>
                  </div>
                </div>

                <div className="mb-6">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Set Your Maximum Bid
                  </label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500">€</span>
                    <input
                      type="number"
                      value={maxBid}
                      onChange={e => setMaxBid(Number(e.target.value))}
                      min={room.auction_current_price}
                      className="w-full pl-8 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                    />
                  </div>
                  <p className="mt-2 text-sm text-gray-600">
                    💡 You'll pay the final auction price + €100 (never more than your maximum)
                  </p>
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={() => setShowingRoom(null)}
                    className="flex-1 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => handleReserveRoom(room.id)}
                    disabled={isReserving || maxBid < room.auction_current_price}
                    className="flex-1 py-2 bg-gradient-to-r from-green-500 to-green-600 text-white rounded-lg hover:from-green-600 hover:to-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isReserving ? 'Reserving...' : 'Commit to Room'}
                  </button>
                </div>
              </motion.div>
            </motion.div>
          );
        })()}
      </AnimatePresence>
    </div>
  );
}