\echo '==> workspace RLS sample seed'

BEGIN;

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
VALUES
  (
    '00000000-0000-0000-0000-000000000000'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'authenticated',
    'authenticated',
    'workspace-owner@example.com',
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    '00000000-0000-0000-0000-000000000000'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    'authenticated',
    'authenticated',
    'workspace-member@example.com',
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW()
  ),
  (
    '00000000-0000-0000-0000-000000000000'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    'authenticated',
    'authenticated',
    'workspace-outsider@example.com',
    NOW(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{}'::jsonb,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO UPDATE
SET
  email = EXCLUDED.email,
  aud = EXCLUDED.aud,
  role = EXCLUDED.role,
  email_confirmed_at = EXCLUDED.email_confirmed_at,
  raw_app_meta_data = EXCLUDED.raw_app_meta_data,
  raw_user_meta_data = EXCLUDED.raw_user_meta_data,
  updated_at = NOW();

INSERT INTO public.app_workspace (
  id,
  owner_user_id,
  name,
  workspace_type,
  metadata
)
VALUES
  (
    '20000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Owner Personal Workspace',
    'personal',
    '{}'::jsonb
  ),
  (
    '20000000-0000-0000-0000-000000000002'::uuid,
    '10000000-0000-0000-0000-000000000002'::uuid,
    'Member Personal Workspace',
    'personal',
    '{}'::jsonb
  ),
  (
    '20000000-0000-0000-0000-000000000003'::uuid,
    '10000000-0000-0000-0000-000000000003'::uuid,
    'Outsider Personal Workspace',
    'personal',
    '{}'::jsonb
  ),
  (
    '20000000-0000-0000-0000-000000000010'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'Workspace RLS Probe Team',
    'enterprise',
    '{"seed":"workspace_rls"}'::jsonb
  )
ON CONFLICT (id) DO UPDATE
SET
  owner_user_id = EXCLUDED.owner_user_id,
  name = EXCLUDED.name,
  workspace_type = EXCLUDED.workspace_type,
  metadata = EXCLUDED.metadata,
  archived_at = NULL,
  updated_at = NOW();

INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
VALUES
  ('20000000-0000-0000-0000-000000000001'::uuid, '10000000-0000-0000-0000-000000000001'::uuid, 'owner'),
  ('20000000-0000-0000-0000-000000000002'::uuid, '10000000-0000-0000-0000-000000000002'::uuid, 'owner'),
  ('20000000-0000-0000-0000-000000000003'::uuid, '10000000-0000-0000-0000-000000000003'::uuid, 'owner'),
  ('20000000-0000-0000-0000-000000000010'::uuid, '10000000-0000-0000-0000-000000000001'::uuid, 'owner'),
  ('20000000-0000-0000-0000-000000000010'::uuid, '10000000-0000-0000-0000-000000000002'::uuid, 'member')
ON CONFLICT (workspace_id, user_id) DO UPDATE
SET
  role = EXCLUDED.role,
  updated_at = NOW();

INSERT INTO public.app_user_profile (user_id, current_workspace_id, plan_tier)
VALUES
  ('10000000-0000-0000-0000-000000000001'::uuid, '20000000-0000-0000-0000-000000000010'::uuid, 'free'),
  ('10000000-0000-0000-0000-000000000002'::uuid, '20000000-0000-0000-0000-000000000010'::uuid, 'free'),
  ('10000000-0000-0000-0000-000000000003'::uuid, '20000000-0000-0000-0000-000000000003'::uuid, 'free')
ON CONFLICT (user_id) DO UPDATE
SET
  current_workspace_id = EXCLUDED.current_workspace_id,
  plan_tier = EXCLUDED.plan_tier,
  updated_at = NOW();

INSERT INTO public.app_project (
  id,
  owner_user_id,
  numeric_id,
  name,
  project_type,
  create_time_ms,
  workspace_id,
  metadata
)
VALUES
  (
    '30000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    1001,
    'Workspace RLS Probe Project',
    'short-drama',
    1715000000000,
    '20000000-0000-0000-0000-000000000010'::uuid,
    '{"seed":"workspace_rls"}'::jsonb
  )
ON CONFLICT (numeric_id) DO UPDATE
SET
  id = EXCLUDED.id,
  owner_user_id = EXCLUDED.owner_user_id,
  name = EXCLUDED.name,
  project_type = EXCLUDED.project_type,
  create_time_ms = EXCLUDED.create_time_ms,
  workspace_id = EXCLUDED.workspace_id,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();

INSERT INTO public.app_script (
  id,
  project_id,
  numeric_id,
  name,
  content,
  numeric_project_id,
  metadata
)
VALUES
  (
    '31000000-0000-0000-0000-000000000001'::uuid,
    '30000000-0000-0000-0000-000000000001'::uuid,
    2001,
    'Workspace RLS Probe Script',
    'seed script content',
    1001,
    '{"seed":"workspace_rls"}'::jsonb
  )
ON CONFLICT (numeric_id) DO UPDATE
SET
  id = EXCLUDED.id,
  project_id = EXCLUDED.project_id,
  name = EXCLUDED.name,
  content = EXCLUDED.content,
  numeric_project_id = EXCLUDED.numeric_project_id,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();

INSERT INTO public.app_novel (
  id,
  project_id,
  numeric_id,
  chapter_index,
  chapter,
  chapter_data,
  metadata
)
VALUES
  (
    '32000000-0000-0000-0000-000000000001'::uuid,
    '30000000-0000-0000-0000-000000000001'::uuid,
    3001,
    1,
    'Seed Chapter',
    'seed novel body',
    '{"seed":"workspace_rls"}'::jsonb
  )
ON CONFLICT (numeric_id) DO UPDATE
SET
  id = EXCLUDED.id,
  project_id = EXCLUDED.project_id,
  chapter_index = EXCLUDED.chapter_index,
  chapter = EXCLUDED.chapter,
  chapter_data = EXCLUDED.chapter_data,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();

INSERT INTO public.app_asset (
  id,
  project_id,
  numeric_id,
  name,
  asset_type,
  metadata
)
VALUES
  (
    '33000000-0000-0000-0000-000000000001'::uuid,
    '30000000-0000-0000-0000-000000000001'::uuid,
    4001,
    'Seed Role Asset',
    'role',
    '{"seed":"workspace_rls"}'::jsonb
  )
ON CONFLICT (numeric_id) DO UPDATE
SET
  id = EXCLUDED.id,
  project_id = EXCLUDED.project_id,
  name = EXCLUDED.name,
  asset_type = EXCLUDED.asset_type,
  metadata = EXCLUDED.metadata,
  updated_at = NOW();

INSERT INTO public.app_generation_job (
  id,
  owner_user_id,
  kind,
  status,
  payload,
  idempotency_key,
  workspace_id
)
VALUES
  (
    '34000000-0000-0000-0000-000000000001'::uuid,
    '10000000-0000-0000-0000-000000000001'::uuid,
    'seed.workspace.rls',
    'queued',
    jsonb_build_object(
      'project_uuid', '30000000-0000-0000-0000-000000000001',
      'project_numeric_id', 1001,
      'workspace_id', '20000000-0000-0000-0000-000000000010'
    ),
    'workspace-rls-seed-job',
    '20000000-0000-0000-0000-000000000010'::uuid
  )
ON CONFLICT (owner_user_id, idempotency_key)
WHERE idempotency_key IS NOT NULL
DO UPDATE
SET
  id = EXCLUDED.id,
  kind = EXCLUDED.kind,
  status = EXCLUDED.status,
  payload = EXCLUDED.payload,
  updated_at = NOW();

COMMIT;

\echo 'seed_workspace_id=20000000-0000-0000-0000-000000000010'
\echo 'seed_owner_user_id=10000000-0000-0000-0000-000000000001'
\echo 'seed_member_user_id=10000000-0000-0000-0000-000000000002'
\echo 'seed_outsider_user_id=10000000-0000-0000-0000-000000000003'
