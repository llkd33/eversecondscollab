-- Create product_likes table for like functionality
-- Run this in Supabase SQL Editor

-- Create product_likes table
CREATE TABLE IF NOT EXISTS public.product_likes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    
    -- Ensure one like per user per product
    UNIQUE(product_id, user_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS product_likes_product_id_idx ON public.product_likes(product_id);
CREATE INDEX IF NOT EXISTS product_likes_user_id_idx ON public.product_likes(user_id);
CREATE INDEX IF NOT EXISTS product_likes_created_at_idx ON public.product_likes(created_at);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER product_likes_updated_at
    BEFORE UPDATE ON public.product_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.product_likes ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view all likes
CREATE POLICY "Anyone can view product likes" ON public.product_likes
    FOR SELECT USING (true);

-- Users can only insert their own likes
CREATE POLICY "Users can insert their own likes" ON public.product_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can only delete their own likes
CREATE POLICY "Users can delete their own likes" ON public.product_likes
    FOR DELETE USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.product_likes TO authenticated;
GRANT SELECT ON public.product_likes TO anon;

-- Add like_count column to products table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' 
                   AND column_name = 'like_count' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.products ADD COLUMN like_count INTEGER DEFAULT 0;
    END IF;
END
$$;

-- Add view_count column to products table if it doesn't exist  
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' 
                   AND column_name = 'view_count' 
                   AND table_schema = 'public') THEN
        ALTER TABLE public.products ADD COLUMN view_count INTEGER DEFAULT 0;
    END IF;
END
$$;

-- Function to update like count when likes are added/removed
CREATE OR REPLACE FUNCTION public.update_product_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.products 
        SET like_count = COALESCE(like_count, 0) + 1 
        WHERE id = NEW.product_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.products 
        SET like_count = GREATEST(COALESCE(like_count, 0) - 1, 0) 
        WHERE id = OLD.product_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers to automatically update like count
DROP TRIGGER IF EXISTS product_likes_insert_trigger ON public.product_likes;
CREATE TRIGGER product_likes_insert_trigger
    AFTER INSERT ON public.product_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_product_like_count();

DROP TRIGGER IF EXISTS product_likes_delete_trigger ON public.product_likes;
CREATE TRIGGER product_likes_delete_trigger
    AFTER DELETE ON public.product_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_product_like_count();

-- Create product_views table for view tracking
CREATE TABLE IF NOT EXISTS public.product_views (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Allow anonymous views
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    
    -- Prevent duplicate views from same user within short time
    UNIQUE(product_id, user_id, DATE(created_at))
);

-- Create indexes for product_views
CREATE INDEX IF NOT EXISTS product_views_product_id_idx ON public.product_views(product_id);
CREATE INDEX IF NOT EXISTS product_views_user_id_idx ON public.product_views(user_id);
CREATE INDEX IF NOT EXISTS product_views_created_at_idx ON public.product_views(created_at);

-- Enable RLS for product_views
ALTER TABLE public.product_views ENABLE ROW LEVEL SECURITY;

-- RLS Policies for views
CREATE POLICY "Anyone can view product views" ON public.product_views
    FOR SELECT USING (true);

CREATE POLICY "Anyone can insert product views" ON public.product_views
    FOR INSERT WITH CHECK (true);

-- Grant permissions for product_views
GRANT ALL ON public.product_views TO authenticated;
GRANT SELECT, INSERT ON public.product_views TO anon;

-- Function to update view count
CREATE OR REPLACE FUNCTION public.update_product_view_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.products 
    SET view_count = COALESCE(view_count, 0) + 1 
    WHERE id = NEW.product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update view count
DROP TRIGGER IF EXISTS product_views_insert_trigger ON public.product_views;
CREATE TRIGGER product_views_insert_trigger
    AFTER INSERT ON public.product_views
    FOR EACH ROW
    EXECUTE FUNCTION public.update_product_view_count();

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';