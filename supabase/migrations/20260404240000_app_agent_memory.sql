-- Agent chat memory (SQLite `memories` parity for Rust + Supabase PG).
CREATE TABLE IF NOT EXISTS public.app_agent_memory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  legacy_project_id INTEGER NOT NULL,
  episodes_id INTEGER,
  agent_type TEXT NOT NULL,
  memory_type TEXT NOT NULL,
  role TEXT,
  name TEXT,
  content TEXT NOT NULL,
  embedding TEXT,
  related_message_ids TEXT,
  summarized SMALLINT NOT NULL DEFAULT 0,
  create_time_ms BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
  CONSTRAINT app_agent_memory_agent_type_chk CHECK (agent_type IN ('scriptAgent', 'productionAgent')),
  CONSTRAINT app_agent_memory_memory_type_chk CHECK (memory_type IN ('message', 'summary'))
);

CREATE INDEX IF NOT EXISTS idx_app_agent_memory_lookup ON public.app_agent_memory (
  owner_user_id,
  legacy_project_id,
  agent_type,
  episodes_id,
  memory_type
);

COMMENT ON TABLE public.app_agent_memory IS 'Per-user agent memory; isolation = legacy_project_id + agent_type + episodes_id (NULL = no episode scope)';

ALTER TABLE public.app_agent_memory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_agent_memory_own ON public.app_agent_memory;
CREATE POLICY app_agent_memory_own ON public.app_agent_memory FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()))
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));
