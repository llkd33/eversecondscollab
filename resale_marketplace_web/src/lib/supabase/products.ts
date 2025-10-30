import { createClient } from './config';
import type { Product, Category, ProductStatus } from '@/types';

/**
 * Product Service
 * Handles all product-related operations with Supabase
 */

export const productService = {
  /**
   * Get all products with optional filters
   */
  async getProducts(filters?: {
    category?: string;
    status?: string;
    seller_id?: string;
    search?: string;
    limit?: number;
    offset?: number;
  }) {
    const supabase = createClient();

    let query = supabase
      .from('products')
      .select(`
        *,
        seller:users!seller_id(
          id,
          name,
          email,
          phone,
          role,
          is_verified
        )
      `);

    // Apply filters
    if (filters?.category) {
      query = query.eq('category', filters.category);
    }

    if (filters?.status) {
      query = query.eq('status', filters.status);
    }

    if (filters?.seller_id) {
      query = query.eq('seller_id', filters.seller_id);
    }

    if (filters?.search) {
      query = query.or(`title.ilike.%${filters.search}%,description.ilike.%${filters.search}%`);
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
      console.error('Error fetching products:', error);
      throw error;
    }

    return data as Product[];
  },

  /**
   * Get product statistics (admin)
   */
  async getProductStats() {
    const supabase = createClient();

    // Total products
    const { count: totalProducts } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true });

    // Active products
    const { count: activeProducts } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('status', '판매중');

    // Sold products
    const { count: soldProducts } = await supabase
      .from('products')
      .select('*', { count: 'exact', head: true })
      .eq('status', '판매완료');

    // Products by category
    const { data: categoryData } = await supabase
      .from('products')
      .select('category');

    const categoryCount: Record<string, number> = {};
    categoryData?.forEach((product: any) => {
      categoryCount[product.category] = (categoryCount[product.category] || 0) + 1;
    });

    return {
      total: totalProducts || 0,
      active: activeProducts || 0,
      sold: soldProducts || 0,
      byCategory: categoryCount,
    };
  },

  /**
   * Get a single product by ID
   */
  async getProductById(id: string) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('products')
      .select(`
        *,
        category:categories(id, name, slug),
        seller:profiles!seller_id(
          id,
          name,
          level,
          rating,
          total_transactions,
          success_rate
        )
      `)
      .eq('id', id)
      .single();

    if (error) {
      console.error('Error fetching product:', error);
      throw error;
    }

    return data as Product;
  },

  /**
   * Get all categories
   */
  async getCategories() {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .order('name');

    if (error) {
      console.error('Error fetching categories:', error);
      // Return default categories if table doesn't exist
      return [
        { id: '1', name: '의류', slug: 'clothing', icon: '👕' },
        { id: '2', name: '전자기기', slug: 'electronics', icon: '📱' },
        { id: '3', name: '생활용품', slug: 'household', icon: '🏠' },
        { id: '4', name: '가구', slug: 'furniture', icon: '🪑' },
        { id: '5', name: '스포츠', slug: 'sports', icon: '⚽' },
        { id: '6', name: '도서', slug: 'books', icon: '📚' },
        { id: '99', name: '기타', slug: 'other', icon: '📦' },
      ] as Category[];
    }

    return data as Category[];
  },

  /**
   * Create a new product
   */
  async createProduct(product: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('products')
      .insert({
        title: product.title,
        price: product.price,
        description: product.description,
        images: product.images,
        category_id: product.category.id,
        seller_id: product.sellerId,
        resale_enabled: product.resaleEnabled,
        commission_rate: product.commissionRate,
        status: product.status,
      })
      .select()
      .single();

    if (error) {
      console.error('Error creating product:', error);
      throw error;
    }

    return data as Product;
  },

  /**
   * Update a product
   */
  async updateProduct(id: string, updates: Partial<Product>) {
    const supabase = createClient();

    const updateData: any = {};

    if (updates.title !== undefined) updateData.title = updates.title;
    if (updates.price !== undefined) updateData.price = updates.price;
    if (updates.description !== undefined) updateData.description = updates.description;
    if (updates.images !== undefined) updateData.images = updates.images;
    if (updates.status !== undefined) updateData.status = updates.status;
    if (updates.resaleEnabled !== undefined) updateData.resale_enabled = updates.resaleEnabled;
    if (updates.commissionRate !== undefined) updateData.commission_rate = updates.commissionRate;

    const { data, error } = await supabase
      .from('products')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

    if (error) {
      console.error('Error updating product:', error);
      throw error;
    }

    return data as Product;
  },

  /**
   * Delete a product
   */
  async deleteProduct(id: string) {
    const supabase = createClient();

    const { error } = await supabase
      .from('products')
      .delete()
      .eq('id', id);

    if (error) {
      console.error('Error deleting product:', error);
      throw error;
    }

    return true;
  },

  /**
   * Get products by seller
   */
  async getProductsBySeller(sellerId: string) {
    const supabase = createClient();

    const { data, error } = await supabase
      .from('products')
      .select(`
        *,
        category:categories(id, name, slug)
      `)
      .eq('seller_id', sellerId)
      .order('created_at', { ascending: false });

    if (error) {
      console.error('Error fetching seller products:', error);
      throw error;
    }

    return data as Product[];
  },

  /**
   * Upload product image
   */
  async uploadProductImage(file: File, productId: string): Promise<string> {
    const supabase = createClient();
    const fileExt = file.name.split('.').pop();
    const fileName = `${productId}/${Date.now()}.${fileExt}`;

    const { data, error } = await supabase.storage
      .from('products')
      .upload(fileName, file);

    if (error) {
      console.error('Error uploading image:', error);
      throw error;
    }

    // Get public URL
    const { data: urlData } = supabase.storage
      .from('products')
      .getPublicUrl(fileName);

    return urlData.publicUrl;
  },
};
