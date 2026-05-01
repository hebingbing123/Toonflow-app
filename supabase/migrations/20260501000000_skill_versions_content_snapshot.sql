-- 技能文件版本管理：新增 content_snapshot 字段，支持真正的文件内容回滚
-- 需求 24.4：回滚操作须将文件内容恢复到指定版本

ALTER TABLE public.app_skill_versions
    ADD COLUMN IF NOT EXISTS content_snapshot TEXT;

COMMENT ON COLUMN public.app_skill_versions.content_snapshot IS
    '版本对应的文件内容快照，用于回滚时恢复文件内容；NULL 表示旧版本记录（迁移前写入）';
