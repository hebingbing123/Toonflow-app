-- Add next_action typed field to app_quality_review table
-- Task I.4: Promote quality nextAction to typed field for rework action

-- Add next_action column with enum constraint
ALTER TABLE public.app_quality_review
ADD COLUMN IF NOT EXISTS next_action TEXT;

-- Add check constraint for valid next_action values
ALTER TABLE public.app_quality_review
ADD CONSTRAINT next_action_check
CHECK (next_action IS NULL OR next_action IN (
    'patch_storyboard_items',
    'rollback_to_director_planning',
    'update_character_anchor',
    'observe',
    'regenerate_storyboard',
    'adjust_video_prompt',
    'retry_video_generation',
    'manual_review'
));

COMMENT ON COLUMN public.app_quality_review.next_action IS 
'Typed next action for rework workflows: patch_storyboard_items, rollback_to_director_planning, update_character_anchor, observe, regenerate_storyboard, adjust_video_prompt, retry_video_generation, manual_review';

-- Create index for filtering by next_action
CREATE INDEX idx_quality_review_next_action ON public.app_quality_review(next_action) 
WHERE next_action IS NOT NULL;
