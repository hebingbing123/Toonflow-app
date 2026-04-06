-- Per-user preferred text model (§12 / parity with legacy o_setting.textModel).
-- Stores a composite id matching GET /api/v1/models/detail?model_id= format: "{vendor_id}:{model_name}".
-- NULL means "use server default (TOONFLOW_DEFAULT_TEXT_MODEL_ID or first catalog text model)".

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS preferred_text_model_id TEXT;

COMMENT ON COLUMN public.app_user_profile.preferred_text_model_id IS
  'Per-user preferred text model composite id ("{vendor_id}:{model_name}"). NULL = server default.';
