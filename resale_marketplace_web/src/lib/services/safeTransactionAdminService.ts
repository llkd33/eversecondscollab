import { supabase } from '@/lib/supabase/config';

export interface SafeTransactionStats {
  totalCount: number;
  waitingDepositCount: number;
  waitingShippingCount: number;
  shippingCount: number;
  waitingSettlementCount: number;
  completedCount: number;
}

export interface SafeTransaction {
  id: string;
  transactionId: string;
  productTitle: string;
  buyerName: string;
  buyerPhone: string;
  sellerName: string;
  sellerPhone: string;
  resellerName?: string;
  depositAmount: number;
  depositConfirmed: boolean;
  shippingConfirmed: boolean;
  deliveryConfirmed: boolean;
  settlementStatus: string;
  currentStep: string;
  progress: number;
  adminNotes?: string;
  createdAt: Date;
  updatedAt: Date;
}

class SafeTransactionAdminService {
  private async callEdgeFunction(action: string, data: any = {}) {
    const { data: result, error } = await supabase.functions.invoke('safe-transaction-admin', {
      body: { action, ...data }
    });

    if (error) {
      throw new Error(error.message || 'Edge function call failed');
    }

    return result;
  }

  async confirmDeposit(safeTransactionId: string, adminNotes?: string): Promise<void> {
    await this.callEdgeFunction('confirm_deposit', {
      safeTransactionId,
      adminNotes
    });
  }

  async confirmShipping(safeTransactionId: string, trackingNumber?: string, courier?: string): Promise<void> {
    await this.callEdgeFunction('confirm_shipping', {
      safeTransactionId,
      trackingNumber,
      courier
    });
  }

  async processSettlement(safeTransactionId: string, adminNotes?: string): Promise<void> {
    await this.callEdgeFunction('process_settlement', {
      safeTransactionId,
      adminNotes
    });
  }

  async updateNotes(safeTransactionId: string, adminNotes: string): Promise<void> {
    await this.callEdgeFunction('update_notes', {
      safeTransactionId,
      adminNotes
    });
  }

  async getStats(): Promise<SafeTransactionStats> {
    const result = await this.callEdgeFunction('get_stats');
    return result;
  }

  async getList(status?: string, limit: number = 50, offset: number = 0): Promise<SafeTransaction[]> {
    const params = new URLSearchParams();
    if (status) params.append('status', status);
    params.append('limit', limit.toString());
    params.append('offset', offset.toString());

    const result = await this.callEdgeFunction('get_list');
    
    return result.data.map((item: any) => this.mapToSafeTransaction(item));
  }

  private mapToSafeTransaction(item: any): SafeTransaction {
    const transaction = item.transactions;
    const product = transaction?.products;
    const buyer = transaction?.buyer;
    const seller = transaction?.seller;
    const reseller = transaction?.reseller;

    // Calculate current step and progress
    let currentStep = '입금 대기중';
    let progress = 0;

    if (item.deposit_confirmed) {
      currentStep = '배송 준비중';
      progress = 0.2;
    }
    if (item.shipping_confirmed) {
      currentStep = '배송중';
      progress = 0.4;
    }
    if (item.delivery_confirmed) {
      currentStep = '정산 대기중';
      progress = 0.6;
    }
    if (item.settlement_status === '정산준비') {
      currentStep = '정산 준비중';
      progress = 0.8;
    }
    if (item.settlement_status === '정산완료') {
      currentStep = '정산 완료';
      progress = 1.0;
    }

    return {
      id: item.id,
      transactionId: item.transaction_id,
      productTitle: product?.title || '상품명 없음',
      buyerName: buyer?.name || '구매자',
      buyerPhone: buyer?.phone || '',
      sellerName: seller?.name || '판매자',
      sellerPhone: seller?.phone || '',
      resellerName: reseller?.name,
      depositAmount: item.deposit_amount,
      depositConfirmed: item.deposit_confirmed,
      shippingConfirmed: item.shipping_confirmed,
      deliveryConfirmed: item.delivery_confirmed,
      settlementStatus: item.settlement_status,
      currentStep,
      progress,
      adminNotes: item.admin_notes,
      createdAt: new Date(item.created_at),
      updatedAt: new Date(item.updated_at)
    };
  }

  // Direct Supabase queries for real-time data (fallback)
  async getStatsDirectly(): Promise<SafeTransactionStats> {
    try {
      const { count: totalCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true });

      const { count: waitingDepositCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true })
        .eq('deposit_confirmed', false);

      const { count: waitingShippingCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true })
        .eq('deposit_confirmed', true)
        .eq('shipping_confirmed', false);

      const { count: shippingCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true })
        .eq('shipping_confirmed', true)
        .eq('delivery_confirmed', false);

      const { count: waitingSettlementCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true })
        .eq('settlement_status', '대기중');

      const { count: completedCount } = await supabase
        .from('safe_transactions')
        .select('*', { count: 'exact', head: true })
        .eq('settlement_status', '정산완료');

      return {
        totalCount: totalCount || 0,
        waitingDepositCount: waitingDepositCount || 0,
        waitingShippingCount: waitingShippingCount || 0,
        shippingCount: shippingCount || 0,
        waitingSettlementCount: waitingSettlementCount || 0,
        completedCount: completedCount || 0,
      };
    } catch (error) {
      console.error('Error getting stats directly:', error);
      throw error;
    }
  }

  async getListDirectly(status?: string, limit: number = 50, offset: number = 0): Promise<SafeTransaction[]> {
    try {
      let query = supabase
        .from('safe_transactions')
        .select(`
          *,
          transactions!transaction_id (
            *,
            products!product_id (title),
            buyer:users!buyer_id (name, phone),
            seller:users!seller_id (name, phone),
            reseller:users!reseller_id (name, phone)
          )
        `);

      if (status) {
        query = query.eq('settlement_status', status);
      }

      const { data, error } = await query
        .order('created_at', { ascending: false })
        .range(offset, offset + limit - 1);

      if (error) throw error;

      return (data || []).map(item => this.mapToSafeTransaction(item));
    } catch (error) {
      console.error('Error getting list directly:', error);
      throw error;
    }
  }
}

export const safeTransactionAdminService = new SafeTransactionAdminService();