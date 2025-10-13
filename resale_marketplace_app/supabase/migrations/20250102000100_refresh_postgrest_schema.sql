-- Refresh PostgREST schema cache to pick up recent table and function changes
-- This addresses runtime errors like PGRST204 (missing column) and RPC unavailability

-- Trigger a schema reload so PostgREST recognizes the latest changes
select pg_notify('pgrst', 'reload schema');
