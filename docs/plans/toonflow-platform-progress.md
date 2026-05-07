# Toonflow 平台执行进度

更新时间：2026-05-07

这个文件用于记录“平台实施落地计划（竖切执行版）”的实际落地进度。  
大路线图仍以 [`docs/plans/harness-rust-flutter.md`](./harness-rust-flutter.md) 为总蓝图；这里单独记录当前做到了哪一条、下一条是什么、还有哪些阻塞。

## 状态约定

- `completed`：已实现、已验证、已提交
- `in_progress`：当前正在实现
- `pending`：尚未开始
- `blocked`：有明确阻塞，需先清理依赖项

## 当前总览

- 当前阶段：`Phase 1 — 平台底座与最小主链`
- 当前执行策略：按“前后端一并落地”的竖切推进
- 当前验证策略：阶段内只跑定向验证；所有计划任务完成后统一执行一次 `yarn refactor:check`
- 当前最新完成 commit：`9b675231`
- 当前最新完成竖切：`资产与生产竖切 production readiness/gap 摘要增量`

## Phase 1 进度

### 1. Workspace 基础竖切

状态：`completed`

已完成：

- personal workspace 自动创建
- `workspace/project` 基础作用域落库
- `GET /api/v1/me` 返回当前 workspace
- 项目创建/读取带 `workspace_id`
- 前端显示 workspace / project 上下文栏

已提交：

- `9335f826` — personal workspace foundation + current workspace/project context

已验证：

- `cargo test me_ok_without_pool_with_jwt`
- `flutter test test/workspace_context_view_test.dart`
- 触达文件 `flutter analyze` 通过

备注：

- `yarn refactor:check` 已执行
- backend 通过
- frontend 全量仍被仓库既有 `short_video_space/*` analyzer 告警卡住，不是该竖切新增问题

### 2. 项目立项 + 项目首页竖切

状态：`completed`

已完成：

- `app_project.project_brief` / `app_project.brand_bible` 落库
- `GET /api/v1/projects/{project_id}/home` 项目首页读模型
- `readiness score` / onboarding / `style_bible_ready` 基础版
- 项目创建弹窗补 `project_brief` / `brand_bible`
- 现有项目详情入口补“项目首页驾驶舱”卡片与保存回写
- 顺带修复 `ProjectRow` 查询列不完整导致的潜在运行时映射错误

已提交：

- `b6e26d63` — complete project-home slice on existing project detail surfaces

已验证：

- `cargo test brief_ready_requires_three_meaningful_fields --lib`
- `cargo test parse_json_object_patch --lib`
- `flutter test test/projects_section_test.dart`
- 触达文件 `flutter analyze` 通过

备注：

- `yarn refactor:check` 已执行
- OpenAPI drift / rust_api consistency 通过
- 当前卡在工作区既有脏改动触发的 `cargo fmt --check` 差异：
  - `backend/src/publish/nine_platform_acceptance_tests/mod.rs`
  - `backend/src/publish/nine_platform_acceptance_tests/tests/metrics.rs`
  - `backend/src/publish/nine_platform_acceptance_tests/tests/registry.rs`
- 这些差异不属于本竖切新增代码

### 3. 内容接入竖切（主路径）

状态：`in_progress`

当前增量：

- 章节工作台新增“整本导入”入口
- 前端支持整本正文本地预解析（按章节标题自动切章）
- 支持预解析预览与按批次写入既有章节 API
- 前端支持 `crawler_client` 首版：按 URL 抓网页、抽标题与正文、回填到整本导入区
- 为后续 `manual` / `whole-book import` / `crawler_client` 共用落库契约做统一入口
- 后端 `novels` create/get/list/patch 契约补齐 `intake_source` / `intake_source_url` / `intake_status` / `intake_note`
- 前端手动录入、整本导入、`crawler_client` 三条入口统一写入 intake source/status
- 章节编辑区支持查看和更新准入状态、来源 URL、准入备注
- 工作台摘要增加 admitted/pending/rejected/crawler 统计
- 列表接口支持按 `intake_status` / `intake_source` 过滤
- 工作台搜索区支持准入状态 / 来源筛选与一键清空筛选
- 工作台支持批量更新章节准入状态与准入备注，便于处理 pending/rejected 队列
- 整本导入预解析结果支持逐条修正：改标题、改正文、删除误切章节、补充漏切章节
- 导入前会自动重排章节序号，并拦截空正文章节，避免错误批量入库
- 整本导入支持显式指定导入后的 `intake_status` 与共享 `intake_note`，方便先入 `pending_review` 再批量准入

本轮定向验证：

- `flutter test test/novel_import_parser_test.dart`
- `cargo test narrative::novels --lib`
- `flutter test test/novel_workbench_support_test.dart`
- 触达文件 `flutter analyze` 通过
- 本轮额外确认：`yarn refactor:check` 已全绿；后续默认保留到整批任务完成后再统一执行

已提交：

- `76232801` — add whole-book intake preview + batch import on top of the existing chapter API
- `c986cabf` — add crawler extraction regression coverage on the shared import path
- `7a7bb497` — preserve explicit nulls in intake PATCH bodies for admission editing
- `91170746` — unify intake source/admission metadata on the shared novel rail
- `2cb8fd5e` — add intake filtering and batch admission actions on the shared workbench
- `2aa14b75` — add editable import correction plus explicit import admission targeting

### 4. 改写与上游结构竖切

状态：`in_progress`

当前增量：

