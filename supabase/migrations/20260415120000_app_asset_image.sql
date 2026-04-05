-- Per-asset image history (legacy **`o_image`** rows linked by **`assetsId`** to parent **`o_assets`**).

CREATE TABLE IF NOT EXISTS public.app_asset_image (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  asset_id UUID NOT NULL REFERENCES public.app_asset (id) ON DELETE CASCADE,
  sort_index INTEGER NOT NULL DEFAULT 0,
  file_path TEXT,
  state TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_asset_image_asset_sort ON public.app_asset_image (asset_id, sort_index);

ALTER TABLE public.app_asset_image ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_asset_image_via_asset ON public.app_asset_image;

CREATE POLICY app_asset_image_via_asset ON public.app_asset_image FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    WHERE
      a.id = app_asset_image.asset_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    WHERE
      a.id = app_asset_image.asset_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
);

COMMENT ON TABLE public.app_asset_image IS 'Image history rows per app_asset; corner-scape lists rows with state 已完成 (legacy o_image parity)';
