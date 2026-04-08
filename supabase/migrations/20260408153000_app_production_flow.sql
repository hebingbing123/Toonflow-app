-- Persist production-agent flow JSON (legacy o_agentWorkData for productionAgent).

CREATE TABLE IF NOT EXISTS public.app_production_flow (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  script_id UUID NOT NULL REFERENCES public.app_script (id) ON DELETE CASCADE,
  flow_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_production_flow_project_script_unique UNIQUE (project_id, script_id)
);

CREATE INDEX IF NOT EXISTS idx_app_production_flow_project ON public.app_production_flow (project_id);

CREATE INDEX IF NOT EXISTS idx_app_production_flow_script ON public.app_production_flow (script_id);

ALTER TABLE public.app_production_flow ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_production_flow_via_script ON public.app_production_flow;

CREATE POLICY app_production_flow_via_script ON public.app_production_flow FOR ALL TO authenticated USING (
  EXISTS (
    SELECT 1
    FROM public.app_script s
    INNER JOIN public.app_project p ON p.id = s.project_id
    WHERE
      s.id = app_production_flow.script_id
      AND p.id = app_production_flow.project_id
      AND p.owner_user_id = (SELECT auth.uid ())
  )
)
WITH
  CHECK (
    EXISTS (
      SELECT 1
      FROM public.app_script s
      INNER JOIN public.app_project p ON p.id = s.project_id
      WHERE
        s.id = app_production_flow.script_id
        AND p.id = app_production_flow.project_id
        AND p.owner_user_id = (SELECT auth.uid ())
    )
  );

COMMENT ON TABLE public.app_production_flow IS 'Per project/script production flow JSON; legacy o_agentWorkData parity for productionAgent';
