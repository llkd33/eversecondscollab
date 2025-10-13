-- Ensure shops.owner_id has a foreign key to users.id so PostgREST can expose the relationship
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'shops_owner_id_fkey'
      AND conrelid = 'public.shops'::regclass
  ) THEN
    ALTER TABLE public.shops
      ADD CONSTRAINT shops_owner_id_fkey
      FOREIGN KEY (owner_id)
      REFERENCES public.users(id)
      ON UPDATE CASCADE
      ON DELETE CASCADE;
  END IF;
END
$$;

-- Refresh PostgREST schema cache for the new relationship
NOTIFY pgrst, 'reload schema';
