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
- 当前最新完成 commit：`2cb8fd5e`
- 当前最新完成竖切：`内容接入竖切（主路径）准入筛选与批量处理增量`

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

### 4. 改写与上游结构竖切

状态：`pending`

### 5. 资产与生产竖切

状态：`pending`

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
