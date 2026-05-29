-- Widen project-domain RLS to workspace members (rebuild plan P0-2 / stage 22).
-- Aligns app_project / app_script / app_asset with app_project_timeline pattern.

-- app_project
DROP POLICY IF EXISTS app_project_own ON public.app_project;

CREATE POLICY app_project_workspace_member ON public.app_project FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE m.workspace_id = app_project.workspace_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_workspace_member m
    WHERE m.workspace_id = app_project.workspace_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

-- app_script
DROP POLICY IF EXISTS app_script_own ON public.app_script;

CREATE POLICY app_script_workspace_member ON public.app_script FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_script.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_script.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

-- app_asset
DROP POLICY IF EXISTS app_asset_own ON public.app_asset;

CREATE POLICY app_asset_workspace_member ON public.app_asset FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_asset.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_project p
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE p.id = app_asset.project_id
      AND m.user_id = (SELECT auth.uid ())
  )
);

-- app_asset_image (chain via asset)
DROP POLICY IF EXISTS app_asset_image_own ON public.app_asset_image;

CREATE POLICY app_asset_image_workspace_member ON public.app_asset_image FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE a.id = app_asset_image.asset_id
      AND m.user_id = (SELECT auth.uid ())
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.app_asset a
    INNER JOIN public.app_project p ON p.id = a.project_id
    INNER JOIN public.app_workspace_member m ON m.workspace_id = p.workspace_id
    WHERE a.id = app_asset_image.asset_id
      AND m.user_id = (SELECT auth.uid ())
  )
);
