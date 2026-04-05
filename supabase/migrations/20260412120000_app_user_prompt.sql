-- Per-user prompt templates (parity with SQLite **`o_prompt`** + **`/api/setting/promptManage/*`**).
-- **`legacy_id`** 1–3 matches legacy **`o_prompt.id`** for stable **`PATCH`** paths.
CREATE TABLE IF NOT EXISTS public.app_user_prompt (
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  legacy_id SMALLINT NOT NULL,
  name TEXT,
  kind TEXT NOT NULL,
  body TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
  PRIMARY KEY (owner_user_id, legacy_id),
  CONSTRAINT app_user_prompt_legacy_chk CHECK (
    legacy_id >= 1
    AND legacy_id <= 32767
  ),
  CONSTRAINT app_user_prompt_kind_unique UNIQUE (owner_user_id, kind)
);

CREATE INDEX IF NOT EXISTS idx_app_user_prompt_kind ON public.app_user_prompt (owner_user_id, kind);

COMMENT ON TABLE public.app_user_prompt IS 'User-scoped prompt bodies; defaults served from server files until first PATCH';

ALTER TABLE public.app_user_prompt ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_prompt_own ON public.app_user_prompt;
CREATE POLICY app_user_prompt_own ON public.app_user_prompt FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()))
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));
