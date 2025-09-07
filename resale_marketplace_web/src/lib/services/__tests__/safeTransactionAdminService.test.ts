import { describe, it, expect, beforeEach, vi } from 'vitest';
import { safeTransactionAdminService } from '../safeTransactionAdminService';
import { supabase } from '@/lib/supabase/config';

// Mock Supabase
vi.mock('@/lib/supabase/config', () => ({
  supabase: {
    functions: {
      invoke: vi.fn()
    },
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          single: vi.fn(),
          range: vi.fn(),
          order: vi.fn(() => ({
            range: vi.fn()
          }))
        })),
        count: vi.fn(),
        head: vi.fn()
      }))
    }))
  }
}));

describe('SafeTransactionAdminService', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('confirmDeposit', () => {
    it('should call edge function with correct parameters', async () => {
      const mockResponse = { success: true, message: '입금이 확인되었습니다.' };
      (supabase.functions.invoke as any).mockResolvedValue({ data: mockResponse, error: null });

      await safeTransactionAdminService.confirmDeposit('test-id', 'test notes');

      expect(supabase.functions.invoke).toHaveBeenCalledWith('safe-transaction-admin', {
        body: {
          action: 'confirm_deposit',
          safeTransactionId: 'test-id',
          adminNotes: 'test notes'
        }
      });
    });

    it('should handle errors properly', async () => {
      const mockError = { message: 'Test error' };
      (supabase.functions.invoke as any).mockResolvedValue({ data: null, error: mockError });

      await expect(safeTransactionAdminService.confirmDeposit('test-id')).rejects.toThrow('Test error');
    });
  });

  describe('confirmShipping', () => {
    it('should call edge function with tracking info', async () => {
      const mockResponse = { success: true, message: '배송이 확인되었습니다.' };
      (supabase.functions.invoke as any).mockResolvedValue({ data: mockResponse, error: null });

      await safeTransactionAdminService.confirmShipping('test-id', '1234567890', 'CJ대한통운');

      expect(supabase.functions.invoke).toHaveBeenCalledWith('safe-transaction-admin', {
        body: {
          action: 'confirm_shipping',
          safeTransactionId: 'test-id',
          trackingNumber: '1234567890',
          courier: 'CJ대한통운'
        }
      });
    });
  });

  describe('processSettlement', () => {
    it('should call edge function for settlement processing', async () => {
      const mockResponse = { success: true, message: '정산이 완료되었습니다.' };
      (supabase.functions.invoke as any).mockResolvedValue({ data: mockResponse, error: null });

      await safeTransactionAdminService.processSettlement('test-id', 'Settlement complete');

      expect(supabase.functions.invoke).toHaveBeenCalledWith('safe-transaction-admin', {
        body: {
          action: 'process_settlement',
          safeTransactionId: 'test-id',
          adminNotes: 'Settlement complete'
        }
      });
    });
  });

  describe('getStatsDirectly', () => {
    it('should fetch stats from database directly', async () => {
      const mockCount = { count: 5 };
      const mockFrom = {
        select: vi.fn(() => ({
          eq: vi.fn(() => mockCount),
          count: mockCount
        }))
      };
      (supabase.from as any).mockReturnValue(mockFrom);

      const stats = await safeTransactionAdminService.getStatsDirectly();

      expect(stats).toEqual({
        totalCount: 5,
        waitingDepositCount: 5,
        waitingShippingCount: 5,
        shippingCount: 5,
        waitingSettlementCount: 5,
        completedCount: 5
      });
    });
  });

  describe('getListDirectly', () => {
    it('should fetch safe transactions list from database', async () => {
      const mockData = [
        {
          id: 'st-1',
          transaction_id: 'tx-1',
          deposit_amount: 100000,
          deposit_confirmed: false,
          shipping_confirmed: false,
          delivery_confirmed: false,
          settlement_status: '대기중',
          admin_notes: 'Test notes',
          created_at: '2024-03-15T10:00:00Z',
          updated_at: '2024-03-15T10:00:00Z',
          transactions: {
            products: { title: 'Test Product' },
            buyer: { name: 'Test Buyer', phone: '010-1234-5678' },
            seller: { name: 'Test Seller', phone: '010-2345-6789' },
            reseller: null
          }
        }
      ];

      const mockQuery = {
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            order: vi.fn(() => ({
              range: vi.fn(() => ({ data: mockData, error: null }))
            }))
          })),
          order: vi.fn(() => ({
            range: vi.fn(() => ({ data: mockData, error: null }))
          }))
        }))
      };
      (supabase.from as any).mockReturnValue(mockQuery);

      const result = await safeTransactionAdminService.getListDirectly();

      expect(result).toHaveLength(1);
      expect(result[0]).toMatchObject({
        id: 'st-1',
        transactionId: 'tx-1',
        productTitle: 'Test Product',
        buyerName: 'Test Buyer',
        sellerName: 'Test Seller',
        currentStep: '입금 대기중',
        progress: 0
      });
    });
  });
});