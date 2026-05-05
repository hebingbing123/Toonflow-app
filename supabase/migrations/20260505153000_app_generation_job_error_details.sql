-- D5: structured failure diagnostics for Task Center (e.g. video.export) + deep_links JSON.
ALTER TABLE public.app_generation_job
  ADD COLUMN IF NOT EXISTS error_details JSONB;

COMMENT ON COLUMN public.app_generation_job.error_details IS
  'Optional JSON when status=failed (machine code, deep_links to project/script/storyboard numeric ids); worker-owned';
