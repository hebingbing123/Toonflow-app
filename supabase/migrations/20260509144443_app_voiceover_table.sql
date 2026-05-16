-- Base table for per-storyboard voiceover rows (TTS columns added in 20260509144445).
-- Must run before 20260509144445_extend_voiceover_table.sql.

CREATE TABLE IF NOT EXISTS public.app_voiceover (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  storyboard_id uuid NOT NULL REFERENCES public.app_storyboard (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_voiceover_storyboard_id ON public.app_voiceover (storyboard_id);
CREATE INDEX IF NOT EXISTS idx_app_voiceover_updated_at ON public.app_voiceover (updated_at DESC);

COMMENT ON TABLE public.app_voiceover IS
  'Per-storyboard voiceover / TTS artifact row; storyboard narration state may also live in app_storyboard.metadata.voiceover.';

ALTER TABLE public.app_voiceover ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_voiceover_via_storyboard ON public.app_voiceover;
CREATE POLICY app_voiceover_via_storyboard ON public.app_voiceover FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_storyboard sb
    JOIN public.app_script sc ON sc.id = sb.script_id
    JOIN public.app_project p ON p.id = sc.project_id
    WHERE
      sb.id = app_voiceover.storyboard_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_storyboard sb
      JOIN public.app_script sc ON sc.id = sb.script_id
      JOIN public.app_project p ON p.id = sc.project_id
      WHERE
        sb.id = app_voiceover.storyboard_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );
