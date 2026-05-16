-- Add suggested_action derived field to app_quality_review
-- Task 2.1: quality-review-driven continuous optimization

ALTER TABLE public.app_quality_review
ADD COLUMN IF NOT EXISTS suggested_action TEXT;

COMMENT ON COLUMN public.app_quality_review.suggested_action IS
'Rule-based suggested action mapped from bad_case_category for quick triage.';

CREATE INDEX IF NOT EXISTS idx_quality_review_suggested_action
ON public.app_quality_review(suggested_action)
WHERE suggested_action IS NOT NULL;
