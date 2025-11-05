import { createClient } from './config';
import type { Product, Category } from '@/types';
import { ProductStatus } from '@/types';

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

    try {
      // First, get the product data
      const { data: productData, error: productError } = await supabase
        .from('products')
        .select('*')
        .eq('id', id)
        .single();

      if (productError) {
        console.error('Error fetching product:', {
          code: productError.code,
          message: productError.message,
          details: productError.details,
          hint: productError.hint,
        });
        throw new Error(`상품을 불러오는데 실패했습니다: ${productError.message}`);
      }

      if (!productData) {
        throw new Error('상품을 찾을 수 없습니다.');
      }

      // Get seller information from users table
      let sellerInfo: any = null;
      if (productData.seller_id) {
        try {
          const { data: sellerData, error: sellerError } = await supabase
            .from('users')
            .select('id, name, profile_image')
            .eq('id', productData.seller_id)
            .maybeSingle();

          if (sellerError) {
            console.warn('Error fetching seller info:', sellerError);
          }

          if (sellerData) {
            // Try to get additional info from profiles if it exists
            try {
              const { data: profileData } = await supabase
                .from('profiles')
                .select('level, rating, total_transactions, success_rate')
                .eq('id', productData.seller_id)
                .maybeSingle();

              sellerInfo = {
                id: sellerData.id,
                name: sellerData.name,
                profileImage: sellerData.profile_image,
                level: profileData?.level || 0,
                rating: profileData?.rating || 0,
                totalTransactions: profileData?.total_transactions || 0,
                successRate: profileData?.success_rate || 0,
              };
            } catch (profileError) {
              // profiles table might not exist, use basic seller info
              console.warn('Profiles table not available, using basic seller info');
              sellerInfo = {
                id: sellerData.id,
                name: sellerData.name,
                profileImage: sellerData.profile_image,
                level: 0,
                rating: 0,
                totalTransactions: 0,
                successRate: 0,
              };
            }
          }
        } catch (err) {
          console.warn('Error fetching seller information:', err);
        }
      }

      // Get category information if category field exists
      let category: Category | null = null;
      if (productData.category) {
        try {
          // Try to find category by name or slug
          const { data: categoryData } = await supabase
            .from('categories')
            .select('id, name, slug, icon')
            .or(`name.eq.${productData.category},slug.eq.${productData.category}`)
            .maybeSingle();

          if (categoryData) {
            category = categoryData as Category;
          } else {
            // If category not found in categories table, create a basic category object
            category = {
              id: '',
              name: productData.category,
              slug: productData.category.toLowerCase().replace(/\s+/g, '-'),
            };
          }
        } catch (categoryError) {
          console.warn('Error fetching category:', categoryError);
          // Create a basic category object as fallback
          category = {
            id: '',
            name: productData.category,
            slug: productData.category.toLowerCase().replace(/\s+/g, '-'),
          };
        }
      }

      // Ensure images is an array
      let images: string[] = [];
      if (productData.images) {
        if (Array.isArray(productData.images)) {
          images = productData.images;
        } else if (typeof productData.images === 'string') {
          // Handle case where images might be stored as JSON string
          try {
            images = JSON.parse(productData.images);
          } catch {
            images = [productData.images];
          }
        }
      }

      // Transform the data to match Product interface
      const product: Product = {
        id: productData.id,
        title: productData.title || '',
        price: productData.price || 0,
        description: productData.description || '',
        images: images,
        category: category || { id: '', name: productData.category || '기타', slug: 'other' },
        sellerId: productData.seller_id,
        sellerInfo: sellerInfo || {
          id: productData.seller_id,
          name: '알 수 없음',
          level: 0,
          rating: 0,
          totalTransactions: 0,
          successRate: 0,
        },
        resaleEnabled: productData.resale_enabled || false,
        commissionRate: productData.resale_fee_percentage 
          ? Number(productData.resale_fee_percentage) 
          : 0,
        commissionAmount: productData.resale_fee || 0,
        status: (productData.status as ProductStatus) || ProductStatus.ACTIVE,
        createdAt: productData.created_at 
          ? new Date(productData.created_at) 
          : new Date(),
        updatedAt: productData.updated_at 
          ? new Date(productData.updated_at) 
          : new Date(),
      };

      return product;
    } catch (error: any) {
      console.error('Error in getProductById:', {
        message: error?.message,
        error: error,
      });
      throw error;
    }
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
