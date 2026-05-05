-- Add quality_gate_strategy column to app_project table
-- Supports three strategies: off, warn, block (default: block)

ALTER TABLE public.app_project
ADD COLUMN IF NOT EXISTS quality_gate_strategy TEXT;

-- Add check constraint to ensure only valid values
ALTER TABLE public.app_project
ADD CONSTRAINT quality_gate_strategy_check
CHECK (quality_gate_strategy IS NULL OR quality_gate_strategy IN ('off', 'warn', 'block'));

-- Add comment for documentation
COMMENT ON COLUMN public.app_project.quality_gate_strategy IS 
'Quality gate enforcement strategy: off (skip checks), warn (show warnings but allow), block (block on issues). Default: block';
