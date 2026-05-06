-- **P10**: 发布状态机补全生产语义
-- 新增状态：manual_pending（人工桥接待处理）、callback_timeout（回调超时）、compensating（补偿中）

-- 先删除旧的约束
ALTER TABLE public.app_publish_job
DROP CONSTRAINT IF EXISTS app_publish_job_status_check;

-- 添加新的约束，包含新状态
ALTER TABLE public.app_publish_job
ADD CONSTRAINT app_publish_job_status_check CHECK (
  status IN (
    'queued',
    'validating',
    'awaiting_confirmation',
    'uploading',
    'platform_processing',
    'succeeded',
    'partial_failed',
    'failed',
    'retrying',
    'cancelled',
    -- **P10 新增**
    'manual_pending',
    'callback_timeout',
    'compensating'
  )
);

COMMENT ON CONSTRAINT app_publish_job_status_check ON public.app_publish_job IS 
'P10: 生产级状态机 - manual_pending（人工桥接待处理）、callback_timeout（回调超时）、compensating（补偿中）';

