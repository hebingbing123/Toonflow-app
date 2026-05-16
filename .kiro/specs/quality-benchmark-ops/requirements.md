# Requirements Document

## Introduction

本功能（quality-benchmark-ops）在已落地的 `app_quality_review` 表与质量 REST API 基础上，完成两个工作包：

**WP-A：人工抽检量表固化**——将评审维度（画面/叙事/对口型/节奏/人设一致性等）、阈值与「放行/打回」规则书面化，并通过 JSON schema 列扩展 `app_quality_review`，使 Flutter 评审表单与后端维度打分对齐。

**WP-B：Bad case 集版本化 + 发版前回归**——提供只读导出工具将固定 `quality_review_id` 集合导出为 fixture，并在 `.github/workflows/` 中新增定时/手动触发的 CI job，在发版前对比通过率，同时明确 golden 集更新规则与 CODEOWNER 审查要求。

**已落地基线**：`app_quality_review` 表（含 `stage`、`grade`、`skill_version_hash`、`next_action`、`suggested_action` 等字段）、REST API（创建/列表/详情/统计/分环节通过率）、`GET /api/v1/quality/dashboard` 读模型 + 物化视图、`app_benchmark_case` 表（含 `golden` / `bad_case` / `regression_guard` 三种 `case_type`）均已通过 migration 落地，本功能在此基础上扩展，不重复创建已有结构。

**技术约束**：遵循 `full-stack-delivery-covenant.md`（backend + frontend + 契约同里程碑交付）；单文件 ≤ 800 行；DB 新列保持 nullable（回滚友好）；变更后需跑 `yarn refactor:agent --full`。

**术语说明：**

- **Quality_Review_API**：Rust 后端 `/api/v1/quality/reviews*` 及相关聚合端点的统称。
- **Rubric**：人工抽检量表，包含评审维度定义、各维度评分范围、阈值与放行/打回规则，存储于 `docs/plans/quality-rubric.md`。
- **Dimension_Score**：单个评审维度的 1–10 分评分（如 `lip_sync`、`visual_consistency` 等）。
- **Dimension_Schema**：存储在 `app_quality_review.dimension_scores` 列中的 JSON 对象，键为维度名，值为 1–10 整数。
- **Pass_Threshold**：量表中定义的放行阈值，`overall_score >= 6` 且无 D 级维度分（分值 ≤ 3）时视为放行，否则视为打回。
- **Bad_Case_Fixture**：由 Export_Tool 生成的 JSON 文件，包含固定 `quality_review_id` 集合及其评审快照，用于 CI 回归对比。
- **Golden_Set**：经人工确认的高质量样本集合，存储于已落地的 `app_benchmark_case`（`case_type = 'golden'`）。
- **Regression_Guard_Set**：经人工确认的坏例守卫集合，存储于已落地的 `app_benchmark_case`（`case_type = 'regression_guard'`）。
- **Export_Tool**：`backend` 只读二进制子命令（`cargo run --bin quality-export`），将指定 `quality_review_id` 集合导出为 Bad_Case_Fixture，不修改任何数据库记录。
- **Regression_Check_Tool**：`backend` 只读二进制子命令（`cargo run --bin quality-regression-check`），读取 Bad_Case_Fixture 并与数据库当前状态对比，输出结构化退化报告。
- **CI_Regression_Job**：`.github/workflows/quality-regression.yml` 中的 GitHub Actions job，定时或手动触发，对比 Bad_Case_Fixture 与当前通过率。
- **CODEOWNER**：在 `.github/CODEOWNERS` 中指定的 golden 集更新审查人，golden 集文件变更须经其 review 后方可合并。
- **Flutter_Review_Form**：Flutter 质量工作台中的评审创建/编辑表单，需与后端 Dimension_Schema 对齐。
- **Rust_API**：`frontend/lib/rust_api/` 下的 Dart 客户端层，与 OpenAPI 契约保持一致。
- **Stage**：生成阶段，取值为 `story_skeleton` / `adaptation_strategy` / `director_planning` / `storyboard_table` / `storyboard_panel` / `video_prompt`。
- **Grade**：监督层评分等级，取值为 A / B / C / D（A=可直接使用，B=小修后可用，C=需较大修改，D=建议重做）。
- **Regression_Rate**：退化率，计算公式为：退化记录数 ÷ 有效检查记录数（不含数据库中不存在的记录）。

