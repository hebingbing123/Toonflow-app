-- F3: multi-target serial order within one draft (worker respects ascending serial_order).

ALTER TABLE public.app_publish_target
  ADD COLUMN IF NOT EXISTS serial_order INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_app_publish_target_draft_serial ON public.app_publish_target (
  draft_id,
  serial_order ASC,
  platform_id ASC
);

COMMENT ON COLUMN public.app_publish_target.serial_order IS 'Lower runs first when publishing targets sequentially (Wave β / F3).';
