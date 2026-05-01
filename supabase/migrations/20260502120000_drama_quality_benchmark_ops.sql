-- 短剧质量基线与实验运营闭环：数据库迁移
-- 涵盖：基线样本池、实验运行与变体快照、人工复核队列、观察资产治理、放行决策

-- ============================================================
-- 1. app_benchmark_case：基线样本池
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_benchmark_case (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id),
    project_id INTEGER NOT NULL,
    script_id INTEGER,
    stage TEXT NOT NULL
        CHECK (stage IN (
            'story_skeleton',
            'adaptation_strategy',
            'director_planning',
            'storyboard_table',
            'storyboard_panel',
            'video_prompt'
        )),
    case_type TEXT NOT NULL
        CHECK (case_type IN ('golden', 'bad_case', 'regression_guard')),
    issue_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    weight INTEGER NOT NULL DEFAULT 1,
    source_kind TEXT NOT NULL,
    source_ref TEXT,
    summary TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_verified_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_benchmark_case_owner_project
    ON public.app_benchmark_case (owner_user_id, project_id);

CREATE INDEX IF NOT EXISTS idx_app_benchmark_case_type_stage
    ON public.app_benchmark_case (case_type, stage);

CREATE INDEX IF NOT EXISTS idx_app_benchmark_case_weight
    ON public.app_benchmark_case (weight DESC);

COMMENT ON TABLE public.app_benchmark_case IS
    '基线样本池：golden=优质样本, bad_case=坏例样本, regression_guard=回归守卫样本';
COMMENT ON COLUMN public.app_benchmark_case.case_type IS
    '样本类型：golden=代表高质量目标, bad_case=真实失败样本, regression_guard=高敏感守卫样本';
COMMENT ON COLUMN public.app_benchmark_case.issue_tags IS
    '问题标签数组，如 ["人物一致性", "情绪递进", "镜头连续性"]';
COMMENT ON COLUMN public.app_benchmark_case.weight IS
    '样本权重，用于放行门判断，高权重样本退化会阻断放行';
COMMENT ON COLUMN public.app_benchmark_case.source_kind IS
    '样本来源：quality_review=质量评审, job_failure=任务失败, patch_attribution=返工归因, manual=人工添加';
COMMENT ON COLUMN public.app_benchmark_case.source_ref IS
    '来源引用，如 quality_review_id 或 job_id';

ALTER TABLE public.app_benchmark_case ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_benchmark_case_owner ON public.app_benchmark_case
    FOR ALL TO authenticated
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ============================================================
-- 2. app_experiment_run：实验运行记录
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_experiment_run (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id),
    name TEXT NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('draft', 'queued', 'running', 'completed', 'failed', 'cancelled')),
    sample_tier TEXT NOT NULL
        CHECK (sample_tier IN ('smoke', 'core', 'full')),
    stage_scope JSONB NOT NULL DEFAULT '[]'::jsonb,
    baseline_variant_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_experiment_run_owner_status
    ON public.app_experiment_run (owner_user_id, status);

CREATE INDEX IF NOT EXISTS idx_app_experiment_run_created
    ON public.app_experiment_run (created_at DESC);

COMMENT ON TABLE public.app_experiment_run IS
    '实验运行记录：对一组样本按不同配置执行的对比实验';
COMMENT ON COLUMN public.app_experiment_run.sample_tier IS
    '样本分层：smoke=快速验证, core=核心样本集, full=完整样本集';
COMMENT ON COLUMN public.app_experiment_run.stage_scope IS
    '阶段范围数组，如 ["storyboard_table", "storyboard_panel", "video_prompt"]';
COMMENT ON COLUMN public.app_experiment_run.baseline_variant_id IS
    '基线变体 ID，作为所有比较的参照物';

ALTER TABLE public.app_experiment_run ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_experiment_run_owner ON public.app_experiment_run
    FOR ALL TO authenticated
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ============================================================
-- 3. app_experiment_variant：实验变体快照
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_experiment_variant (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_run_id UUID NOT NULL REFERENCES public.app_experiment_run(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    is_baseline BOOLEAN NOT NULL DEFAULT FALSE,
    skill_snapshot JSONB NOT NULL,
    prompt_snapshot JSONB NOT NULL,
    memory_budget_snapshot JSONB NOT NULL,
    observation_policy_snapshot JSONB NOT NULL,
    model_route_snapshot JSONB NOT NULL,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_app_experiment_variant_run
    ON public.app_experiment_variant (experiment_run_id);

CREATE INDEX IF NOT EXISTS idx_app_experiment_variant_baseline
    ON public.app_experiment_variant (experiment_run_id, is_baseline);

COMMENT ON TABLE public.app_experiment_variant IS
    '实验变体快照：固化技能版本、提示词、记忆预算、观察治理策略、模型路由配置';
COMMENT ON COLUMN public.app_experiment_variant.skill_snapshot IS
    '技能版本快照 JSON，包含文件路径和 hash';
COMMENT ON COLUMN public.app_experiment_variant.prompt_snapshot IS
    '提示词模板快照 JSON，包含模板内容和版本';
COMMENT ON COLUMN public.app_experiment_variant.memory_budget_snapshot IS
    '记忆预算档快照 JSON，包含 lean/expanded 策略、压缩规则、保留桶等';
COMMENT ON COLUMN public.app_experiment_variant.observation_policy_snapshot IS
    '观察治理策略快照 JSON，包含负向约束、观察笔记上限等';
COMMENT ON COLUMN public.app_experiment_variant.model_route_snapshot IS
    '模型路由配置快照 JSON，包含模型选择、参数等';

ALTER TABLE public.app_experiment_variant ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_experiment_variant_owner ON public.app_experiment_variant
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_experiment_run
            WHERE id = app_experiment_variant.experiment_run_id
            AND owner_user_id = auth.uid()
        )
    );

