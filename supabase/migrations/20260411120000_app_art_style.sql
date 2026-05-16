-- User-scoped art style presets (历史 **`o_artStyle`**: id, name, fileUrl, label, prompt).

CREATE TABLE IF NOT EXISTS public.app_art_style (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  file_url TEXT,
  label TEXT,
  prompt TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_art_style_owner ON public.app_art_style (owner_user_id);

ALTER TABLE public.app_art_style ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_art_style_own ON public.app_art_style;

CREATE POLICY app_art_style_own ON public.app_art_style FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()))
WITH
  CHECK (owner_user_id = (SELECT auth.uid ()));

COMMENT ON TABLE public.app_art_style IS 'Per-user art style library; SQLite o_artStyle parity (subset; no binary upload in Rust MVP)';
