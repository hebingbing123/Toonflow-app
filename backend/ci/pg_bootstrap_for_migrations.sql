-- Minimal Supabase-like surface for applying `supabase/migrations/*.sql` on vanilla Postgres
-- (CI or self-hosted PG without GoTrue). Not used by `supabase start` (real auth already exists).

CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.users (
  id UUID PRIMARY KEY
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END
$$;

-- RLS policies call auth.uid(); stub returns NULL (policies still install).
CREATE OR REPLACE FUNCTION auth.uid ()
RETURNS UUID
LANGUAGE sql
STABLE
AS $$
  SELECT NULL::uuid;
$$;
