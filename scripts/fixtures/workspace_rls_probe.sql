\echo '==> workspace RLS probe'
\echo 'probe_user_id=' :probe_user_id
\echo 'probe_workspace_id=' :probe_workspace_id

BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.role', 'authenticated', true);
SELECT set_config('request.jwt.claim.sub', :'probe_user_id', true);

\echo '==> auth context'
SELECT current_user AS current_role, auth.uid() AS auth_uid;

\echo '==> policy snapshot'
SELECT
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced,
  p.policyname,
  p.cmd,
  p.roles,
  p.qual,
  p.with_check
FROM pg_class c
LEFT JOIN pg_policies p
  ON p.schemaname = 'public'
 AND p.tablename = c.relname
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname IN (
    'app_workspace',
    'app_workspace_member',
    'app_project',
    'app_script',
    'app_asset',
    'app_novel',
    'app_generation_job',
    'app_agent_memory',
    'app_art_style'
  )
ORDER BY c.relname, p.policyname NULLS LAST;

\echo '==> visible rows scoped to target workspace'
SELECT 'app_workspace' AS table_name, COUNT(*)::bigint AS visible_rows
FROM public.app_workspace
WHERE id = :'probe_workspace_id'::uuid
UNION ALL
SELECT 'app_workspace_member', COUNT(*)::bigint
FROM public.app_workspace_member
WHERE workspace_id = :'probe_workspace_id'::uuid
UNION ALL
SELECT 'app_project', COUNT(*)::bigint
FROM public.app_project
WHERE workspace_id = :'probe_workspace_id'::uuid
UNION ALL
SELECT 'app_script', COUNT(*)::bigint
FROM public.app_script s
WHERE EXISTS (
  SELECT 1
  FROM public.app_project p
  WHERE p.id = s.project_id
    AND p.workspace_id = :'probe_workspace_id'::uuid
)
UNION ALL
SELECT 'app_asset', COUNT(*)::bigint
FROM public.app_asset a
WHERE EXISTS (
  SELECT 1
  FROM public.app_project p
  WHERE p.id = a.project_id
    AND p.workspace_id = :'probe_workspace_id'::uuid
)
UNION ALL
SELECT 'app_novel', COUNT(*)::bigint
FROM public.app_novel n
WHERE EXISTS (
  SELECT 1
  FROM public.app_project p
  WHERE p.id = n.project_id
    AND p.workspace_id = :'probe_workspace_id'::uuid
)
UNION ALL
SELECT 'app_generation_job', COUNT(*)::bigint
FROM public.app_generation_job j
WHERE EXISTS (
  SELECT 1
  FROM public.app_project p
  WHERE p.workspace_id = :'probe_workspace_id'::uuid
    AND (
      (j.payload->>'project_uuid') = p.id::text
      OR (
        (j.payload->>'project_uuid') IS NULL
        AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
        AND p.numeric_id = (j.payload->>'project_numeric_id')::int
      )
    )
)
UNION ALL
SELECT 'app_agent_memory', COUNT(*)::bigint
FROM public.app_agent_memory
UNION ALL
SELECT 'app_art_style', COUNT(*)::bigint
FROM public.app_art_style;

ROLLBACK;
