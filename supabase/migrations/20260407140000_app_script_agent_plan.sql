-- Script agent plan draft (历史 **`o_agentWorkData`** for **`scriptAgent`**); scripts of record remain **`app_script`**.

CREATE TABLE IF NOT EXISTS public.app_script_agent_plan (
  id BIGSERIAL PRIMARY KEY,
  owner_user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  project_id UUID NOT NULL REFERENCES public.app_project (id) ON DELETE CASCADE,
  agent_key TEXT NOT NULL,
  plan_data JSONB NOT NULL DEFAULT '{"storySkeleton":"","adaptationStrategy":""}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT app_script_agent_plan_owner_project_agent UNIQUE (owner_user_id, project_id, agent_key)
);

CREATE INDEX IF NOT EXISTS idx_app_script_agent_plan_project ON public.app_script_agent_plan (project_id);

ALTER TABLE public.app_script_agent_plan ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_script_agent_plan_own ON public.app_script_agent_plan;

CREATE POLICY app_script_agent_plan_own ON public.app_script_agent_plan FOR ALL TO authenticated USING (owner_user_id = (SELECT auth.uid ()));

COMMENT ON TABLE public.app_script_agent_plan IS 'Script agent plan JSON (storySkeleton/adaptationStrategy); optional script snapshot in JSON on update-data; live scripts in app_script';
