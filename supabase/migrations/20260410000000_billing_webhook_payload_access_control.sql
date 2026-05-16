-- Migration: Restrict access to billing webhook payload column (PII hygiene)
-- Task: 8.2 PII hygiene: aggregates only in exports/logs
-- Related: .kiro/specs/workspace-scope-billing/pii-hygiene-audit.md

-- The `payload` column in app_billing_webhook_event may contain PII from billing providers
-- (customer email, name, address, phone). This migration restricts access to ops/admin roles only.

-- Step 1: Create ops role if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ops_role') THEN
    CREATE ROLE ops_role;
  END IF;
END
$$;

-- Step 2: Revoke payload column access from authenticated users
-- (authenticated role is used by PostgREST and application connections)
REVOKE SELECT (payload) ON public.app_billing_webhook_event FROM authenticated;
REVOKE SELECT (payload) ON public.app_billing_webhook_event FROM anon;

-- Step 3: Grant payload access only to ops_role
GRANT SELECT (payload) ON public.app_billing_webhook_event TO ops_role;

-- Step 4: Grant metadata column access to authenticated users (for audit endpoint)
-- This allows /api/v1/webhooks/billing/events to return metadata without exposing payload
GRANT SELECT (
  id,
  provider_event_id,
  provider,
  raw_event_id,
  event_type,
  event_created_at,
  is_informational_event,
  created_at
) ON public.app_billing_webhook_event TO authenticated;

-- Step 5: Add comment documenting PII risk
COMMENT ON COLUMN public.app_billing_webhook_event.payload IS
  'Full webhook JSON from billing provider. MAY CONTAIN PII (email, name, address, phone). Access restricted to ops_role only. See docs/plans/billing-webhook-retention-policy.md for retention policy.';

-- Rollback instructions:
-- To restore full access (not recommended in production):
-- GRANT SELECT (payload) ON public.app_billing_webhook_event TO authenticated;
