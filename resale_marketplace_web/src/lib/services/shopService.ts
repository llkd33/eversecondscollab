import { createServerSupabaseClient } from '@/lib/supabase/server';
import { Shop, ShopProduct, ProductStatus } from '@/types';
import { DatabaseError, NotFoundError, logError, handleAsyncError } from '@/lib/utils/errorHandler';

export interface ShopWithProducts {
  shop: Shop;
  ownProducts: ShopProduct[];
  resaleProducts: ShopProduct[];
}

/**
 * Get shop data by share URL (server-side)
 */
export async function getShopByShareUrl(shareUrl: string): Promise<ShopWithProducts | null> {
  return handleAsyncError(async () => {
    const supabase = await createServerSupabaseClient();

    // Fetch shop data
    const { data: shop, error: shopError } = await supabase
      .from('shops')
      .select('*')
      .eq('share_url', shareUrl)
      .single();

    if (shopError) {
      throw new DatabaseError('Failed to fetch shop', shopError);
    }

    if (!shop) {
      throw new NotFoundError('Shop');
    }

    // Fetch shop_products (joins for product details)
    const { data: shopProducts, error: shopProductsError } = await supabase
      .from('shop_products')
      .select(`
        is_resale,
        products (
          id,
          title,
          price,
          description,
          images,
          category,
          seller_id,
          resale_enabled,
          resale_fee_percentage,
          status,
          created_at,
          updated_at
        )
      `)
      .eq('shop_id', shop.id)
      .eq('products.status', ProductStatus.ACTIVE)
      .order('added_at', { ascending: false });

    if (shopProductsError) {
      logError(shopProductsError, { shopId: shop.id, context: 'fetch_shop_products' });
      // Return shop with empty products instead of failing completely
      return {
        shop: {
          ...shop,
          created_at: new Date(shop.created_at),
          updated_at: new Date(shop.updated_at),
        },
        ownProducts: [],
        resaleProducts: [],
      };
    }

    // Separate own products vs resale products
    const ownProducts: ShopProduct[] = [];
    const resaleProducts: ShopProduct[] = [];

    if (shopProducts) {
      for (const sp of shopProducts) {
        if (sp.products) {
          const productsArray = Array.isArray(sp.products) ? sp.products : [sp.products];
          for (const product of productsArray) {
            if (product) {
              if (sp.is_resale) {
                resaleProducts.push(product as ShopProduct);
              } else {
                ownProducts.push(product as ShopProduct);
              }
            }
          }
        }
      }
    }

    return {
      shop: {
        ...shop,
        created_at: new Date(shop.created_at),
        updated_at: new Date(shop.updated_at),
      },
      ownProducts,
      resaleProducts,
    };
  }, { shareUrl, context: 'getShopByShareUrl' }).catch((error) => {
    // Return null for not found errors (will trigger 404 page)
    if (error instanceof NotFoundError) {
      return null;
    }
    // Re-throw other errors
    throw error;
  });
}