## Requirements

### Requirement 1：书面量表固化

**User Story:** 作为编导/运营，我希望有一份书面化的评审量表，明确各维度定义、评分范围与放行/打回规则，以便评审员按统一标准打分，减少主观漂移。

#### Acceptance Criteria

1. THE Quality_Review_API SHALL 在 `docs/plans/quality-rubric.md` 中提供书面量表，包含以下 7 个评审维度的定义与评分说明：`visual_consistency`（画面/人设一致性）、`narrative_coherence`（叙事连贯性）、`lip_sync`（对口型）、`pacing`（节奏）、`character_consistency`（人设一致性）、`dialogue_naturalness`（对白自然度）、`faithfulness`（与原著/设定符合度）。
2. THE Quality_Review_API SHALL 在量表中明确 Pass_Threshold：`overall_score >= 6` 且 `dimension_scores` 中无分值 ≤ 3 的维度时视为放行，否则视为打回。
3. THE Quality_Review_API SHALL 在量表中说明抽样批次规则：每个 Stage 每周至少抽检 5 条评审记录。
4. THE Quality_Review_API SHALL 在量表文件顶部包含版本标识，格式为 `version: YYYY-MM-DD`，以便 Flutter_Review_Form 展示当前量表版本。

---

### Requirement 2：扩展 app_quality_review 支持维度打分

**User Story:** 作为后端工程师，我希望 `app_quality_review` 表新增 `dimension_scores` JSON 列，以便存储各维度的结构化评分，并通过 API 校验其合法性。

#### Acceptance Criteria

1. THE Quality_Review_API SHALL 通过 Supabase migration 在 `app_quality_review` 表新增 `dimension_scores jsonb NULL` 列，不设置 NOT NULL 约束；IF 该列被定义为 NOT NULL，THEN THE Quality_Review_API SHALL 视为不满足本需求，以保证旧客户端写入的记录不受影响。
2. WHEN 创建或更新评审记录时，IF `dimension_scores` 字段存在且不为 null，THEN THE Quality_Review_API SHALL 校验其为合法 JSON 对象，且每个键必须是以下已定义维度名之一：`visual_consistency`、`narrative_coherence`、`lip_sync`、`pacing`、`character_consistency`、`dialogue_naturalness`、`faithfulness`。
3. WHEN 创建或更新评审记录时，IF `dimension_scores` 包含未定义的维度键，THEN THE Quality_Review_API SHALL 返回 HTTP 400，错误码 `invalid_dimension_key`，并在响应体中列出非法键名。
4. WHEN 创建或更新评审记录时，IF `dimension_scores` 中任意维度值不在 1–10 范围内（含边界），THEN THE Quality_Review_API SHALL 返回 HTTP 400，错误码 `dimension_score_out_of_range`，并在响应体中列出越界的键名与实际值。
5. THE Quality_Review_API SHALL 在 `GET /api/v1/quality/reviews/{id}` 响应中包含 `dimensionScores` 字段（camelCase），值为 `dimension_scores` 列内容或 `null`。
6. THE Quality_Review_API SHALL 在 `GET /api/v1/quality/reviews` 列表响应中包含每条记录的 `dimensionScores` 字段。
7. THE Quality_Review_API SHALL 在 OpenAPI spec 中为 `dimensionScores` 字段提供 schema 定义，包含 `additionalProperties: {type: integer, minimum: 1, maximum: 10}` 约束与各维度键名枚举说明。
8. FOR ALL 合法的 `dimension_scores` 输入，THE Quality_Review_API SHALL 保证写入后读取返回等价对象（round-trip 属性：`decode(encode(x)) == x`）。

---

### Requirement 3：Flutter 评审表单支持维度打分

**User Story:** 作为评审员，我希望在 Flutter 质量工作台的评审创建/编辑表单中，能够对各维度逐一打分，并在提交时与后端 Dimension_Schema 对齐，以便结构化记录评审结果。

#### Acceptance Criteria

