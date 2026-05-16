-- 质量评估表：人工抽检与自动评分
-- 与 Harness trace 挂钩：通过 job_id 关联到 app_generation_job

CREATE TABLE app_quality_review (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    -- 关联信息
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id integer, -- 可选关联项目
    script_id integer, -- 可选关联剧本
    job_id uuid REFERENCES app_generation_job(id), -- Harness 任务追溯

    -- 评估对象类型：storyboard / script / video / asset 等
    target_type text NOT NULL CHECK (target_type IN (
        'storyboard', 'script', 'video', 'asset', 'output'
    )),
    target_id text, -- 被评估对象的标识

    -- 评估来源：人工 manual / 自动 auto
    source text NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'auto')),

    -- 评分维度（1-10 分，null 表示未评）
    plot_coherence smallint CHECK (plot_coherence BETWEEN 1 AND 10), -- 剧情连贯
    character_consistency smallint CHECK (character_consistency BETWEEN 1 AND 10), -- 人设一致
    dialogue_naturalness smallint CHECK (dialogue_naturalness BETWEEN 1 AND 10), -- 对白自然
    pacing smallint CHECK (pacing BETWEEN 1 AND 10), -- 节奏
    faithfulness smallint CHECK (faithfulness BETWEEN 1 AND 10), -- 与原著/设定符合度
    visual_quality smallint CHECK (visual_quality BETWEEN 1 AND 10), -- 画面质量（可选）

    -- 总分（加权平均，自动计算或手动给出）
    overall_score smallint CHECK (overall_score BETWEEN 1 AND 10),

    -- 是否通过（阈值判断）
    passed boolean,

    -- 评估备注
    comments text,

    -- 技能版本追溯（与 Harness 对齐）
    skill_version text,
    model_name text,
    model_params jsonb,

    -- 评估者标识（人工抽检时记录）
    reviewer_id uuid REFERENCES auth.users(id),

    -- 标记为 bad case
    is_bad_case boolean NOT NULL DEFAULT false,
    bad_case_category text CHECK (bad_case_category IN (
        'plot_hole',          -- 剧情跑题/漏洞
        'character_break',    -- 人设崩塌
        'storyboard_mismatch', -- 分镜衔接错误
        'dialogue_issue',     -- 对白问题
        'visual_error',       -- 画面错误
        'pacing_issue',       -- 节奏问题
        'other'               -- 其他
    ))
);

COMMENT ON TABLE app_quality_review IS '短剧生成质量评估表：人工抽检与自动评分';

-- 索引
CREATE INDEX idx_quality_review_user_id ON app_quality_review(user_id);
CREATE INDEX idx_quality_review_job_id ON app_quality_review(job_id);
CREATE INDEX idx_quality_review_target ON app_quality_review(target_type, target_id);
CREATE INDEX idx_quality_review_bad_case ON app_quality_review(is_bad_case) WHERE is_bad_case = true;
CREATE INDEX idx_quality_review_created_at ON app_quality_review(created_at DESC);

-- RLS 策略（先关闭，应用层控制）
ALTER TABLE app_quality_review ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own reviews"
    ON app_quality_review FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can create own reviews"
    ON app_quality_review FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update own reviews"
    ON app_quality_review FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid());

-- 更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_quality_review_updated_at
    BEFORE UPDATE ON app_quality_review
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 分环节通过率统计视图（按 target_type + 日期聚合）
CREATE VIEW quality_pass_rate_by_stage AS
SELECT
    target_type,
    date_trunc('day', created_at) as review_date,
    count(*) as total_reviews,
    count(*) FILTER (WHERE passed = true) as passed_count,
    count(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
    round(count(*) FILTER (WHERE passed = true) * 100.0 / nullif(count(*), 0), 2) as pass_rate_percent,
    avg(overall_score) as avg_score
FROM app_quality_review
GROUP BY target_type, date_trunc('day', created_at);