-- ============================================================
-- 4. app_experiment_result：实验结果
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_experiment_result (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_run_id UUID NOT NULL REFERENCES public.app_experiment_run(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES public.app_experiment_variant(id) ON DELETE CASCADE,
    benchmark_case_id UUID NOT NULL REFERENCES public.app_benchmark_case(id) ON DELETE CASCADE,
    status TEXT NOT NULL
        CHECK (status IN ('queued', 'running', 'completed', 'failed', 'skipped')),
    score_summary JSONB,
    roi_summary JSONB,
    quality_review_id UUID,
    llm_usage_refs JSONB NOT NULL DEFAULT '[]'::jsonb,
    requires_human_review BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_experiment_result_run
    ON public.app_experiment_result (experiment_run_id);

CREATE INDEX IF NOT EXISTS idx_app_experiment_result_variant
    ON public.app_experiment_result (variant_id);

CREATE INDEX IF NOT EXISTS idx_app_experiment_result_case
    ON public.app_experiment_result (benchmark_case_id);

CREATE INDEX IF NOT EXISTS idx_app_experiment_result_review
    ON public.app_experiment_result (requires_human_review)
    WHERE requires_human_review = TRUE;

COMMENT ON TABLE public.app_experiment_result IS
    '实验结果：链接实验、变体、样本与评分、ROI 数据';
COMMENT ON COLUMN public.app_experiment_result.score_summary IS
    '评分摘要 JSON，包含各维度分值、问题等级、置信度';
COMMENT ON COLUMN public.app_experiment_result.roi_summary IS
    'ROI 摘要 JSON，包含 token 消耗、质量提升、成本收益比';
COMMENT ON COLUMN public.app_experiment_result.llm_usage_refs IS
    'LLM 使用记录引用数组，指向 app_llm_usage_log';
COMMENT ON COLUMN public.app_experiment_result.requires_human_review IS
    '是否需要人工复核：自动评测置信不足时标记为 true';

ALTER TABLE public.app_experiment_result ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_experiment_result_owner ON public.app_experiment_result
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_experiment_run
            WHERE id = app_experiment_result.experiment_run_id
            AND owner_user_id = auth.uid()
        )
    );

-- ============================================================
-- 5. app_review_queue：人工复核队列
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_review_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id),
    experiment_run_id UUID REFERENCES public.app_experiment_run(id) ON DELETE CASCADE,
    experiment_result_id UUID REFERENCES public.app_experiment_result(id) ON DELETE CASCADE,
    review_type TEXT NOT NULL
        CHECK (review_type IN ('quality', 'roi')),
    status TEXT NOT NULL
        CHECK (status IN ('pending', 'submitted', 'skipped')),
    priority INTEGER NOT NULL DEFAULT 0,
    prompt TEXT NOT NULL,
    rubric_snapshot JSONB NOT NULL,
    submitted_score JSONB,
    submitted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_review_queue_owner_status
    ON public.app_review_queue (owner_user_id, status, priority DESC);

CREATE INDEX IF NOT EXISTS idx_app_review_queue_experiment
    ON public.app_review_queue (experiment_run_id);

CREATE INDEX IF NOT EXISTS idx_app_review_queue_result
    ON public.app_review_queue (experiment_result_id);

COMMENT ON TABLE public.app_review_queue IS
    '人工复核队列：供运营或创作者对高风险、低置信样本进行二次判断';
COMMENT ON COLUMN public.app_review_queue.review_type IS
    '复核类型：quality=内容质量复核, roi=成本收益复核';
COMMENT ON COLUMN public.app_review_queue.priority IS
    '优先级：数值越大越优先，用于排序';
COMMENT ON COLUMN public.app_review_queue.prompt IS
    '待回答问题或复核指引';
COMMENT ON COLUMN public.app_review_queue.rubric_snapshot IS
    '评测量表快照 JSON，与自动评测共用同一问题类型字典';
COMMENT ON COLUMN public.app_review_queue.submitted_score IS
    '提交的评分 JSON，包含结构化评分、问题标签、建议动作';