1. THE Flutter_Review_Form SHALL 在评审创建表单中展示 Requirement 1 中定义的全部 7 个评审维度，每个维度提供 1–10 的评分输入控件（滑块或数字输入）。
2. WHEN 用户在 Flutter_Review_Form 中填写维度分值时，IF 分值不在 1–10 范围内，THEN THE Flutter_Review_Form SHALL 在对应控件旁显示错误提示，不发起网络请求。
3. WHEN 用户提交评审表单时，THE Flutter_Review_Form SHALL 将各维度评分组装为 `dimensionScores` JSON 对象，通过 Rust_API 的 `createQualityReview` 方法发送至后端；IF 任意已填写的维度分值校验失败，THEN THE Flutter_Review_Form SHALL 阻止提交，不发起网络请求。
4. WHEN 用户打开已有评审记录的编辑视图时，THE Flutter_Review_Form SHALL 从 `dimensionScores` 字段回填各维度评分控件。
5. WHERE 维度评分为可选项，THE Flutter_Review_Form SHALL 允许用户跳过部分维度（提交时对应键不出现在 JSON 中），不强制要求全部填写。
6. THE Rust_API SHALL 在 `CreateQualityReviewRequest` 模型中包含 `dimensionScores` 可选字段，类型为 `Map<String, int>?`，与后端 OpenAPI 契约一致。
7. THE Flutter_Review_Form SHALL 在表单顶部展示当前量表版本（从 Rubric 文件 `version` 字段读取的日期字符串），以便评审员知晓所用量表版本。

---

### Requirement 4：Bad case 导出工具

**User Story:** 作为运营/工程师，我希望有一个只读命令行工具，能将指定 `quality_review_id` 集合导出为结构化 fixture 文件，以便在 CI 中用于发版前回归对比。

#### Acceptance Criteria

1. THE Export_Tool SHALL 作为 `backend` 的独立二进制子命令（`cargo run --bin quality-export`）实现，不修改任何数据库记录。
2. WHEN 调用 `quality-export --ids <id1,id2,...> --output <path>` 时，THE Export_Tool SHALL 从数据库读取指定 `quality_review_id` 对应的评审记录，并将其序列化为 JSON 文件，写入 `<path>`。
3. THE Export_Tool SHALL 在导出的 JSON 文件中包含以下字段：`exportedAt`（ISO 8601 时间戳）、`reviewCount`（导出条数）、`schemaVersion`（当前为 `"1"`）、`reviews`（评审记录数组，每条包含 `id`、`stage`、`grade`、`passed`、`overall_score`、`dimension_scores`、`is_bad_case`、`bad_case_category`、`skill_version_hash`、`created_at`）。
4. WHEN 调用 Export_Tool 时，IF 指定的 `quality_review_id` 在数据库中不存在，THEN THE Export_Tool SHALL 在 stderr 输出警告（格式：`WARN: review <id> not found, skipped`），并继续导出其余记录，不中止执行。
5. WHEN 调用 Export_Tool 时，IF 数据库连接失败，THEN THE Export_Tool SHALL 以非零退出码退出，并在 stderr 输出错误信息。
6. THE Export_Tool SHALL 支持 `--ids-file <path>` 参数，从文件中读取换行分隔的 `quality_review_id` 列表；`--ids` 与 `--ids-file` 参数互斥，同时提供时以非零退出码退出。
7. THE Export_Tool SHALL 支持 `--stage <stage>` 过滤参数，仅导出指定 Stage 的评审记录；WHEN `--stage` 值不在合法 Stage 枚举中时，THE Export_Tool SHALL 以非零退出码退出并在 stderr 输出合法值列表。
8. FOR ALL 合法输入，THE Export_Tool SHALL 保证导出的 JSON 文件可被重新解析为等价的评审记录集合（round-trip 属性：`parse(export(reviews)) == reviews`）。

---

### Requirement 5：Bad case fixture 版本化管理

**User Story:** 作为工程师，我希望 Bad_Case_Fixture 文件受版本控制，并有明确的更新规则，以便追踪 golden 集变更历史，防止未经审查的修改进入主线。

#### Acceptance Criteria

1. THE Export_Tool SHALL 将 Bad_Case_Fixture 文件存储于 `scripts/fixtures/quality/` 目录下，文件名格式为 `<stage>_<YYYYMMDD>.json`（示例：`storyboard_panel_20260601.json`）。
2. THE Quality_Review_API SHALL 在 `.github/CODEOWNERS` 中为 `scripts/fixtures/quality/` 目录指定至少一名 CODEOWNER，该目录下任何文件的变更须经 CODEOWNER review 后方可合并。
3. THE Quality_Review_API SHALL 在 `scripts/fixtures/quality/README.md` 中说明 golden 集更新流程：（1）运行 Export_Tool 生成新 fixture；（2）提交 PR 并请求 CODEOWNER review；（3）在 PR 描述中说明新增/移除的 `quality_review_id` 及原因。
4. WHEN golden 集文件发生变更时，THE CI_Regression_Job SHALL 在 PR 检查日志中输出变更摘要（新增/移除的 id 数量），不阻断合并。
5. THE Export_Tool SHALL 在 fixture 文件中包含 `schemaVersion` 字段（当前为 `"1"`），以便未来格式升级时向后兼容。

