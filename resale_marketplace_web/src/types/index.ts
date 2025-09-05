export interface Product {
  id: string;
  title: string;
  price: number;
  description: string;
  images: string[];
  category: Category;
  sellerId: string;
  sellerInfo: UserProfile;
  resaleEnabled: boolean;
  commissionRate?: number;
  commissionAmount?: number;
  status: ProductStatus;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserProfile {
  id: string;
  name: string;
  phoneNumber?: string;
  profileImage?: string;
  level: number;
  rating: number;
  totalTransactions: number;
  successRate: number;
}

export interface Category {
  id: string;
  name: string;
  slug: string;
  icon?: string;
}

export enum ProductStatus {
  ACTIVE = 'active',
  SOLD = 'sold',
  RESERVED = 'reserved',
  HIDDEN = 'hidden',
}

export interface ResaleItem {
  id: string;
  originalProductId: string;
  resellerId: string;
  customPrice?: number;
  isActive: boolean;
  addedAt: Date;
}

export interface Transaction {
  id: string;
  buyerId: string;
  sellerId: string;
  resellerId?: string;
  productId: string;
  amount: number;
  status: TransactionStatus;
  createdAt: Date;
  completedAt?: Date;
}

export enum TransactionStatus {
  PENDING = 'pending',
  PAID = 'paid',
  SHIPPED = 'shipped',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  DISPUTED = 'disputed',
}