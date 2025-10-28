// Supabase database types for safe_transactions
export interface SafeTransactionDbRow {
  id: string;
  transaction_id: string;
  deposit_amount: number;
  deposit_confirmed: boolean;
  shipping_confirmed: boolean;
  delivery_confirmed: boolean;
  settlement_status: string;
  admin_notes?: string;
  created_at: string;
  updated_at: string;
  transactions?: {
    products?: {
      title?: string;
    };
    buyer?: {
      name?: string;
      phone?: string;
    };
    seller?: {
      name?: string;
      phone?: string;
    };
    reseller?: {
      name?: string;
      phone?: string;
    };
  };
}

// Edge function response types
export interface EdgeFunctionResult<T = unknown> {
  data: T;
  error?: string;
}
