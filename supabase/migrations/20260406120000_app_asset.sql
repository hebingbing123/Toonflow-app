-- Script-linked assets (role / tool / scene) per project; junction to app_script.
-- Rust API parity with 历史 o_assets + o_scriptAssets (integer legacy_id on assets).

CREATE TABLE IF NOT EXISTS public.app_asset (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  legacy_id INTEGER NOT NULL UNIQUE,
  name TEXT NOT NULL,
  asset_type TEXT NOT NULL CHECK (asset_type IN ('role', 'tool', 'scene')),
  description TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  create_time_ms BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_asset_project_name_unique UNIQUE (project_id, name)
);

CREATE INDEX IF NOT EXISTS idx_app_asset_project ON public.app_asset (project_id);

CREATE TABLE IF NOT EXISTS public.app_script_asset (
  script_id UUID NOT NULL REFERENCES public.app_script (id) ON DELETE CASCADE,
  asset_id UUID NOT NULL REFERENCES public.app_asset (id) ON DELETE CASCADE,
  PRIMARY KEY (script_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_app_script_asset_asset ON public.app_script_asset (asset_id);

ALTER TABLE public.app_asset ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_asset_project_own ON public.app_asset;

CREATE POLICY app_asset_project_own ON public.app_asset FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    WHERE
      p.id = app_asset.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_project p
      WHERE
        p.id = app_asset.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

ALTER TABLE public.app_script_asset ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_script_asset_via_script ON public.app_script_asset;

CREATE POLICY app_script_asset_via_script ON public.app_script_asset FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_script s
    INNER JOIN public.app_project p ON p.id = s.project_id
    WHERE
      s.id = app_script_asset.script_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
  AND EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_script s ON s.id = app_script_asset.script_id
    WHERE
      a.id = app_script_asset.asset_id
      AND a.project_id = s.project_id
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_script s
      INNER JOIN public.app_project p ON p.id = s.project_id
      WHERE
        s.id = app_script_asset.script_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
    AND EXISTS (
      SELECT 1
      FROM public.app_asset a
      INNER JOIN public.app_script s ON s.id = app_script_asset.script_id
      WHERE
        a.id = app_script_asset.asset_id
        AND a.project_id = s.project_id
    )
  );
