CREATE TABLE IF NOT EXISTS app_outbound_webhook (
  id uuid PRIMARY KEY,
  owner_user_id uuid NOT NULL,
  url text NOT NULL,
  secret text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_outbound_webhook_owner_user_id
  ON app_outbound_webhook(owner_user_id);
