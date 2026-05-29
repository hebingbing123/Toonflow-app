-- Block-level asset index for DPI-aware delivery (rebuild plan P0-4 / stage 15+20).

CREATE TABLE IF NOT EXISTS public.app_asset_block (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id UUID NOT NULL REFERENCES public.app_asset (id) ON DELETE CASCADE,
  block_key TEXT NOT NULL,
  dpi_tier SMALLINT NOT NULL DEFAULT 1
    CONSTRAINT app_asset_block_dpi_tier_positive CHECK (dpi_tier > 0 AND dpi_tier <= 4),
  storage_path TEXT NOT NULL,
  width INTEGER NOT NULL
    CONSTRAINT app_asset_block_width_positive CHECK (width > 0),
  height INTEGER NOT NULL
    CONSTRAINT app_asset_block_height_positive CHECK (height > 0),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_asset_block_unique_key UNIQUE (asset_id, block_key, dpi_tier)
);

CREATE INDEX IF NOT EXISTS idx_app_asset_block_asset
  ON public.app_asset_block (asset_id);

COMMENT ON TABLE public.app_asset_block IS
  'Per-block raster assets at independent DPI tiers; no tiled spritesheets.';

ALTER TABLE public.app_asset_block ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_asset_block_via_project ON public.app_asset_block;

CREATE POLICY app_asset_block_via_project ON public.app_asset_block FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE a.id = app_asset_block.asset_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE a.id = app_asset_block.asset_id
      AND m.user_id = (SELECT auth.uid ())
  )
);
