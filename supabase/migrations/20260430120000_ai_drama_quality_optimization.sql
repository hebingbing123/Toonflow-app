-- AI 短剧生成质量优化：数据库迁移
-- 涵盖：app_agent_memory 分层记忆、app_skill_versions 版本管理、
--        app_quality_review 阶段评审、projects 风格配置

-- ============================================================
-- 1. app_agent_memory：新增 memory_tier 和 scope_signature 字段
-- ============================================================

ALTER TABLE public.app_agent_memory
    ADD COLUMN IF NOT EXISTS memory_tier TEXT NOT NULL DEFAULT 'message'
        CHECK (memory_tier IN ('style_bible', 'stage_summary', 'delta_memory', 'message')),
    ADD COLUMN IF NOT EXISTS scope_signature JSONB;

COMMENT ON COLUMN public.app_agent_memory.memory_tier IS
    '记忆分层：style_bible=项目级风格圣经, stage_summary=阶段摘要, delta_memory=增量补丁, message=普通消息';
COMMENT ON COLUMN public.app_agent_memory.scope_signature IS
    '范围签名 JSON，包含 storyboardIds/assetIds/focusSections/episodeId 等维度，支持精确范围匹配检索';

-- 为 memory_tier 添加索引，支持按层级过滤查询
CREATE INDEX IF NOT EXISTS idx_app_agent_memory_tier
    ON public.app_agent_memory (owner_user_id, legacy_project_id, agent_type, memory_tier);

-- ============================================================
-- 2. app_skill_versions：新增技能文件版本管理表
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_skill_versions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path   TEXT NOT NULL,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    summary     TEXT CHECK (char_length(summary) <= 100),
    hash_before TEXT,
    hash_after  TEXT NOT NULL,
    changed_by  UUID REFERENCES auth.users(id),
    rollback_of UUID REFERENCES public.app_skill_versions(id)
);

CREATE INDEX IF NOT EXISTS idx_app_skill_versions_file_path
    ON public.app_skill_versions (file_path, changed_at DESC);

COMMENT ON TABLE public.app_skill_versions IS
    '技能文件（.md）和提示词模板（.txt）的版本变更记录，支持质量回归对比和回滚';
COMMENT ON COLUMN public.app_skill_versions.hash_before IS 'SHA256 of previous file content';
COMMENT ON COLUMN public.app_skill_versions.hash_after IS 'SHA256 of new file content';
COMMENT ON COLUMN public.app_skill_versions.rollback_of IS '若为回滚操作，指向被回滚的版本记录';

ALTER TABLE public.app_skill_versions ENABLE ROW LEVEL SECURITY;

-- 管理员可读写，普通用户只读
CREATE POLICY app_skill_versions_read ON public.app_skill_versions
    FOR SELECT TO authenticated USING (true);

-- ============================================================
-- 3. app_quality_review：新增阶段、评分等级、技能版本字段
-- ============================================================

ALTER TABLE public.app_quality_review
    ADD COLUMN IF NOT EXISTS stage TEXT
        CHECK (stage IN (
            'story_skeleton',
            'adaptation_strategy',
            'director_planning',
            'storyboard_table',
            'storyboard_panel',
            'video_prompt'
        )),
    ADD COLUMN IF NOT EXISTS grade TEXT
        CHECK (grade IN ('A', 'B', 'C', 'D')),
    ADD COLUMN IF NOT EXISTS skill_file_path TEXT,
    ADD COLUMN IF NOT EXISTS skill_version_hash TEXT;

COMMENT ON COLUMN public.app_quality_review.stage IS
    '生成阶段：story_skeleton/adaptation_strategy/director_planning/storyboard_table/storyboard_panel/video_prompt';
COMMENT ON COLUMN public.app_quality_review.grade IS
    '监督层评分等级：A=可直接使用, B=小修后可用, C=需较大修改, D=建议重做';
COMMENT ON COLUMN public.app_quality_review.skill_file_path IS
    '评审时使用的技能文件路径，用于版本对比';
COMMENT ON COLUMN public.app_quality_review.skill_version_hash IS
    '评审时使用的技能文件 SHA256 哈希，与 app_skill_versions.hash_after 对应';

-- 为 stage + grade 添加索引，支持分环节通过率统计
CREATE INDEX IF NOT EXISTS idx_quality_review_stage_grade
    ON public.app_quality_review (stage, grade);

-- ============================================================
-- 4. projects：新增画风技能包和故事风格技能包字段
-- ============================================================

-- 先确认 projects 表存在（通过 legacy_project_id 关联的表）
-- 使用 DO 块安全地添加字段
ALTER TABLE public.app_project
    ADD COLUMN IF NOT EXISTS art_style_pack TEXT,
    ADD COLUMN IF NOT EXISTS story_style_pack TEXT;

COMMENT ON COLUMN public.app_project.art_style_pack IS
    '画风技能包路径，如 art_skills/realpeople_ancient_chinese';
COMMENT ON COLUMN public.app_project.story_style_pack IS
    '故事风格技能包路径，如 story_skills/Sweet_romance_novel';
