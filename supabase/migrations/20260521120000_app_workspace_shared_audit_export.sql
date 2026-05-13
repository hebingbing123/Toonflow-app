-- Dedicated export history for workspace shared cleared-template compliance audit
-- (replaces JSON array under app_workspace.metadata.content_compliance_cleared_templates_shared_audit_exports).

CREATE TABLE IF NOT EXISTS public.app_workspace_shared_audit_export (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  workspace_id uuid NOT NULL REFERENCES public.app_workspace (id) ON DELETE CASCADE,
  actor_user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  exported_at timestamptz NOT NULL,
  format text NOT NULL,
  file_name text NOT NULL,
  template_id text NULL,
  action text NULL,
  start_at text NULL,
  end_at text NULL,
  job_id uuid NULL,
  export_delivery text NOT NULL DEFAULT 'sync',
  created_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_workspace_shared_audit_export_ws_exported
ON public.app_workspace_shared_audit_export (workspace_id, exported_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_app_workspace_shared_audit_export_actor_exported
ON public.app_workspace_shared_audit_export (actor_user_id, exported_at DESC, id DESC);

COMMENT ON TABLE public.app_workspace_shared_audit_export IS
  'History of workspace shared cleared-template audit exports (sync inline and async job downloads); source of truth for GET …/shared/audit/exports.';

-- One-time copy from legacy workspace metadata (camelCase keys from API JSON).
INSERT INTO public.app_workspace_shared_audit_export (
  workspace_id,
  actor_user_id,
  exported_at,
  format,
  file_name,
  template_id,
  action,
  start_at,
  end_at,
  job_id,
  export_delivery
)
SELECT
  w.id,
  (e->>'actorUserId')::uuid,
  (e->>'exportedAt')::timestamptz,
  COALESCE(NULLIF(TRIM(e->>'format'), ''), 'json'),
  COALESCE(NULLIF(TRIM(e->>'fileName'), ''), 'export.bin'),
  NULLIF(TRIM(e->>'templateId'), ''),
  NULLIF(TRIM(e->>'action'), ''),
  NULLIF(TRIM(e->>'startAt'), ''),
  NULLIF(TRIM(e->>'endAt'), ''),
  CASE
    WHEN NULLIF(TRIM(e->>'jobId'), '') IS NOT NULL
    AND TRIM(e->>'jobId') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
      THEN TRIM(e->>'jobId')::uuid
    ELSE NULL
  END,
  COALESCE(NULLIF(TRIM(e->>'exportDelivery'), ''), 'sync')
FROM public.app_workspace AS w,
LATERAL jsonb_array_elements (
  COALESCE(
    w.metadata->'content_compliance_cleared_templates_shared_audit_exports',
    '[]'::jsonb
  )
) AS e
WHERE
  jsonb_typeof(
    COALESCE(
      w.metadata->'content_compliance_cleared_templates_shared_audit_exports',
      '[]'::jsonb
    )
  ) = 'array'
  AND jsonb_array_length (
    COALESCE(
      w.metadata->'content_compliance_cleared_templates_shared_audit_exports',
      '[]'::jsonb
    )
  ) > 0
  AND (e->>'actorUserId') IS NOT NULL
  AND TRIM(e->>'actorUserId') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  AND (e->>'exportedAt') IS NOT NULL;
