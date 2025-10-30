import { createClient } from './config';
import type { Transaction, TransactionStatus } from '@/types';

/**
 * Transaction Service
 * Handles all transaction-related operations with Supabase
 */

export const transactionService = {
  /**
   * Get all transactions with optional filters
   */
  async getTransactions(filters?: {
    userId?: string;
    status?: TransactionStatus;
    limit?: number;
    offset?: number;
  }) {
    const supabase = createClient();

    // First, try to get transactions with relationships
    let query = supabase
      .from('transactions')
      .select('*');

    // Filter by user (buyer or seller)
    if (filters?.userId) {
      query = query.or(`buyer_id.eq.${filters.userId},seller_id.eq.${filters.userId}`);
    }

    // Filter by status
    if (filters?.status) {
      query = query.eq('status', filters.status);
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

    const { data: transactions, error } = await query;

    if (error) {
      console.error('Error fetching transactions:', error);
      throw error;
    }

    if (!transactions || transactions.length === 0) {
      return [];
    }

    // Manually fetch related data
    const productIds = [...new Set(transactions.map(tx => tx.product_id).filter(Boolean))];
    const userIds = [...new Set([
      ...transactions.map(tx => tx.buyer_id),
      ...transactions.map(tx => tx.seller_id),
      ...transactions.map(tx => tx.reseller_id).filter(Boolean)
    ])];

    // Fetch products
    const { data: products } = await supabase
      .from('products')
      .select('id, title, price, images')
      .in('id', productIds);

    // Fetch users
    const { data: users } = await supabase
      .from('users')
      .select('id, name, email, phone')
      .in('id', userIds);

    // Map products and users to transactions
    const productsMap = new Map(products?.map(p => [p.id, p]) || []);
    const usersMap = new Map(users?.map(u => [u.id, u]) || []);

    const enrichedTransactions = transactions.map(tx => ({
      ...tx,
      product: productsMap.get(tx.product_id) || null,
      buyer: usersMap.get(tx.buyer_id) || null,
      seller: usersMap.get(tx.seller_id) || null,
      reseller: tx.reseller_id ? usersMap.get(tx.reseller_id) || null : null,
    }));

    return enrichedTransactions as Transaction[];
  },

  /**
   * Get a single transaction by ID
   */
  async getTransactionById(id: string) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('transactions')
      .select(`
        *,
        product:products(
          id,
          title,
          price,
          images,
          description
        ),
        buyer:profiles!buyer_id(
          id,
          name,
          email,
          phone,
          avatar
        ),
        seller:profiles!seller_id(
          id,
          name,
          email,
          phone,
          avatar
        )
      `)
      .eq('id', id)
      .single();

    if (error) {
      console.error('Error fetching transaction:', error);
      throw error;
    }

    return data as Transaction;
  },

  /**
   * Create a new transaction
   */
  async createTransaction(transaction: {
    productId: string;
    buyerId: string;
    sellerId: string;
    price: number;
    commissionRate: number;
  }) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('transactions')
      .insert({
        product_id: transaction.productId,
        buyer_id: transaction.buyerId,
        seller_id: transaction.sellerId,
        price: transaction.price,
        commission_rate: transaction.commissionRate,
        status: 'pending',
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating transaction:', error);
      throw error;
    }

    return data as Transaction;
  },

  /**
   * Update transaction status
   */
  async updateTransactionStatus(id: string, status: TransactionStatus) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('transactions')
      .update({ status })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating transaction:', error);
      throw error;
    }

    return data as Transaction;
  },

  /**
   * Get transaction statistics (admin only)
   */
  async getTransactionStats() {
    const supabase = createClient();

    // Get total transactions
    const { count: totalCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true });

    // Get pending transactions
    const { count: pendingCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'pending');

    // Get completed transactions
    const { count: completedCount } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'completed');

    // Get total revenue (sum of completed transactions)
    const { data: revenueData } = await supabase
      .from('transactions')
      .select('price, commission_rate')
      .eq('status', 'completed');

    const totalRevenue = revenueData?.reduce((sum, tx) => {
      return sum + (tx.price * (tx.commission_rate / 100));
    }, 0) || 0;

    return {
      total: totalCount || 0,
      pending: pendingCount || 0,
      completed: completedCount || 0,
      revenue: totalRevenue,
    };
  },

  /**
   * Get monthly transaction statistics
   */
  async getMonthlyStats(months: number = 6) {
    const supabase = createClient();

    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - months);

    const { data, error } = await supabase
      .from('transactions')
      .select('created_at, price, commission_rate, status')
      .gte('created_at', startDate.toISOString())
      .order('created_at');

    if (error) {
      console.error('Error fetching monthly stats:', error);
      throw error;
    }

    // Group by month
    const monthlyData: { [key: string]: { count: number; revenue: number } } = {};

    data?.forEach((tx) => {
      const month = new Date(tx.created_at).toLocaleDateString('ko-KR', {
        year: 'numeric',
        month: 'short',
      });

      if (!monthlyData[month]) {
        monthlyData[month] = { count: 0, revenue: 0 };
      }

      monthlyData[month].count += 1;

      if (tx.status === 'completed') {
        monthlyData[month].revenue += tx.price * (tx.commission_rate / 100);
      }
    });

    return Object.entries(monthlyData).map(([month, data]) => ({
      month,
      transactions: data.count,
      revenue: data.revenue,
    }));
  },
};
