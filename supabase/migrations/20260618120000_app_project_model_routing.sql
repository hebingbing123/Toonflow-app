-- Add project-scoped model routing fields for text, multimodal, and voice generation.

ALTER TABLE public.app_project
  ADD COLUMN IF NOT EXISTS text_model TEXT,
  ADD COLUMN IF NOT EXISTS multimodal_model TEXT,
  ADD COLUMN IF NOT EXISTS voice_model TEXT;

COMMENT ON COLUMN public.app_project.text_model IS 'Project-level default text generation model';
COMMENT ON COLUMN public.app_project.multimodal_model IS 'Project-level default multimodal generation model';
COMMENT ON COLUMN public.app_project.voice_model IS 'Project-level default voice / TTS model override';