ALTER TABLE public.app_review_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_review_queue_owner ON public.app_review_queue
    FOR ALL TO authenticated
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ============================================================
-- 6. app_observation_asset：观察资产治理
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_observation_asset (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id),
    project_id INTEGER,
    scope_kind TEXT NOT NULL,
    issue_type TEXT NOT NULL,
    source_kind TEXT NOT NULL,
    source_ref TEXT,
    signal_strength INTEGER NOT NULL DEFAULT 1,
    hit_count INTEGER NOT NULL DEFAULT 0,
    falsified_count INTEGER NOT NULL DEFAULT 0,
    status TEXT NOT NULL
        CHECK (status IN ('candidate', 'active', 'archived', 'rejected')),
    normalized_note TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_hit_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_app_observation_asset_owner_status
    ON public.app_observation_asset (owner_user_id, status);

CREATE INDEX IF NOT EXISTS idx_app_observation_asset_project
    ON public.app_observation_asset (project_id, status);

CREATE INDEX IF NOT EXISTS idx_app_observation_asset_issue
    ON public.app_observation_asset (issue_type, status);

CREATE INDEX IF NOT EXISTS idx_app_observation_asset_signal
    ON public.app_observation_asset (signal_strength DESC, hit_count DESC);

COMMENT ON TABLE public.app_observation_asset IS
    '观察资产治理：从评审、返工、失败任务、人工复核中沉淀的结构化观察项';
COMMENT ON COLUMN public.app_observation_asset.scope_kind IS
    '作用范围：global=全局, project=项目级, style_pack=风格包级';
COMMENT ON COLUMN public.app_observation_asset.issue_type IS
    '问题类型：人物一致性、情绪表达、镜头真实感、AI 痕迹等';
COMMENT ON COLUMN public.app_observation_asset.source_kind IS
    '来源：quality_review=质量评审, job_failure=任务失败, patch_attribution=返工归因, human_review=人工复核, experiment=实验对比';
COMMENT ON COLUMN public.app_observation_asset.signal_strength IS
    '信号强度：1-10，表示该观察项的重要性和可信度';
COMMENT ON COLUMN public.app_observation_asset.hit_count IS
    '命中计数：该观察项在后续样本中被命中的次数';
COMMENT ON COLUMN public.app_observation_asset.falsified_count IS
    '证伪计数：该观察项被证明无效或误判的次数';
COMMENT ON COLUMN public.app_observation_asset.status IS
    '状态：candidate=候选, active=生效中, archived=已归档, rejected=已拒绝';
COMMENT ON COLUMN public.app_observation_asset.normalized_note IS
    '规范化观察笔记：去重、冲突检测后的标准化描述';

ALTER TABLE public.app_observation_asset ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_observation_asset_owner ON public.app_observation_asset
    FOR ALL TO authenticated
    USING (owner_user_id = auth.uid())
    WITH CHECK (owner_user_id = auth.uid());

-- ============================================================
-- 7. app_promotion_gate_decision：放行门决策
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_promotion_gate_decision (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_run_id UUID NOT NULL REFERENCES public.app_experiment_run(id) ON DELETE CASCADE,
    variant_id UUID NOT NULL REFERENCES public.app_experiment_variant(id) ON DELETE CASCADE,
    decision TEXT NOT NULL
        CHECK (decision IN ('blocked', 'needs_review', 'approved', 'approved_limited')),
    rationale JSONB NOT NULL,
    decided_by UUID REFERENCES auth.users(id),
    decided_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_promotion_gate_experiment
    ON public.app_promotion_gate_decision (experiment_run_id);

CREATE INDEX IF NOT EXISTS idx_app_promotion_gate_variant
    ON public.app_promotion_gate_decision (variant_id);

CREATE INDEX IF NOT EXISTS idx_app_promotion_gate_decision
    ON public.app_promotion_gate_decision (decision);

COMMENT ON TABLE public.app_promotion_gate_decision IS
    '放行门决策：决定某个变更是否可以推广到更多项目';
COMMENT ON COLUMN public.app_promotion_gate_decision.decision IS
    '决策：blocked=阻断, needs_review=需要复核, approved=批准, approved_limited=有限批准（仅限高价值项目）';
COMMENT ON COLUMN public.app_promotion_gate_decision.rationale IS
    '决策理由 JSON，包含基线样本通过情况、bad case 复发、质量变化、token 变化、人工复核结论';
COMMENT ON COLUMN public.app_promotion_gate_decision.decided_by IS
    '决策人：系统自动决策时为 NULL，人工决策时记录用户 ID';

ALTER TABLE public.app_promotion_gate_decision ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_promotion_gate_decision_owner ON public.app_promotion_gate_decision
    FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.app_experiment_run
            WHERE id = app_promotion_gate_decision.experiment_run_id
            AND owner_user_id = auth.uid()
        )
    );

-- ============================================================
-- 8. 外键约束补充
-- ============================================================

-- 为 app_experiment_run.baseline_variant_id 添加外键约束
-- 注意：这个约束需要在 app_experiment_variant 表创建后添加
ALTER TABLE public.app_experiment_run
    ADD CONSTRAINT fk_experiment_run_baseline_variant
    FOREIGN KEY (baseline_variant_id)
    REFERENCES public.app_experiment_variant(id)
    ON DELETE SET NULL;
