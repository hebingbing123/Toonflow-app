-- C4: 候选资产工作流 — pending / linked / ignored（可空：非候选流资产为 NULL）

ALTER TABLE public.app_asset
ADD COLUMN IF NOT EXISTS candidate_status TEXT;

ALTER TABLE public.app_asset DROP CONSTRAINT IF EXISTS app_asset_candidate_status_check;

ALTER TABLE public.app_asset
ADD CONSTRAINT app_asset_candidate_status_check CHECK (
  candidate_status IS NULL
  OR candidate_status IN ('pending', 'linked', 'ignored')
);

COMMENT ON COLUMN public.app_asset.candidate_status IS
  'Short-video candidate confirmation: pending | linked | ignored; NULL when not in candidate flow';
