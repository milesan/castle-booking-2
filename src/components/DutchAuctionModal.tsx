import React from 'react';
import { X, TrendingDown, Calendar, Clock } from 'lucide-react';

interface DutchAuctionModalProps {
  isOpen: boolean;
  onClose: () => void;
  hasStarted: boolean;
  auctionStartDate: Date;
  auctionEndDate: Date;
}

export function DutchAuctionModal({ 
  isOpen, 
  onClose, 
  hasStarted,
  auctionStartDate,
  auctionEndDate 
}: DutchAuctionModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">Dutch Auction Details</h2>
          <button
            onClick={onClose}
            className="p-1 rounded-lg hover:bg-gray-100 transition-colors"
            aria-label="Close"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Content */}
        <div className="px-6 py-6 space-y-6">
          {/* How it works */}
          <div>
            <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <TrendingDown className="w-5 h-5 text-amber-600" />
              How the Dutch Auction Works
            </h3>
            <p className="text-gray-600 leading-relaxed">
              Room prices start high and decrease by a fixed amount each day at midnight UTC. 
              You can purchase immediately at the current price, or wait for a lower price—but 
              risk the room being sold to another buyer.
            </p>
          </div>

          {/* Timeline */}
          <div>
            <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <Calendar className="w-5 h-5 text-amber-600" />
              Auction Timeline
            </h3>
            <div className="bg-amber-50 rounded-lg p-4 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Start Date:</span>
                <span className="font-medium text-gray-900">
                  {auctionStartDate.toLocaleDateString('en-US', { 
                    month: 'long', 
                    day: 'numeric', 
                    year: 'numeric' 
                  })} at midnight UTC
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">End Date:</span>
                <span className="font-medium text-gray-900">
                  {auctionEndDate.toLocaleDateString('en-US', { 
                    month: 'long', 
                    day: 'numeric', 
                    year: 'numeric' 
                  })}
                </span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Duration:</span>
                <span className="font-medium text-gray-900">30 days</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Price Reductions:</span>
                <span className="font-medium text-gray-900">Daily at midnight UTC</span>
              </div>
            </div>
          </div>

          {/* Pricing Tiers */}
          <div>
            <h3 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
              <Clock className="w-5 h-5 text-amber-600" />
              Room Pricing Tiers
            </h3>
            <div className="space-y-3">
              {/* Tower Suite */}
              <div className="border border-gray-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-2">
                  <h4 className="font-medium text-gray-900">Tower Suite</h4>
                  <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">Premium</span>
                </div>
                <div className="grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-gray-500 block">Starting</span>
                    <span className="font-semibold text-gray-900">€15,000</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Daily reduction</span>
                    <span className="font-semibold text-amber-600">€367</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Floor</span>
                    <span className="font-semibold text-gray-900">€4,000</span>
                  </div>
                </div>
              </div>

              {/* Noble Quarter */}
              <div className="border border-gray-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-2">
                  <h4 className="font-medium text-gray-900">Noble Quarter</h4>
                  <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">Comfort</span>
                </div>
                <div className="grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-gray-500 block">Starting</span>
                    <span className="font-semibold text-gray-900">€10,000</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Daily reduction</span>
                    <span className="font-semibold text-amber-600">€267</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Floor</span>
                    <span className="font-semibold text-gray-900">€2,000</span>
                  </div>
                </div>
              </div>

              {/* Standard Chamber */}
              <div className="border border-gray-200 rounded-lg p-4">
                <div className="flex justify-between items-start mb-2">
                  <h4 className="font-medium text-gray-900">Standard Chamber</h4>
                  <span className="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded">Value</span>
                </div>
                <div className="grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-gray-500 block">Starting</span>
                    <span className="font-semibold text-gray-900">€4,800</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Daily reduction</span>
                    <span className="font-semibold text-amber-600">€133</span>
                  </div>
                  <div>
                    <span className="text-gray-500 block">Floor</span>
                    <span className="font-semibold text-gray-900">€800</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Strategy tip */}
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h4 className="font-medium text-blue-900 mb-2">💡 Strategy Tip</h4>
            <p className="text-sm text-blue-700 leading-relaxed">
              {hasStarted 
                ? "Prices reduce daily at midnight UTC. The earlier you buy, the higher the price—but you secure your preferred room. Waiting saves money but increases the risk of missing out."
                : "The auction begins on August 15 at midnight UTC. You can purchase now at starting prices, or wait for daily reductions once the auction begins."
              }
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}