---

### Requirement 6：CI 发版前回归 job

**User Story:** 作为工程师，我希望在 `.github/workflows/` 中有一个定时或手动触发的 CI job，在发版前自动对比 Bad_Case_Fixture 与当前通过率，以便及时发现质量退化。

#### Acceptance Criteria

1. THE CI_Regression_Job SHALL 在 `.github/workflows/quality-regression.yml` 中定义，支持 `workflow_dispatch`（手动触发）和 `schedule`（每周一次，UTC 周一 07:00）两种触发方式。
2. WHEN CI_Regression_Job 运行时，THE CI_Regression_Job SHALL 启动本地 Supabase（`supabase db start` + `supabase db reset --yes --no-seed`），应用所有 migrations，并通过 `supabase status -o env` 获取 `DATABASE_URL` 与 `SUPABASE_JWT_SECRET`。
3. WHEN CI_Regression_Job 运行时，THE CI_Regression_Job SHALL 对 `scripts/fixtures/quality/` 下每个 fixture 文件，调用 `cargo run --bin quality-regression-check -- --fixture <path>` 命令，对比 fixture 中记录的 `passed` 状态与当前数据库中对应记录的 `passed` 状态。
4. WHEN CI_Regression_Job 运行时，IF 任意 fixture 的 Regression_Rate 超过 0.10（即 10%），THEN THE CI_Regression_Job SHALL 以非零退出码退出，并在 job 日志中输出退化记录的 `id` 列表与 Regression_Rate。
5. WHEN CI_Regression_Job 运行时，IF fixture 文件中的 `quality_review_id` 在当前数据库中不存在，THEN THE CI_Regression_Job SHALL 在日志中输出警告（格式：`WARN: review <id> not found in DB, skipped`），不将该记录计入 Regression_Rate 计算。
6. THE CI_Regression_Job SHALL 在 job 结束时输出摘要报告，包含：检查的 fixture 文件数、总记录数、退化记录数、Regression_Rate（百分比，保留两位小数）。
7. THE CI_Regression_Job SHALL 使用 `concurrency` 配置防止同一分支的并发运行（`cancel-in-progress: true`）。
8. THE CI_Regression_Job SHALL 在 `permissions` 中仅声明 `contents: read`，不申请写权限。
9. THE CI_Regression_Job SHALL 在 workflow 文件注释中说明暂停定时触发的方式（将 `schedule` 触发器注释掉），以便在紧急情况下快速禁用。

---

### Requirement 7：回归检查子命令

**User Story:** 作为工程师，我希望有一个 `quality-regression-check` 二进制子命令，能读取 fixture 文件并与数据库当前状态对比，输出结构化的退化报告，以便 CI job 调用。

#### Acceptance Criteria

1. THE Regression_Check_Tool SHALL 提供 `cargo run --bin quality-regression-check -- --fixture <path>` 子命令，读取指定 fixture 文件并连接数据库（通过 `DATABASE_URL` 环境变量）。
2. WHEN 运行回归检查时，THE Regression_Check_Tool SHALL 对 fixture 中每条记录，查询数据库中对应 `quality_review_id` 的当前 `passed` 值，并与 fixture 中记录的 `passed` 值对比。
3. THE Regression_Check_Tool SHALL 将对比结果以 JSON 格式输出到 stdout，包含：`fixtureFile`、`totalChecked`、`regressionCount`、`regressionRate`（0.0–1.0 浮点数）、`regressions`（退化记录数组，每条含 `id`、`fixturePassed`、`currentPassed`）。
4. WHEN 回归检查完成时，IF `regressionRate > 0.1`，THEN THE Regression_Check_Tool SHALL 以退出码 `1` 退出；WHILE `regressionRate <= 0.1`，THE Regression_Check_Tool SHALL 以退出码 `0` 退出。
5. WHEN 运行回归检查时，IF fixture 文件格式不合法（JSON 解析失败或缺少 `schemaVersion`、`reviews` 必要字段），THEN THE Regression_Check_Tool SHALL 立即以退出码 `2` 退出，不执行任何回归检查，不产生 stdout 输出，并在 stderr 输出具体错误字段名。
6. FOR ALL 合法 fixture 输入，THE Regression_Check_Tool SHALL 保证输出的 JSON 报告可被重新解析（round-trip 属性：`parse(report_json)` 等价于原始报告对象）。
7. FOR ALL 合法 fixture 输入，THE Regression_Check_Tool SHALL 保证 `regressionRate == regressionCount / totalChecked`（metamorphic 属性：退化率与计数一致）。

