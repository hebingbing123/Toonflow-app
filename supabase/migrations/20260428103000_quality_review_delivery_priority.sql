-- 质量评审补充：记录是否命中 delivery memory 优先策略
ALTER TABLE app_quality_review
    ADD COLUMN IF NOT EXISTS memory_delivery_priority_applied boolean;

COMMENT ON COLUMN app_quality_review.memory_delivery_priority_applied
    IS '视频 prompt 生成时是否在脆弱对白/情绪镜头优先命中 delivery memory 锚点';

CREATE INDEX IF NOT EXISTS idx_quality_review_delivery_priority
    ON app_quality_review(memory_delivery_priority_applied)
    WHERE memory_delivery_priority_applied IS TRUE;
