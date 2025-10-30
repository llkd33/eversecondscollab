import { createClient } from './config';
import type { UserProfile } from '@/types';

// User type for database users table (different from UserProfile)
interface User {
  id: string;
  name?: string;
  email?: string;
  phone?: string;
  role?: string;
  is_verified?: boolean;
  avatar?: string;
  created_at?: string;
  updated_at?: string;
}

/**
 * User Service
 * Handles all user-related operations with Supabase
 */

export const userService = {
  /**
   * Get current user profile
   */
  async getCurrentUser() {
    const supabase = createClient();

    const { data: { user }, error: authError } = await supabase.auth.getUser();

    if (authError || !user) {
      console.error('Error getting current user:', authError);
      return null;
    }

    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (error) {
      console.error('Error fetching user profile:', error);
      return null;
    }

    return data as User;
  },

  /**
   * Get user by ID
   */
  async getUserById(id: string) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', id)
      .single();

    if (error) {
      console.error('Error fetching user:', error);
      throw error;
    }

    return data as User;
  },

  /**
   * Get all users (admin only)
   */
  async getAllUsers(filters?: {
    search?: string;
    role?: string;
    is_verified?: boolean;
    limit?: number;
    offset?: number;
  }) {
    const supabase = createClient();

    let query = supabase
      .from('users')
      .select('*');

    // Apply role filter
    if (filters?.role) {
      query = query.eq('role', filters.role);
    }

    // Apply verification filter
    if (filters?.is_verified !== undefined) {
      query = query.eq('is_verified', filters.is_verified);
    }

    // Apply search filter
    if (filters?.search) {
      query = query.or(`name.ilike.%${filters.search}%,email.ilike.%${filters.search}%,phone.ilike.%${filters.search}%`);
    }

    // Order by created date
    query = query.order('created_at', { ascending: false });

    // Apply pagination
    if (filters?.limit) {
      query = query.limit(filters.limit);
    }

    if (filters?.offset) {
      query = query.range(filters.offset, filters.offset + (filters?.limit || 10) - 1);
    }

    const { data, error } = await query;

    if (error) {
      console.error('Error fetching users:', error);
      throw error;
    }

    return data as User[];
  },

  /**
   * Get user statistics for admin
   */
  async getAllUsersStats() {
    const supabase = createClient();

    // Get total users
    const { count: totalUsers } = await supabase
      .from('users')
      .select('*', { count: 'exact', head: true });

    // Get verified users
    const { count: verifiedUsers } = await supabase
      .from('users')
      .select('*', { count: 'exact', head: true })
      .eq('is_verified', true);

    // Get users by role
    const { data: roleData } = await supabase
      .from('users')
      .select('role');

    const roleCounts = {
      일반: 0,
      대신판매자: 0,
      관리자: 0,
    };

    roleData?.forEach((user: any) => {
      if (user.role in roleCounts) {
        roleCounts[user.role as keyof typeof roleCounts]++;
      }
    });

    return {
      total: totalUsers || 0,
      verified: verifiedUsers || 0,
      unverified: (totalUsers || 0) - (verifiedUsers || 0),
      ...roleCounts,
    };
  },

  /**
   * Update user role (admin only)
   */
  async updateUserRole(id: string, role: '일반' | '대신판매자' | '관리자') {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('users')
      .update({ role })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating user role:', error);
      throw error;
    }

    return data;
  },

  /**
   * Verify user (admin only)
   */
  async verifyUser(id: string, verified: boolean = true) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('users')
      .update({ is_verified: verified })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error verifying user:', error);
      throw error;
    }

    return data;
  },

  /**
   * Update user profile
   */
  async updateProfile(id: string, updates: Partial<User>) {
    const supabase = createClient();

    const updateData: any = {};

    if (updates.name !== undefined) updateData.name = updates.name;
    if (updates.email !== undefined) updateData.email = updates.email;
    if (updates.phone !== undefined) updateData.phone = updates.phone;
    if (updates.avatar !== undefined) updateData.avatar = updates.avatar;

    const { data, error } = await supabase
      .from('profiles')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating profile:', error);
      throw error;
    }

    return data as User;
  },

  /**
   * Upload user avatar
   */
  async uploadAvatar(file: File, userId: string): Promise<string> {
    const supabase = createClient();
    const fileExt = file.name.split('.').pop();
    const fileName = `${userId}/avatar.${fileExt}`;

    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(fileName, file, {
        upsert: true, // Replace existing avatar
      });

    if (error) {
      console.error('Error uploading avatar:', error);
      throw error;
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('avatars')
      .getPublicUrl(fileName);

    return urlData.publicUrl;
  },

  /**
   * Get user statistics
   */
  async getUserStats(userId: string) {
    const supabase = createClient();

    // Get total products
    const { count: productCount } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('seller_id', userId);

    // Get total transactions
    const { count: transactionCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`);

    // Get completed transactions
    const { count: completedCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .or(`buyer_id.eq.${userId},seller_id.eq.${userId}`)
      .eq('status', 'completed');

    return {
      totalProducts: productCount || 0,
      totalTransactions: transactionCount || 0,
      completedTransactions: completedCount || 0,
      successRate: transactionCount ? ((completedCount || 0) / transactionCount) * 100 : 0,
    };
  },

  /**
   * Sign in with Kakao
   */
  async signInWithKakao() {
    const supabase = createClient();

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'kakao',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      console.error('Error signing in with Kakao:', error);
      throw error;
    }

    return data;
  },

  /**
   * Sign out
   */
  async signOut() {
    const supabase = createClient();

    const { error } = await supabase.auth.signOut();

    if (error) {
      console.error('Error signing out:', error);
      throw error;
    }

    return true;
  },
};
