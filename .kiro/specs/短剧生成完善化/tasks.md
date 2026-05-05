# 短剧生成完善化 tasks

基线原则：

- 先补功能闭环，再压 token。
- 质量优先于成本。
- 每次只测当前改动范围。
- 每轮结束后都再 review 一次是否还有更高收益优化点。

## Phase A - Workflow Gap Review

- [x] 盘点当前"生成 -> review -> 返工 -> 回写记忆"链路还缺哪些环节
- [x] 标注每个缺口对"人物稳定 / 情绪自然 / 穿帮率 / token 成本"的影响
- [x] 选出第一个最高 ROI 竖切，不等候额外确认直接开做

## Phase B - Quality Loop Closure

- [x] 检查质量 review 结果是否能稳定回写到视频专用记忆
- [x] 检查坏例分类是否足够支撑自动负向约束
- [x] 检查连续失败镜头是否已有明确"局部返工 / 归因模式"
- [x] 若缺失，补一条最影响出片质量的闭环能力

## Phase C - Memory Governance

- [x] 梳理 agent_memory 与 video_prompt_memory 的职责边界
- [x] 明确哪些信号允许自动写入，哪些必须拒绝或淘汰
- [x] 检查项目/用户/agent/scope 隔离是否贯穿所有自动写入路径
- [x] 压缩低信号记忆，避免重复注入上下文

## Phase D - Token ROI Optimization

- [x] 盘点当前生成链路里最浪费 token 的重复上下文
- [x] 优先压缩导演手册、角色锚点、阶段历史的重复注入
- [x] 检查低风险/高风险镜头预算分流是否还可继续细化
- [x] 验证 token 压缩后是否出现质量回退

## Phase E - Missing Feature Completion

- [x] 如果现有功能已基本无缺口，再 review 是否还缺少应有能力
- [x] 收敛短剧生成主流程的操作步数
- [x] 评估是否能把生成流程压成更短的一条动作链
- [x] 优先补能直接提升短剧质量的能力
- [x] 完成后再次 review 是否继续深挖或切换方向

## Phase F - Highest Priority Dubbing Parity

- [x] 对照 master 梳理旧仓库 TTS/Audio 能力边界
- [x] 把当前旁白文案升级成正式配音链路设计
- [x] 明确最小可交付路径：旁白文本到TTS到音频资产到成片装配
- [x] 优先补单供应商 TTS 打通
- [x] 给配音链路补状态可见性与失败重试
- [x] F.1 Review audio-video assembly consistency
- [x] F.2 Review voice tone and emotion control gaps

## Phase G - Production Gap Review

- [x] 基于当前实现复核发布是否真实闭环
- [x] 复核质量信号是否真正阻断高风险导出发布
- [x] 复核 short-video-space 的刷新与拉取路径是否浪费
- [x] 复核多草稿多平台自动化模式是否仍停留在 happy path
- [x] 按严重级别收敛缺口并转成可执行任务清单

## Phase H - Production Feature Closure (P0)

- [x] 将发布适配升级到可区分 sandbox/live/manual_bridge 的真实投递链路
- [x] 在 attempts/jobs 中落地 delivery_mode 和 evidence 支持审计筛选
- [x] 将表现数据同步从 mock 拉取升级为真实平台指标拉取
- [x] H.1 Refactor publish panel to require explicit draft selection
- [x] 支持多草稿批量发布定时清档重试
- [x] 自动化模式按平台能力真实生效

## Phase I - Quality Enforcement Closure (P0)

- [x] I.1 Upgrade export quality gate to off/warn/block strategy
- [x] I.2 Add quality gate validation before publish queue
- [x] I.3 Extend quality comparison to storyboard+video+output
- [x] I.4 Promote quality nextAction to typed field for rework action
- [x] I.5 Connect low-performance alert to rewrite/republish loop

## Phase J - Token and Cost ROI Closure (P0/P1)

- [x] J.1 Add input hash cache for publish copy generation
- [x] J.2 Change publish copy to incremental mode for changed platforms only
- [x] J.3 Add app_llm_usage_log for publish copy calls
- [x] J.4 Aggregate short-video-space publish requests to single endpoint
- [x] J.5 Reduce loadProjectOverview fanout and duplicate fetches
- [x] J.6 Add request deduplication and generation protection for high-frequency refresh

## Phase K - Reliability / Observability / Contract Governance

- [x] K.1 Add version conflict detection for timeline reorder save
- [x] K.2 Change shot duration alignment to minimal field patch
- [-] K.3 Standardize error messages with status/code/message/request-id
- [~] K.4 Add cross-panel snapshot versioning with inconsistency alerts
- [~] K.5 Add metrics and SLI for critical paths
- [~] K.6 Add OpenAPI drift gate and rust_api contract consistency check

## Phase L - Production Acceptance Re-Run

- [~] L.1 Redo nine-platform matrix acceptance with real capability
- [~] L.2 Execute end-to-end regression in staging environment
- [~] L.3 A/B validate token optimization without quality regression
- [~] L.4 Final review: feature/quality/token/stability/observability all pass

## Phase M - Security / Compliance / Idempotency

- [~] M.1 Add signature/timestamp/nonce validation for platform callbacks
- [~] M.2 Add idempotency keys for publish create/confirm/retry/writeback
- [~] M.3 Unify request-id across publish pipeline for full-chain tracing
- [~] M.4 Mask sensitive fields in audit details
- [~] M.5 Add stricter RBAC for platform credential access
- [~] M.6 Add rate limiting and quota protection for publish domain

## Phase N - Operability / DR / Data Lifecycle

- [~] N.1 Define and implement publish SLA and timeout alerts
- [~] N.2 Provide runbooks for critical failure scenarios
- [~] N.3 Establish publish and performance data archival strategy
- [~] N.4 Add pagination/cursor support for large project scenarios
- [~] N.5 Add gradual rollout and fast rollback switches
- [~] N.6 Add production drill day checklist

## Phase O - FinOps / Governance / Release Safety

- [~] O.1 Build cost attribution dashboard for publish and quality pipeline
- [~] O.2 Establish quality baseline set for token optimization validation
- [~] O.3 Add real vs mock metrics isolation and dashboard labels
- [~] O.4 Add callback and retry data reconciliation task
- [~] O.5 Add migration/backfill runbooks for critical schema changes
- [~] O.6 Make publish strategy config auditable
- [~] O.7 Introduce feature flag governance for production features
- [~] O.8 Add pre-launch go/no-go checklist

## Phase P - UX and Human-in-the-loop Completeness

- [~] P.1 Complete audio-video assembly consistency review and fix
- [~] P.2 Add manual bridge publish operation panel
- [~] P.3 Add operation preview and impact confirmation for multi-draft/platform ops
- [~] P.4 Add one-click recovery entry for failure states
- [~] P.5 Standardize status labels with real capability tags

## 交付节奏

- [x] 每完成一个主要阶段，提交一次小步 commit
- [x] 每轮提交前只运行本次改动对应的最小必要验证
- [x] 全部功能与质量优化阶段接近完成后，再统一执行一次全量检查
