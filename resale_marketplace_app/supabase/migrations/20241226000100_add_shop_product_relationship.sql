-- Add shop_id to products table and create auto-assignment system
-- This migration creates proper Shop-Product relationship

-- Step 1: Add shop_id column to products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS shop_id UUID REFERENCES public.shops(id) ON DELETE SET NULL;

-- Step 2: Create index for performance
CREATE INDEX IF NOT EXISTS idx_products_shop_id ON public.products(shop_id);

-- Step 3: Update existing products to link with their owner's shops
UPDATE public.products p 
SET shop_id = s.id
FROM public.shops s 
WHERE p.seller_id = s.owner_id
AND p.shop_id IS NULL;

-- Step 4: Create function to ensure user has a shop
CREATE OR REPLACE FUNCTION public.ensure_user_shop(user_id UUID, user_name TEXT DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    shop_id UUID;
    final_name TEXT;
BEGIN
    -- Check if user already has a shop
    SELECT id INTO shop_id FROM public.shops WHERE owner_id = user_id LIMIT 1;
    
    IF shop_id IS NOT NULL THEN
        RETURN shop_id;
    END IF;
    
    -- Prepare shop name
    final_name := COALESCE(NULLIF(TRIM(user_name), ''), '사용자');
    
    -- Create shop with retry logic for share_url conflicts
    FOR i IN 1..5 LOOP
        BEGIN
            INSERT INTO public.shops (
                owner_id,
                name,
                description,
                share_url,
                created_at,
                updated_at
            ) VALUES (
                user_id,
                final_name || '의 샵',
                final_name || '님의 개인 샵입니다.',
                'shop-' || REPLACE(user_id::TEXT, '-', '') || CASE WHEN i > 1 THEN '-' || i::TEXT ELSE '' END,
                NOW(),
                NOW()
            )
            RETURNING id INTO shop_id;
            
            EXIT; -- Success, exit loop
            
        EXCEPTION
            WHEN unique_violation THEN
                IF i = 5 THEN
                    RAISE; -- Re-raise after max attempts
                END IF;
                -- Continue to next iteration with different share_url
        END;
    END LOOP;
    
    -- Update user's shop_id
    UPDATE public.users 
    SET shop_id = shop_id, updated_at = NOW()
    WHERE id = user_id;
    
    RETURN shop_id;
END;
$$;

-- Step 5: Create function to auto-assign products to shops
CREATE OR REPLACE FUNCTION public.assign_product_to_shop()
RETURNS TRIGGER AS $$
DECLARE
    user_shop_id UUID;
    user_name TEXT;
BEGIN
    -- Get user's name for shop creation
    SELECT name INTO user_name FROM public.users WHERE id = NEW.seller_id;
    
    -- Ensure user has a shop and get shop_id
    user_shop_id := public.ensure_user_shop(NEW.seller_id, user_name);
    
    -- Assign product to shop
    NEW.shop_id := user_shop_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 6: Create trigger for new products
DROP TRIGGER IF EXISTS product_shop_assignment ON public.products;
CREATE TRIGGER product_shop_assignment
    BEFORE INSERT ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.assign_product_to_shop();

-- Step 7: Update any remaining products without shop_id
DO $$
DECLARE
    product_record RECORD;
    user_shop_id UUID;
    user_name TEXT;
BEGIN
    FOR product_record IN 
        SELECT p.id, p.seller_id, u.name 
        FROM public.products p
        JOIN public.users u ON p.seller_id = u.id
        WHERE p.shop_id IS NULL
    LOOP
        -- Ensure user has shop
        user_shop_id := public.ensure_user_shop(product_record.seller_id, product_record.name);
        
        -- Update product
        UPDATE public.products 
        SET shop_id = user_shop_id, updated_at = NOW()
        WHERE id = product_record.id;
    END LOOP;
END $$;

-- Step 8: Grant permissions
GRANT EXECUTE ON FUNCTION public.ensure_user_shop TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.assign_product_to_shop TO authenticated, anon;

-- Step 9: Add comments for documentation
COMMENT ON COLUMN public.products.shop_id IS 'Reference to the shop this product belongs to';
COMMENT ON FUNCTION public.ensure_user_shop IS 'Ensures a user has a shop, creates one if needed';
COMMENT ON FUNCTION public.assign_product_to_shop IS 'Automatically assigns new products to user shop';