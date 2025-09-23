-- Ensure products.seller_id has a foreign key to users.id so PostgREST can expose the relationship
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'products_seller_id_fkey'
      AND conrelid = 'public.products'::regclass
  ) THEN
    ALTER TABLE public.products
      ADD CONSTRAINT products_seller_id_fkey
      FOREIGN KEY (seller_id)
      REFERENCES public.users(id)
      ON UPDATE CASCADE
      ON DELETE CASCADE;
  END IF;
END
$$;

-- Refresh PostgREST schema cache so the new relationship is picked up immediately
NOTIFY pgrst, 'reload schema';
