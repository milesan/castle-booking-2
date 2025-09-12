import React, { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { format, parseISO } from 'date-fns';
import { Trash2, X, Edit } from 'lucide-react';

interface SimpleBooking {
  id: string;
  user_email: string;
  total_price: number;
  created_at: string;
  status?: string;
  check_in?: string;
  check_out?: string;
  accommodation_id?: string;
  accommodations?: {
    title: string;
  };
  garden_addon_details?: {
    option_name: string;
    start_date: string;
    end_date: string;
    price: number;
  };
}

export function SimpleBookingsList() {
  const [bookings, setBookings] = useState<SimpleBooking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [gardenStats, setGardenStats] = useState({ total: 0, addons: 0, standalone: 0 });
  const [cancelModalBooking, setCancelModalBooking] = useState<SimpleBooking | null>(null);
  const [deleteMode, setDeleteMode] = useState<'cancel' | 'delete'>('cancel');
  const [isProcessing, setIsProcessing] = useState(false);
  const [editingBooking, setEditingBooking] = useState<SimpleBooking | null>(null);
  const [editFormData, setEditFormData] = useState({
    check_in: '',
    check_out: '',
    total_price: '',
    status: '',
    accommodation_id: ''
  });
  const [accommodations, setAccommodations] = useState<any[]>([]);

  useEffect(() => {
    loadBookings();
    loadAccommodations();
  }, []);

  useEffect(() => {
    // Calculate garden decompression statistics
    const gardenBookings = bookings.filter(b => 
      b.garden_addon_details || 
      b.accommodations?.title === 'Garden Decompression (No Castle Accommodation)'
    );
    
    const gardenAddons = bookings.filter(b => b.garden_addon_details).length;
    const gardenStandalone = bookings.filter(b => 
      b.accommodations?.title === 'Garden Decompression (No Castle Accommodation)'
    ).length;
    
    setGardenStats({
      total: gardenBookings.length,
      addons: gardenAddons,
      standalone: gardenStandalone
    });
  }, [bookings]);

  async function loadBookings() {
    setLoading(true);
    setError(null);
    
    try {
      const { data, error: bookingsError } = await supabase
        .from('bookings_with_emails')
        .select(`
          id,
          user_email,
          total_price,
          created_at,
          status,
          check_in,
          check_out,
          accommodation_id,
          accommodations ( title ),
          garden_addon_details
        `)
        .order('created_at', { ascending: false });

      if (bookingsError) throw bookingsError;
      
      setBookings(data || []);
    } catch (err) {
      console.error('Error loading bookings:', err);
      setError(err instanceof Error ? err.message : 'Failed to load bookings');
    } finally {
      setLoading(false);
    }
  }

  async function loadAccommodations() {
    try {
      const { data, error } = await supabase
        .from('accommodations')
        .select('id, title')
        .order('title');
      
      if (error) throw error;
      setAccommodations(data || []);
    } catch (err) {
      console.error('Error loading accommodations:', err);
    }
  }

  async function handleCancelBooking() {
    if (!cancelModalBooking || isProcessing) return;

    setIsProcessing(true);
    setError(null);

    try {
      if (deleteMode === 'delete') {
        // First, delete any related payments
        const { error: paymentsError } = await supabase
          .from('payments')
          .delete()
          .eq('booking_id', cancelModalBooking.id);

        if (paymentsError) {
          console.error('Error deleting payments:', paymentsError);
          // Continue even if payments deletion fails
        }

        // Then delete the booking
        const { error } = await supabase
          .from('bookings')
          .delete()
          .eq('id', cancelModalBooking.id);

        if (error) throw error;
      } else {
        // Mark as cancelled
        const { error } = await supabase
          .from('bookings')
          .update({ status: 'cancelled' })
          .eq('id', cancelModalBooking.id);

        if (error) throw error;
      }

      // Reload bookings
      await loadBookings();
      setCancelModalBooking(null);
      setError(null);
    } catch (err) {
      console.error('Error cancelling/deleting booking:', err);
      setError(err instanceof Error ? err.message : 'Failed to cancel/delete booking');
      // Don't close modal on error so user can see what happened
    } finally {
      setIsProcessing(false);
    }
  }

  function openCancelModal(booking: SimpleBooking, mode: 'cancel' | 'delete') {
    setCancelModalBooking(booking);
    setDeleteMode(mode);
  }

  function openEditModal(booking: SimpleBooking) {
    setEditingBooking(booking);
    setEditFormData({
      check_in: booking.check_in ? format(parseISO(booking.check_in), 'yyyy-MM-dd') : '',
      check_out: booking.check_out ? format(parseISO(booking.check_out), 'yyyy-MM-dd') : '',
      total_price: booking.total_price.toString(),
      status: booking.status || 'pending',
      accommodation_id: booking.accommodation_id || ''
    });
  }

  async function handleSaveEdit() {
    if (!editingBooking || isProcessing) return;

    setIsProcessing(true);
    setError(null);

    try {
      const { error } = await supabase
        .from('bookings')
        .update({
          check_in: editFormData.check_in,
          check_out: editFormData.check_out,
          total_price: parseFloat(editFormData.total_price),
          status: editFormData.status,
          accommodation_id: editFormData.accommodation_id
        })
        .eq('id', editingBooking.id);

      if (error) throw error;

      await loadBookings();
      setEditingBooking(null);
    } catch (err) {
      console.error('Error updating booking:', err);
      setError(err instanceof Error ? err.message : 'Failed to update booking');
    } finally {
      setIsProcessing(false);
    }
  }

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="text-[var(--color-text-secondary)]">Loading bookings...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-sm p-4">
        <p className="text-red-800">Error: {error}</p>
      </div>
    );
  }

  return (
    <div className="bg-[var(--color-bg-surface)] rounded-sm shadow-sm overflow-hidden">
      <div className="px-6 py-4 border-b border-[var(--color-border)]">
        <h2 className="text-lg font-medium text-[var(--color-text-primary)]">
          Bookings ({bookings.length})
        </h2>
        {gardenStats.total > 0 && (
          <div className="mt-2 p-3 bg-green-50 rounded-sm border border-green-200">
            <div className="text-sm font-medium text-green-800">
              Garden Decompression Sales: {gardenStats.total} total
            </div>
            <div className="text-xs text-green-600 mt-1">
              • Garden Add-ons (with Castle): {gardenStats.addons}
              <br />
              • Garden-Only bookings: {gardenStats.standalone}
            </div>
          </div>
        )}
      </div>
      
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-[var(--color-border)]">
          <thead className="bg-[var(--color-bg-surface)]">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Email
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Room
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Amount Paid
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Booked
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Status
              </th>
              <th className="px-6 py-3 text-left text-xs font-medium text-[var(--color-text-secondary)] uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody className="bg-[var(--color-bg-surface)] divide-y divide-[var(--color-border)]">
            {bookings.map((booking) => (
              <tr key={booking.id} className="hover:bg-[var(--color-bg-surface-hover)] transition-colors">
                <td className="px-6 py-4 whitespace-nowrap text-sm text-[var(--color-text-primary)]">
                  {booking.user_email}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-[var(--color-text-primary)]">
                  <div>
                    {booking.accommodations?.title || 'N/A'}
                    {booking.garden_addon_details && (
                      <div className="text-xs text-green-600 mt-1">
                        + Garden: {booking.garden_addon_details.option_name}
                      </div>
                    )}
                  </div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-[var(--color-text-primary)]">
                  €{Number(booking.total_price).toFixed(2)}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-[var(--color-text-secondary)]">
                  {format(new Date(booking.created_at), 'MMM d, yyyy')}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <span className={`px-2 py-1 rounded-sm text-xs font-medium ${
                    booking.status === 'cancelled' 
                      ? 'bg-red-100 text-red-800'
                      : booking.status === 'confirmed'
                      ? 'bg-green-100 text-green-800'
                      : 'bg-yellow-100 text-yellow-800'
                  }`}>
                    {booking.status || 'pending'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-sm">
                  <div className="flex gap-2">
                    <button
                      onClick={() => openEditModal(booking)}
                      className="p-1.5 rounded-sm text-blue-600 hover:bg-blue-50 transition-colors"
                      title="Edit booking"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    {booking.status !== 'cancelled' && (
                      <button
                        onClick={() => openCancelModal(booking, 'cancel')}
                        className="p-1.5 rounded-sm text-yellow-600 hover:bg-yellow-50 transition-colors"
                        title="Mark as cancelled"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    )}
                    <button
                      onClick={() => openCancelModal(booking, 'delete')}
                      className="p-1.5 rounded-sm text-red-600 hover:bg-red-50 transition-colors"
                      title="Delete permanently"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Edit Modal */}
      {editingBooking && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-[var(--color-bg-surface)] rounded-sm p-6 max-w-md w-full border border-[var(--color-border)]">
            <h3 className="text-lg font-medium text-[var(--color-text-primary)] mb-2">
              Edit Booking
            </h3>
            {editingBooking && (
              <p className="text-sm text-[var(--color-text-secondary)] mb-4">
                {editingBooking.user_email}
              </p>
            )}

            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-[var(--color-text-secondary)] mb-1">
                  Room / Accommodation
                </label>
                <select
                  value={editFormData.accommodation_id}
                  onChange={(e) => setEditFormData({ ...editFormData, accommodation_id: e.target.value })}
                  className="w-full px-3 py-2 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-sm text-[var(--color-text-primary)] focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">Select accommodation</option>
                  {accommodations.map((acc) => (
                    <option key={acc.id} value={acc.id}>
                      {acc.title}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-[var(--color-text-secondary)] mb-1">
                  Check-in Date
                </label>
                <input
                  type="date"
                  value={editFormData.check_in}
                  onChange={(e) => setEditFormData({ ...editFormData, check_in: e.target.value })}
                  className="w-full px-3 py-2 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-sm text-[var(--color-text-primary)] focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-[var(--color-text-secondary)] mb-1">
                  Check-out Date
                </label>
                <input
                  type="date"
                  value={editFormData.check_out}
                  onChange={(e) => setEditFormData({ ...editFormData, check_out: e.target.value })}
                  className="w-full px-3 py-2 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-sm text-[var(--color-text-primary)] focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-[var(--color-text-secondary)] mb-1">
                  Total Price (€)
                </label>
                <input
                  type="number"
                  step="0.01"
                  value={editFormData.total_price}
                  onChange={(e) => setEditFormData({ ...editFormData, total_price: e.target.value })}
                  className="w-full px-3 py-2 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-sm text-[var(--color-text-primary)] focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-[var(--color-text-secondary)] mb-1">
                  Status
                </label>
                <select
                  value={editFormData.status}
                  onChange={(e) => setEditFormData({ ...editFormData, status: e.target.value })}
                  className="w-full px-3 py-2 bg-[var(--color-bg-primary)] border border-[var(--color-border)] rounded-sm text-[var(--color-text-primary)] focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="pending">Pending</option>
                  <option value="confirmed">Confirmed</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </div>
            </div>

            {error && (
              <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-sm">
                <p className="text-sm text-red-800">{error}</p>
              </div>
            )}

            <div className="flex gap-3 justify-end mt-6">
              <button
                onClick={() => {
                  setEditingBooking(null);
                  setError(null);
                }}
                className="px-4 py-2 text-sm font-medium text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-colors"
                disabled={isProcessing}
              >
                Cancel
              </button>
              <button
                onClick={handleSaveEdit}
                disabled={isProcessing}
                className="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 rounded-sm transition-colors flex items-center gap-2"
              >
                {isProcessing && (
                  <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-white"></div>
                )}
                Save Changes
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirmation Modal */}
      {cancelModalBooking && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-[var(--color-bg-surface)] rounded-sm p-6 max-w-md w-full border border-[var(--color-border)]">
            <h3 className="text-lg font-medium text-[var(--color-text-primary)] mb-4">
              {deleteMode === 'delete' ? 'Delete Booking' : 'Cancel Booking'}
            </h3>
            
            <div className="mb-4 space-y-2">
              <p className="text-sm text-[var(--color-text-secondary)]">
                <strong>Email:</strong> {cancelModalBooking.user_email}
              </p>
              <p className="text-sm text-[var(--color-text-secondary)]">
                <strong>Room:</strong> {cancelModalBooking.accommodations?.title || 'N/A'}
              </p>
              <p className="text-sm text-[var(--color-text-secondary)]">
                <strong>Amount:</strong> €{Number(cancelModalBooking.total_price).toFixed(2)}
              </p>
            </div>

            <p className="text-sm text-[var(--color-text-secondary)] mb-6">
              {deleteMode === 'delete' 
                ? 'This will permanently delete the booking from the database. This action cannot be undone.'
                : 'This will mark the booking as cancelled but keep the record in the database.'}
            </p>

            {error && (
              <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-sm">
                <p className="text-sm text-red-800">{error}</p>
              </div>
            )}

            <div className="flex gap-3 justify-end">
              <button
                onClick={() => {
                  setCancelModalBooking(null);
                  setError(null);
                }}
                className="px-4 py-2 text-sm font-medium text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-colors"
                disabled={isProcessing}
              >
                Cancel
              </button>
              <button
                onClick={handleCancelBooking}
                disabled={isProcessing}
                className={`px-4 py-2 text-sm font-medium text-white rounded-sm transition-colors flex items-center gap-2 ${
                  deleteMode === 'delete'
                    ? 'bg-red-600 hover:bg-red-700 disabled:bg-red-400'
                    : 'bg-yellow-600 hover:bg-yellow-700 disabled:bg-yellow-400'
                }`}
              >
                {isProcessing && (
                  <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-white"></div>
                )}
                {deleteMode === 'delete' ? 'Delete Permanently' : 'Mark as Cancelled'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}