---

### Requirement 8：Flutter 质量工作台展示维度评分

**User Story:** 作为运营/编导，我希望在 Flutter 质量工作台的评审详情视图中，能看到各维度的评分分布，以便快速定位质量问题所在维度。

#### Acceptance Criteria

1. THE Flutter_Review_Form SHALL 在评审详情视图中展示 `dimensionScores` 中各维度的评分，以维度名（中文标签）和分值（1–10）的形式呈现。
2. WHILE `dimensionScores` 为 null 或空对象，THE Flutter_Review_Form SHALL 在详情视图中显示「暂无维度评分」占位文本，不抛出运行时异常。
3. THE Flutter_Review_Form SHALL 在评审列表视图中，对 `dimensionScores` 中存在分值 ≤ 3 的维度的记录，以红色标签视觉标记突出显示，以便快速识别高风险评审。
4. THE Rust_API SHALL 在 `QualityReview` 模型中包含 `dimensionScores` 字段，类型为 `Map<String, int>?`，与后端 OpenAPI 契约一致。

---

### Requirement 9：全栈契约一致性

**User Story:** 作为工程师，我希望所有新增 API 字段与端点均在 OpenAPI spec 中有对应定义，且 Flutter `rust_api` 层与后端契约保持一致，以便 CI 门禁能自动检测漂移。

#### Acceptance Criteria

1. THE Quality_Review_API SHALL 在 OpenAPI spec 中为 `dimension_scores` 字段提供完整的 schema 定义，包含 `additionalProperties: {type: integer, minimum: 1, maximum: 10}` 约束。
2. THE Quality_Review_API SHALL 在 OpenAPI spec 的 `components/schemas` 中为 Bad_Case_Fixture JSON 格式提供独立 schema 定义（`BadCaseFixture`），包含 `exportedAt`、`reviewCount`、`schemaVersion`、`reviews` 字段。
3. WHEN 运行 `yarn refactor:agent --full` 时，THE Quality_Review_API SHALL 通过 OpenAPI drift 检查与 `rust_api` 一致性检查，无漂移错误。
4. THE Quality_Review_API SHALL 在 `cargo test` 中包含针对 `dimension_scores` 校验逻辑的单元测试，覆盖以下 3 种场景：合法输入（所有维度键合法且值在 1–10 内）、非法键名（包含未定义维度键）、越界分值（值为 0 或 11）。
5. THE Flutter_Review_Form SHALL 在 `flutter test` 中包含针对维度评分表单校验逻辑的 widget 测试，覆盖以下 2 种场景：合法输入（分值 1 和 10）、越界输入（分值 0 和 11）。

---

### Requirement 10：回滚安全性

**User Story:** 作为工程师，我希望所有 DB 变更均保持回滚友好，以便在出现问题时能安全回退，不影响现有数据。

#### Acceptance Criteria

1. THE Quality_Review_API SHALL 在 migration 中将 `dimension_scores` 列定义为 `jsonb NULL`，不设置 NOT NULL 约束，以保证旧客户端写入的记录不受影响。
2. IF `dimension_scores` 列被回滚删除，THEN THE Quality_Review_API SHALL 保证现有 `app_quality_review` 记录的其他字段不受影响。
3. THE Quality_Review_API SHALL 在 migration 文件中添加注释，说明该列的回滚方式（`ALTER TABLE app_quality_review DROP COLUMN IF EXISTS dimension_scores`）。
4. THE CI_Regression_Job SHALL 在 workflow 文件中添加注释，说明暂停 job 的方式（将 `schedule` 触发器注释掉），以便在紧急情况下快速禁用定时触发，保持 `workflow_dispatch` 可用。
