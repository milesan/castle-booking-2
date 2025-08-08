import React, { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';
import { Plus, Trash2, Search, User, Upload, Shield, X } from 'lucide-react';

interface WhitelistUser {
  id: string | null;
  email: string;
  first_name: string | null;
  last_name: string | null;
  created_at: string;
  is_admin: boolean;
  status: 'active' | 'pending';
  booking_count?: number;
}

export function WhitelistSimple() {
  const [users, setUsers] = useState<WhitelistUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  
  // Add user form
  const [newEmail, setNewEmail] = useState('');
  const [newFirstName, setNewFirstName] = useState('');
  const [newLastName, setNewLastName] = useState('');
  const [newIsAdmin, setNewIsAdmin] = useState(false);
  const [isAdding, setIsAdding] = useState(false);
  
  // CSV upload
  const [showCsvModal, setShowCsvModal] = useState(false);
  const [csvText, setCsvText] = useState('');
  
  const [deleteConfirmUser, setDeleteConfirmUser] = useState<WhitelistUser | null>(null);

  useEffect(() => {
    loadUsers();
  }, []);

  async function loadUsers() {
    try {
      // Load from unified view that includes both active and pending users
      const { data: whitelistData, error: whitelistError } = await supabase
        .from('whitelist_all')
        .select('*')
        .order('created_at', { ascending: false });

      if (whitelistError) throw whitelistError;

      // Get booking counts for each user (only active users have IDs and can have bookings)
      const activeUserIds = (whitelistData || [])
        .filter(u => u.id && u.status === 'active')
        .map(u => u.id);

      let bookingCounts: Record<string, number> = {};
      
      if (activeUserIds.length > 0) {
        const { data: bookingsData, error: bookingsError } = await supabase
          .from('bookings')
          .select('user_id')
          .in('user_id', activeUserIds);

        if (bookingsError) {
          console.error('Error loading bookings:', bookingsError);
        } else {
          // Count bookings per user_id
          (bookingsData || []).forEach(booking => {
            if (booking.user_id) {
              bookingCounts[booking.user_id] = (bookingCounts[booking.user_id] || 0) + 1;
            }
          });
        }
      }

      // Merge booking counts with user data
      const usersWithBookings = (whitelistData || []).map(user => ({
        ...user,
        booking_count: user.id ? (bookingCounts[user.id] || 0) : 0
      }));

      setUsers(usersWithBookings);
      setError(null);
    } catch (err: any) {
      console.error('Error loading users:', err);
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  async function addUser() {
    if (!newEmail || isAdding) return;

    setIsAdding(true);
    setError(null);

    try {
      const { data, error } = await supabase.rpc('whitelist_add_user', {
        user_email: newEmail,
        user_first_name: newFirstName || null,
        user_last_name: newLastName || null,
        make_admin: newIsAdmin
      });

      if (error) throw error;
      
      if (!data.success) {
        throw new Error(data.error);
      }

      // Clear form
      setNewEmail('');
      setNewFirstName('');
      setNewLastName('');
      setNewIsAdmin(false);
      
      await loadUsers();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setIsAdding(false);
    }
  }

  async function removeUser(user: WhitelistUser) {
    try {
      // Use email for pending users (no ID), or ID for active users
      const { data, error } = await supabase.rpc('whitelist_remove_user', {
        user_id_or_email: user.id || user.email
      });

      if (error) throw error;
      
      if (!data.success) {
        throw new Error(data.error);
      }

      await loadUsers();
      setDeleteConfirmUser(null);
    } catch (err: any) {
      setError(err.message);
    }
  }

  async function toggleAdmin(user: WhitelistUser) {
    try {
      // Use email for pending users (no ID), or ID for active users
      const { data, error } = await supabase.rpc('whitelist_toggle_admin', {
        user_id_or_email: user.id || user.email
      });

      if (error) throw error;
      
      if (!data.success) {
        throw new Error(data.error);
      }

      await loadUsers();
    } catch (err: any) {
      setError(err.message);
    }
  }

  async function handleCsvImport() {
    if (!csvText.trim()) return;

    try {
      // Parse CSV (expecting: email,first_name,last_name,is_admin)
      const lines = csvText.trim().split('\n');
      const users = [];
      
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (!line) continue;
        
        // Skip header if it looks like one
        if (i === 0 && line.toLowerCase().includes('email')) continue;
        
        const parts = line.split(',').map(p => p.trim());
        if (parts[0] && parts[0].includes('@')) {
          users.push({
            email: parts[0],
            first_name: parts[1] || null,
            last_name: parts[2] || null,
            is_admin: parts[3] === 'true' || parts[3] === '1' || parts[3] === 'yes'
          });
        }
      }

      if (users.length === 0) {
        setError('No valid emails found in CSV');
        return;
      }

      const { data, error } = await supabase.rpc('whitelist_bulk_import', {
        users: users
      });

      if (error) throw error;
      
      if (!data.success) {
        throw new Error(data.error);
      }

      setShowCsvModal(false);
      setCsvText('');
      await loadUsers();
      
      alert(`Import complete! Added: ${data.added}, Skipped (already exist): ${data.skipped}`);
    } catch (err: any) {
      setError(err.message);
    }
  }

  const filteredUsers = users.filter(user => {
    if (!searchTerm) return true;
    const search = searchTerm.toLowerCase();
    return (
      user.email.toLowerCase().includes(search) ||
      (user.first_name?.toLowerCase() || '').includes(search) ||
      (user.last_name?.toLowerCase() || '').includes(search)
    );
  });

  if (loading) {
    return (
      <div className="flex justify-center items-center p-12">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-500"></div>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-[var(--color-text-primary)] mb-2">
          Whitelist Management
        </h2>
        <p className="text-[var(--color-text-secondary)]">
          Control who can access the booking system. Users in this list can login.
        </p>
      </div>

      {error && (
        <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-sm text-red-800">
          {error}
        </div>
      )}

      {/* Add User Form */}
      <div className="mb-6 p-4 bg-[var(--color-bg-surface)] rounded-sm border border-[var(--color-border)]">
        <div className="flex justify-between items-center mb-3">
          <h3 className="font-medium text-[var(--color-text-primary)]">Add User</h3>
          <button
            onClick={() => setShowCsvModal(true)}
            className="text-sm text-blue-600 hover:text-blue-700 flex items-center gap-1"
          >
            <Upload className="w-4 h-4" />
            Import CSV
          </button>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-5 gap-2">
          <input
            type="email"
            placeholder="Email *"
            value={newEmail}
            onChange={(e) => setNewEmail(e.target.value)}
            className="px-3 py-2 border border-[var(--color-border)] rounded-sm"
          />
          <input
            type="text"
            placeholder="First Name"
            value={newFirstName}
            onChange={(e) => setNewFirstName(e.target.value)}
            className="px-3 py-2 border border-[var(--color-border)] rounded-sm"
          />
          <input
            type="text"
            placeholder="Last Name"
            value={newLastName}
            onChange={(e) => setNewLastName(e.target.value)}
            className="px-3 py-2 border border-[var(--color-border)] rounded-sm"
          />
          <label className="flex items-center gap-2 px-3">
            <input
              type="checkbox"
              checked={newIsAdmin}
              onChange={(e) => setNewIsAdmin(e.target.checked)}
            />
            <span className="text-sm">Admin</span>
          </label>
          <button
            onClick={addUser}
            disabled={!newEmail || isAdding}
            className="px-4 py-2 bg-emerald-600 text-white rounded-sm hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
          >
            <Plus className="w-4 h-4" />
            Add
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="mb-4 relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          placeholder="Search users..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pl-10 pr-3 py-2 border border-[var(--color-border)] rounded-sm"
        />
      </div>

      {/* Stats */}
      <div className="mb-4 text-sm text-[var(--color-text-secondary)]">
        Total: {filteredUsers.length} users ({filteredUsers.filter(u => u.status === 'active').length} active, {filteredUsers.filter(u => u.status === 'pending').length} pending, {filteredUsers.filter(u => u.is_admin).length} admins)
      </div>

      {/* Users List */}
      <div className="bg-white rounded-sm border border-[var(--color-border)] overflow-hidden">
        {filteredUsers.length === 0 ? (
          <div className="p-8 text-center text-gray-500">
            {searchTerm ? 'No users found' : 'No users in whitelist'}
          </div>
        ) : (
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">User</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Bookings</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Added</th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredUsers.map((user) => (
                <tr key={user.id || user.email} className="hover:bg-gray-50/50 transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-full bg-gray-200 flex items-center justify-center">
                        <User className="w-4 h-4 text-gray-600" />
                      </div>
                      <div>
                        <div className="text-sm font-medium">
                          {user.first_name || user.last_name
                            ? `${user.first_name || ''} ${user.last_name || ''}`.trim()
                            : 'No name'}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm">{user.email}</td>
                  <td className="px-4 py-3">
                    {user.status === 'pending' ? (
                      <span className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-gray-100 text-gray-600 rounded-full">
                        Not logged in
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-green-100 text-green-700 rounded-full">
                        Active
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {user.booking_count ? (
                      <span className="text-sm font-medium">{user.booking_count}</span>
                    ) : (
                      <span className="text-sm text-gray-400">0</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {user.is_admin ? (
                      <span className="inline-flex items-center gap-1 px-2 py-1 text-xs bg-purple-100 text-purple-700 rounded-full">
                        <Shield className="w-3 h-3" />
                        Admin
                      </span>
                    ) : (
                      <span className="text-xs text-gray-500">User</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => toggleAdmin(user)}
                        className="text-xs px-2 py-1 border rounded hover:bg-gray-50"
                      >
                        {user.is_admin ? 'Remove Admin' : 'Make Admin'}
                      </button>
                      <button
                        onClick={() => setDeleteConfirmUser(user)}
                        className="text-red-600 hover:text-red-700"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* CSV Import Modal */}
      {showCsvModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-sm p-6 max-w-2xl w-full">
            <div className="flex justify-between items-center mb-4">
              <h3 className="text-lg font-medium">Import CSV</h3>
              <button onClick={() => setShowCsvModal(false)}>
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <p className="text-sm text-gray-600 mb-4">
              Format: email,first_name,last_name,is_admin
              <br />
              Example: john@example.com,John,Doe,false
            </p>
            
            <textarea
              value={csvText}
              onChange={(e) => setCsvText(e.target.value)}
              placeholder="Paste CSV data here..."
              className="w-full h-64 p-3 border rounded-sm font-mono text-sm"
            />
            
            <div className="flex justify-end gap-2 mt-4">
              <button
                onClick={() => setShowCsvModal(false)}
                className="px-4 py-2 border rounded-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={handleCsvImport}
                className="px-4 py-2 bg-emerald-600 text-white rounded-sm hover:bg-emerald-700"
              >
                Import
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Delete Confirmation */}
      {deleteConfirmUser && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-sm p-6 max-w-md w-full">
            <h3 className="text-lg font-medium mb-4">Remove User</h3>
            <p className="text-gray-600 mb-6">
              Remove <strong>{deleteConfirmUser.email}</strong> from whitelist?
              {deleteConfirmUser.status === 'pending' ? 
                ' They will not be able to create an account.' : 
                ' They will no longer be able to login.'}
            </p>
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setDeleteConfirmUser(null)}
                className="px-4 py-2 border rounded-sm hover:bg-gray-50"
              >
                Cancel
              </button>
              <button
                onClick={() => removeUser(deleteConfirmUser)}
                className="px-4 py-2 bg-red-600 text-white rounded-sm hover:bg-red-700"
              >
                Remove
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}