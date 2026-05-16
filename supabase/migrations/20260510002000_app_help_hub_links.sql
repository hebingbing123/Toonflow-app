-- Help Hub: persisted links (user + workspace scopes)

CREATE TABLE IF NOT EXISTS app_help_hub_link (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope TEXT NOT NULL CHECK (scope IN ('env', 'workspace', 'user')),
    workspace_id UUID,
    user_id UUID,
    link_id TEXT NOT NULL,
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_help_hub_scope_owner CHECK (
      (scope = 'workspace' AND workspace_id IS NOT NULL AND user_id IS NULL)
      OR (scope = 'user' AND user_id IS NOT NULL)
      OR (scope = 'env' AND workspace_id IS NULL AND user_id IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_help_hub_link_workspace_order
  ON app_help_hub_link(workspace_id, sort_order);

CREATE INDEX IF NOT EXISTS idx_help_hub_link_user_order
  ON app_help_hub_link(user_id, sort_order);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_help_hub_link_workspace_link_id
  ON app_help_hub_link(workspace_id, link_id)
  WHERE scope = 'workspace';

CREATE UNIQUE INDEX IF NOT EXISTS uniq_help_hub_link_user_link_id
  ON app_help_hub_link(user_id, link_id)
  WHERE scope = 'user';

COMMENT ON TABLE app_help_hub_link IS 'Persisted Help Hub links for workspace/user scopes';
