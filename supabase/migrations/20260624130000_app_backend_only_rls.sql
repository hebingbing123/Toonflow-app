-- HEALTH-006–009: backend-only / audit tables — RLS on, no authenticated policies, revoke API roles.

-- Batch B: audit / governance
ALTER TABLE public.app_content_compliance_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_content_compliance_audit FROM anon, authenticated;

ALTER TABLE public.app_harness_user_wasm_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_harness_user_wasm_audit FROM anon, authenticated;

ALTER TABLE public.app_outbound_webhook_config_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_outbound_webhook_config_audit FROM anon, authenticated;

ALTER TABLE public.app_project_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_project_audit FROM anon, authenticated;

ALTER TABLE public.app_project_governance_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_project_governance_audit FROM anon, authenticated;

ALTER TABLE public.app_user_governance_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_user_governance_audit FROM anon, authenticated;

ALTER TABLE public.app_user_search_saved_view_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_user_search_saved_view_audit FROM anon, authenticated;

ALTER TABLE public.app_workspace_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_workspace_audit FROM anon, authenticated;

ALTER TABLE public.app_workspace_governance_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_workspace_governance_audit FROM anon, authenticated;

-- Batch C: ops / integration / billing
ALTER TABLE public.app_ab_test_results ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_ab_test_results FROM anon, authenticated;

ALTER TABLE public.app_benchmark_ab_compare_case ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_benchmark_ab_compare_case FROM anon, authenticated;

ALTER TABLE public.app_benchmark_ab_compare_run ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_benchmark_ab_compare_run FROM anon, authenticated;

ALTER TABLE public.app_billing_checkout_session ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_billing_checkout_session FROM anon, authenticated;

ALTER TABLE public.app_billing_webhook_event ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_billing_webhook_event FROM anon, authenticated;

ALTER TABLE public.app_content_compliance_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_content_compliance_report FROM anon, authenticated;

ALTER TABLE public.app_dashboard_refresh_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_dashboard_refresh_state FROM anon, authenticated;

ALTER TABLE public.app_export_task ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_export_task FROM anon, authenticated;

ALTER TABLE public.app_help_hub_link ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_help_hub_link FROM anon, authenticated;

ALTER TABLE public.app_outbound_webhook ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_outbound_webhook FROM anon, authenticated;

ALTER TABLE public.app_outbound_webhook_delivery ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_outbound_webhook_delivery FROM anon, authenticated;

ALTER TABLE public.app_publish_copy_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_publish_copy_cache FROM anon, authenticated;

ALTER TABLE public.app_video_prompt_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.app_video_prompt_cache FROM anon, authenticated;

-- HEALTH-009: staging (schema renamed legacy_staging → import_staging)
ALTER TABLE import_staging.snapshot ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE import_staging.snapshot FROM anon, authenticated;
