-- Preserve API key audit history after key deletion.
-- `api_key_id` remains as the deleted key's identifier, but the audit table
-- intentionally no longer enforces a foreign key back to `app_api_key`.

DO $$
DECLARE
  fk_name text;
BEGIN
  SELECT c.conname
  INTO fk_name
  FROM pg_constraint c
  WHERE
    c.conrelid = 'public.app_api_key_audit'::regclass
    AND c.confrelid = 'public.app_api_key'::regclass
    AND c.contype = 'f'
    AND array_position(c.conkey, (
      SELECT attnum
      FROM pg_attribute
      WHERE
        attrelid = 'public.app_api_key_audit'::regclass
        AND attname = 'api_key_id'
        AND NOT attisdropped
    )) IS NOT NULL;

  IF fk_name IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.app_api_key_audit DROP CONSTRAINT %I',
      fk_name
    );
  END IF;
END $$;

COMMENT ON COLUMN public.app_api_key_audit.api_key_id IS
  'Identifier of the API key that triggered the event; retained after key deletion for audit history.';
