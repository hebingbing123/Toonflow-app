-- Outbound webhooks (user-configured): scope, event filter, lifecycle + delivery audit.

ALTER TABLE public.app_outbound_webhook
  ADD COLUMN IF NOT EXISTS workspace_id uuid REFERENCES public.app_workspace (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS event_types jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

UPDATE public.app_outbound_webhook
SET
  event_types = '["job.completed","job.failed","project.created","workspace.member.added"]'::jsonb
WHERE
  event_types = '[]'::jsonb
  OR jsonb_typeof(event_types) <> 'array'
  OR jsonb_array_length(event_types) = 0;

CREATE INDEX IF NOT EXISTS idx_app_outbound_webhook_workspace_id ON public.app_outbound_webhook (workspace_id)
WHERE
  workspace_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.app_outbound_webhook_delivery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid (),
  webhook_id uuid NOT NULL REFERENCES public.app_outbound_webhook (id) ON DELETE CASCADE,
  owner_user_id uuid NOT NULL,
  event_type text NOT NULL,
  payload jsonb NOT NULL,
  status text NOT NULL,
  http_status integer,
  error text,
  retry_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  delivered_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_app_outbound_webhook_delivery_webhook_created ON public.app_outbound_webhook_delivery (webhook_id, created_at DESC);

COMMENT ON TABLE public.app_outbound_webhook_delivery IS 'Outbound POST attempts (test + future job/project hooks); no secret stored.';
