-- F.2: project characters with structured voice_config; optional storyboard link.

CREATE TABLE IF NOT EXISTS public.app_project_character (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  asset_id UUID REFERENCES public.app_asset (id) ON DELETE SET NULL,
  voice_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_project_character_project_name_unique UNIQUE (project_id, name)
);

CREATE INDEX IF NOT EXISTS idx_app_project_character_project ON public.app_project_character (project_id);

COMMENT ON TABLE public.app_project_character IS 'Drama character with TTS voice mapping (F.2)';
COMMENT ON COLUMN public.app_project_character.voice_config IS 'Structured voice: provider, voice, emotion/style, pitch, rate, seedance dims';

ALTER TABLE public.app_project_character ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_project_character_via_project ON public.app_project_character;

CREATE POLICY app_project_character_via_project ON public.app_project_character FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_character.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_project_character.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

ALTER TABLE public.app_storyboard
  ADD COLUMN IF NOT EXISTS character_id UUID REFERENCES public.app_project_character (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_app_storyboard_character ON public.app_storyboard (character_id);

COMMENT ON COLUMN public.app_storyboard.character_id IS 'Optional character for per-role TTS voice (F.2)';
