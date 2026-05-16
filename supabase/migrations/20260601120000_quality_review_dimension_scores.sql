-- Migration: 为 app_quality_review 新增 dimension_scores 列
-- 用途：存储各评审维度的结构化评分（JSON 对象，键为维度名，值为 1-10 整数）
-- 回滚方式：ALTER TABLE app_quality_review DROP COLUMN IF EXISTS dimension_scores

ALTER TABLE public.app_quality_review
    ADD COLUMN IF NOT EXISTS dimension_scores jsonb NULL;

COMMENT ON COLUMN public.app_quality_review.dimension_scores IS
    '维度评分 JSON 对象。合法键：visual_consistency（画面/人设一致性）、narrative_coherence（叙事连贯性）、lip_sync（对口型）、pacing（节奏）、character_consistency（人设一致性）、dialogue_naturalness（对白自然度）、faithfulness（与原著/设定符合度）。值范围：1-10 整数（含边界）。';
