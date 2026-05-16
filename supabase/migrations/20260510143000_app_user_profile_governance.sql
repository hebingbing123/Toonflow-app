-- Internal admin governance state for user suspension / quota override operations.

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS operational_status TEXT NOT NULL DEFAULT 'active'
  CHECK (operational_status IN ('active', 'suspended'));

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS operational_status_reason TEXT;

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS ops_note TEXT;

ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS ops_updated_at TIMESTAMPTZ;

COMMENT ON COLUMN public.app_user_profile.operational_status IS
  'Internal governance state. active = normal access; suspended = product API access blocked.';

COMMENT ON COLUMN public.app_user_profile.operational_status_reason IS
  'Operator-supplied reason when a user is suspended or otherwise manually governed.';

COMMENT ON COLUMN public.app_user_profile.ops_note IS
  'Internal-only support / trust-and-safety note for the user.';

COMMENT ON COLUMN public.app_user_profile.ops_updated_at IS
  'Last time an internal governance mutation updated operational fields on this profile.';

CREATE TABLE IF NOT EXISTS public.app_user_governance_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (event_type IN ('governance_updated')),
  actor_label TEXT NOT NULL DEFAULT 'internal_ops',
  previous_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  next_state JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_user_governance_audit_user_created
  ON public.app_user_governance_audit (user_id, created_at DESC);

ALTER TABLE public.app_user_governance_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_governance_audit_owner ON public.app_user_governance_audit;

COMMENT ON TABLE public.app_user_governance_audit IS
  'Internal governance audit trail for user suspension / quota override mutations. No direct authenticated-user read policy is granted.';
