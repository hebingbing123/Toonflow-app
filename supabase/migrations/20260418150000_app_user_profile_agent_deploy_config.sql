ALTER TABLE public.app_user_profile
ADD COLUMN IF NOT EXISTS agent_deploy_config JSONB DEFAULT NULL;

COMMENT ON COLUMN public.app_user_profile.agent_deploy_config IS
'Per-user agent deploy model selection overlay for the four legacy o_agentDeploy rows. Keys remain server-side only.';
