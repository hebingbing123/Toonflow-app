-- 创建导出任务表
CREATE TABLE IF NOT EXISTS app_export_task (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES app_project(id) ON DELETE CASCADE,
  version_id UUID,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  stage VARCHAR(20),
  progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  format VARCHAR(10) NOT NULL,
  quality JSONB NOT NULL,
  output_url TEXT,
  error TEXT,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_export_task_project_id ON app_export_task(project_id);
CREATE INDEX IF NOT EXISTS idx_export_task_status ON app_export_task(status);
CREATE INDEX IF NOT EXISTS idx_export_task_created_at ON app_export_task(created_at DESC);

-- 添加注释
COMMENT ON TABLE app_export_task IS '视频导出任务表';
COMMENT ON COLUMN app_export_task.id IS '任务 ID';
COMMENT ON COLUMN app_export_task.project_id IS '项目 ID';
COMMENT ON COLUMN app_export_task.version_id IS '版本 ID（可选）';
COMMENT ON COLUMN app_export_task.status IS '任务状态: pending, running, completed, failed, cancelled';
COMMENT ON COLUMN app_export_task.stage IS '当前阶段: preparing, encoding, uploading, finalizing';
COMMENT ON COLUMN app_export_task.progress IS '进度百分比 (0-100)';
COMMENT ON COLUMN app_export_task.format IS '导出格式: mp4, mov, webm';
COMMENT ON COLUMN app_export_task.quality IS '质量参数 JSON: {resolution, bitrate, framerate}';
COMMENT ON COLUMN app_export_task.output_url IS '输出文件 URL';
COMMENT ON COLUMN app_export_task.error IS '错误信息';
COMMENT ON COLUMN app_export_task.started_at IS '开始时间';
COMMENT ON COLUMN app_export_task.completed_at IS '完成时间';
COMMENT ON COLUMN app_export_task.created_at IS '创建时间';
COMMENT ON COLUMN app_export_task.updated_at IS '更新时间';