- 项目剧本区新增“骨架工作台”入口
- 前端可读取并编辑 `storySkeleton` / `adaptationStrategy`
- 前端兼容 `script-agent/get-plan-data` 当前两种返回结构，避免首次读取和已有计划读取形状不一致
- 保存走既有 `script-agent/set-plan-data` 契约，项目内可直接维护上游结构页
- 骨架工作台联动当前小说章节 / 事件数据，展示事件覆盖摘要
- 可用现有事件和章节生成“故事骨架草稿 / 改编策略草稿”，先用确定性模板压缩后续 AI 改写输入
- 可用现有事件 / 章节 / 骨架 / 策略生成“剧本初稿包”，先走确定性模板减少无效 token 消耗
- 骨架工作台新增剧本初稿预览与一键写入，复用既有 `script-agent/set-plan-data` 将同名剧本覆盖更新、缺失剧本自动创建
- script workspace 默认先消费 `planData.script` 里的计划剧本草稿，再按需补事件或章节窗口，避免上来整包回读小说正文
- 骨架工作台新增“结构化改写 guidance”生成与预览，把章节压缩、事件改写、人物情绪推进与去 AI 味约束整理成可执行 guidance，供后续 script 子代理或人工改稿消费
- script workspace 的“上下文快照 / 结果摘要”现在会把 `get_planData` 派生为“改写约束”卡，明确下游先消费计划剧本草稿、再补最少事件与章节正文，避免 guidance 只停留在计划侧
- production workspace 在读取 `scriptPlan` 时，会额外展示“改写约束下沉”卡，并在 flow 摘要中标记“已承接改写约束”，让导演计划、后续分镜与素材核对明确继承上游改写意图
- production workspace 在读取 `scriptPlan` 后，recipe 会新增“继续导演计划”动作，并自动继承 scriptPlan 已点名的关键资产范围，让后续导演计划、分镜和素材动作优先围绕改写约束收束，而不是重新扩读整包上下文
- production workspace 的资产补图与分镜补帧 prompt 现在会继承 scriptPlan 提炼出的短版执行提示，把情绪递进、画面意图和去生硬约束压缩进动作提示，在不扩读大上下文的前提下提升画面与表演自然度
- production workspace 的阶段卡与建议卡现在会直接展示本次子代理将使用的执行提示，用户无需先点应用再检查，即可判断本轮动作是否仍遵守改写约束、情绪递进和最小上下文读取策略

本轮定向验证：

- `flutter test test/script_agent_plan_data_test.dart test/project_script_plan_workbench_view_test.dart test/project_script_plan_workbench_support_test.dart`
- `flutter test test/script_workspace_support_test.dart`
- `flutter test test/project_script_plan_workbench_support_test.dart test/project_script_plan_workbench_view_test.dart test/script_agent_plan_data_test.dart`
- `flutter test test/script_workspace_support_test.dart`
- `flutter test test/agent_workspaces_section_test.dart --plain-name "Script pane renders planData and tool context snapshots"`
- `flutter test test/production_context_snapshot_test.dart test/production_workspace_support_test.dart`
- 触达文件 `flutter analyze` 通过

已提交：

- `e863fe13` — add project-level plan workbench for story skeleton and adaptation strategy
- `77b545b7` — seed skeleton and strategy drafts from current novel events before spending model tokens
- `0070f3ef` — bridge deterministic script draft packets into preview and writeback on top of the existing script-agent plan rail
- `79272d92` — teach script workspaces to prefer planData draft packets before wider chapter reads
- `72166473` — add structured rewrite guidance generation and preview on top of the plan workbench
- `c0e6acb2` — surface plan-derived rewrite constraints inside the script workspace snapshot and result summary
- `ec304994` — surface rewrite-constraint landing inside production scriptPlan snapshots and summaries
- `c90ce32a` — prioritize rewrite-constrained director-plan follow-ups in production recipes
- `5e5f6ea2` — distill scriptPlan rewrite intent into production asset/storyboard execution hints
- `4b253161` — surface production execution prompts inline on stage and recipe cards

### 5. 资产与生产竖切

状态：`in_progress`

当前增量：

- production workspace 的 flow 摘要与阶段文案现在会显式给出 readiness / gap 信息，而不只显示“是否有数据”
- assets flow 会显示主资产已就绪数、主资产待补数、衍生缺口数，便于判断当前是否真能推进出图
- storyboard flow 会显示画面结果已就绪数、待补帧数、纯文本镜头数，避免误把纯文本镜头当成缺帧
- storyboardTable flow 会显示已读取行数 / 总行数 / 待展开行数，便于决定是否继续抽样还是进入修订
- 这些 readiness / gap 摘要同时下沉到 production stage detail 与结果摘要中，帮助用户在最少点击下判断当前阻塞点

本轮定向验证：

- `flutter test test/production_workspace_support_test.dart`
- 触达文件 `flutter analyze` 通过

已提交：

- `9b675231` — turn production flow snapshots into explicit readiness and gap summaries

### 6. 质量与发布最小闭环竖切

状态：`pending`

## 当前阻塞与注意事项

### 已知非本轮新增阻塞

- frontend 全量 `flutter analyze` 仍有既存告警：
  - `frontend/lib/short_video_space/section_production.dart`
  - `frontend/lib/short_video_space/section_production_assembly.dart`
  - `frontend/lib/short_video_space/section_project.dart`
  - `frontend/lib/short_video_space/section_publish*.dart`

这些问题会影响 `yarn refactor:check` 最终全绿，但不是 workspace 竖切引入。

### 合约测试环境注意

- 需要 `DATABASE_URL`
- 需要 `SUPABASE_JWT_SECRET`

没有这两个环境变量时，需 PG 的 `#[ignore]` 合约测试无法本地完整验证。

## 更新规则

后续每完成一个“可提交竖切增量”，这里都要同步更新：

1. 当前阶段
2. 当前竖切状态
3. 已完成内容
4. 定向验证结果
5. 对应 commit
6. 下一条要做的竖切
