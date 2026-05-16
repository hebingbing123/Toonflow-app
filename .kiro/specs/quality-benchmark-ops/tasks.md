# Implementation Plan: quality-benchmark-ops

## Overview

本实现计划分两个工作包交付：

- **WP-A**：人工抽检量表固化——DB migration 新增 `dimension_scores jsonb NULL` 列、Rust 后端维度校验逻辑、OpenAPI 契约扩展、Flutter 评审表单与详情视图的维度打分 UI。
- **WP-B**：Bad case 集版本化 + 发版前回归——`quality-export` 与 `quality-regression-check` 两个只读 Rust 二进制、fixture 目录结构、CI workflow、CODEOWNERS 扩展。

全栈同里程碑交付，遵循 `full-stack-delivery-covenant.md`。

---

## Tasks

- [x] 1. 书面量表与 DB Migration
  - [x] 1.1 创建量表文档 `docs/plans/quality-rubric.md`
    - 顶部包含 `version: YYYY-MM-DD` 版本标识
    - 定义 7 个评审维度（`visual_consistency`、`narrative_coherence`、`lip_sync`、`pacing`、`character_consistency`、`dialogue_naturalness`、`faithfulness`）的中文标签、定义与评分说明
    - 明确 Pass_Threshold：`overall_score >= 6` 且无分值 ≤ 3 的维度
    - 说明抽样批次规则：每个 Stage 每周至少抽检 5 条
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 1.2 创建 DB migration `supabase/migrations/20260601120000_quality_review_dimension_scores.sql`
    - `ALTER TABLE public.app_quality_review ADD COLUMN IF NOT EXISTS dimension_scores jsonb NULL`
    - 添加列注释说明合法键名与值范围
    - 在文件注释中说明回滚方式：`ALTER TABLE app_quality_review DROP COLUMN IF EXISTS dimension_scores`
    - _Requirements: 2.1, 10.1, 10.2, 10.3_

- [x] 2. Rust 后端：维度校验核心逻辑
  - [x] 2.1 新增 `backend/src/prompting/quality/dimension.rs`
    - 定义 `VALID_DIMENSION_KEYS: &[&str]`（7 个维度键）
    - 实现 `validate_dimension_scores(scores: &serde_json::Value) -> Result<(), ApiError>`
      - 非对象类型 → `invalid_dimension_scores`（HTTP 400）
      - 未定义键 → `invalid_dimension_key`（HTTP 400，含 `invalidKeys`）
      - 值超出 1-10 → `dimension_score_out_of_range`（HTTP 400，含 `outOfRangeKeys`）
    - 实现 `pass_threshold_met(overall_score: Option<i16>, dimension_scores: Option<&serde_json::Value>) -> bool`
      - `overall_score >= 6` 且无分值 ≤ 3 时返回 `true`
    - _Requirements: 2.2, 2.3, 2.4, 1.2_

  - [x] 2.2 为 `validate_dimension_scores` 编写属性测试（Property 1）
    - **Property 1: dimension_scores 写入读取 round-trip**
    - 使用 `proptest`，随机生成合法 `dimension_scores`（键为 7 个维度之一，值 1-10），验证 `decode(encode(x)) == x`
    - **Validates: Requirements 2.5, 2.6, 2.8**

  - [x] 2.3 为 `pass_threshold_met` 编写属性测试（Property 2）
    - **Property 2: dimension_scores 校验与放行阈值一致性**
    - 随机 `overall_score`（0-15）与 `dimension_scores`，验证返回值当且仅当 `overall_score >= 6` 且无分值 ≤ 3 时为 `true`
    - **Validates: Requirements 1.2**

  - [x] 2.4 为 `dimension.rs` 编写单元测试
    - 合法输入（所有 7 个维度键合法且值在 1-10 内）→ `Ok(())`
    - 非法键名 → `Err` 含 `invalid_dimension_key`
    - 越界分值（0 或 11）→ `Err` 含 `dimension_score_out_of_range`
    - `pass_threshold_met`：`overall_score=6` 且无 D 级维度 → `true`；`overall_score=5` 或存在分值 ≤ 3 → `false`
    - _Requirements: 9.4_

- [x] 3. Rust 后端：扩展 types、validate、handlers
  - [x] 3.1 扩展 `backend/src/prompting/quality/types.rs`
    - 在 `QualityReview`（响应模型）中新增 `pub dimension_scores: Option<serde_json::Value>`（camelCase: `dimensionScores`）
    - 在 `CreateQualityReviewBody`（请求体）中新增 `pub dimension_scores: Option<serde_json::Value>`
    - _Requirements: 2.5, 2.6, 8.4, 3.6_

  - [x] 3.2 扩展 `backend/src/prompting/quality/validate.rs`
    - 在 `validate_create_review_body` 中调用 `validate_dimension_scores`（当 `dimension_scores` 存在且非 null 时）
    - _Requirements: 2.2, 2.3, 2.4_

  - [x] 3.3 扩展 `backend/src/prompting/quality/handlers/create.rs`
    - INSERT 语句新增 `dimension_scores` 参数绑定（`$N`）
    - RETURNING * 自动包含新列，无需额外修改
    - _Requirements: 2.1, 2.5_

- [x] 4. Checkpoint — 后端核心逻辑验证
  - 确保所有 Rust 单元测试与属性测试通过，ask the user if questions arise.

- [x] 5. OpenAPI 契约扩展
  - [x] 5.1 在 OpenAPI spec 中为 `dimensionScores` 字段添加 schema
    - `additionalProperties: {type: integer, minimum: 1, maximum: 10}`
    - 包含各维度键名枚举说明
    - 在 `QualityReview` 与 `CreateQualityReviewBody` schema 中引用
    - _Requirements: 2.7, 9.1_

  - [x] 5.2 在 OpenAPI spec `components/schemas` 中新增 `BadCaseFixture` schema
    - 包含 `exportedAt`、`reviewCount`、`schemaVersion`、`reviews` 字段定义
    - `reviews` 数组元素包含 `id`、`stage`、`grade`、`passed`、`overall_score`、`dimension_scores`、`is_bad_case`、`bad_case_category`、`skill_version_hash`、`created_at`
    - _Requirements: 9.2_

- [x] 6. Flutter rust_api 层扩展
  - [x] 6.1 扩展 `frontend/lib/rust_api/quality/models.dart`
    - 在 `QualityReview` 中新增 `final Map<String, int>? dimensionScores`
    - 在 `CreateQualityReviewBody` 中新增 `final Map<String, int>? dimensionScores`
    - 实现 `fromJson` 解析（`Map<String, int>.from(...)`）
    - 实现 `toJson` 序列化（`put('dimensionScores', dimensionScores)`）
    - _Requirements: 3.6, 8.4_

- [x] 7. Flutter UI：维度评分表单与展示组件
  - [x] 7.1 新增 `frontend/lib/quality_reviews/dimension_score_form.dart`（≤400 行）
    - 实现 `DimensionScoreFormWidget`：7 个维度的 1-10 评分滑块/输入控件，支持可选跳过
    - 实现 `DimensionScoreDisplayWidget`：详情视图展示各维度评分（中文标签 + 分值），null/空时显示「暂无维度评分」
    - 实现 `hasDimensionRisk(Map<String, int>? scores) -> bool`：存在分值 ≤ 3 时返回 `true`
    - 维度中文标签映射（`visual_consistency` → 画面/人设一致性，等）
    - 表单顶部展示量表版本字符串（从 `quality-rubric.md` `version:` 字段读取）
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.7, 8.1, 8.2, 8.3_

  - [x] 7.2 为 `DimensionScoreFormWidget` 编写属性测试（Property 6）
    - **Property 6: Flutter 维度评分表单校验与组装一致性**
    - 分值 1-10 → 校验通过，组装后 `dimensionScores` 键值与输入等价
    - 分值超出 1-10 → 校验失败，显示错误提示，不发起网络请求
    - **Validates: Requirements 3.2, 3.3, 3.4**

  - [x] 7.3 为 `hasDimensionRisk` 编写属性测试（Property 7）
    - **Property 7: 风险标记与分值规则一致性**
    - 随机 `dimensionScores`，验证 `hasDimensionRisk` 当且仅当存在分值 ≤ 3 时返回 `true`
    - **Validates: Requirements 8.3**

  - [x] 7.4 为维度评分表单编写 widget 测试
    - 合法输入（分值 1 和 10）：无错误提示，`dimensionScores` 包含对应键值
    - 越界输入（分值 0 和 11）：显示错误提示，不触发提交回调
    - null 安全性：`dimensionScores` 为 null 时显示「暂无维度评分」，不抛出异常
    - 回填测试：传入 `dimensionScores = {"lip_sync": 7}` 时对应控件初始值为 7
    - _Requirements: 9.5_

- [x] 8. Flutter UI：扩展 workbench_view.dart
  - [x] 8.1 在 `frontend/lib/quality_reviews/workbench_view.dart` 中集成维度评分组件
    - 创建表单区域嵌入 `DimensionScoreFormWidget`，收集 `dimensionScores` 并传入 `CreateQualityReviewBody`
    - 详情视图区域嵌入 `DimensionScoreDisplayWidget`
    - 列表视图中对 `hasDimensionRisk(review.dimensionScores)` 为 true 的记录添加红色 `Chip` 标签
    - _Requirements: 3.3, 8.1, 8.2, 8.3_

- [x] 9. Checkpoint — WP-A 全栈验证
  - 确保 `flutter test` 与 `cargo test` 全部通过，运行 `yarn refactor:agent` 检查 OpenAPI 契约无漂移，ask the user if questions arise.

- [x] 10. WP-B：Rust 数据结构与 Cargo 配置
  - [x] 10.1 在 `backend/src/prompting/quality/dimension.rs` 中新增 WP-B 数据结构
    - 定义 `BadCaseFixture`（含 `exported_at`、`review_count`、`schema_version`、`reviews`，`serde rename_all = "camelCase"`）
    - 定义 `FixtureReview`（含 `id`、`stage`、`grade`、`passed`、`overall_score`、`dimension_scores`、`is_bad_case`、`bad_case_category`、`skill_version_hash`、`created_at`）
    - 定义 `RegressionReport`（含 `fixture_file`、`total_checked`、`regression_count`、`regression_rate`、`regressions`，`serde rename_all = "camelCase"`）
    - 定义 `RegressionItem`（含 `id`、`fixture_passed`、`current_passed`，`serde rename_all = "camelCase"`）
    - _Requirements: 4.3, 7.3_

  - [x] 10.2 在 `backend/Cargo.toml` 中新增两个二进制目标
    - `[[bin]] name = "quality-export" path = "src/bin/quality_export.rs" test = false`
    - `[[bin]] name = "quality-regression-check" path = "src/bin/quality_regression_check.rs" test = false`
    - _Requirements: 4.1, 7.1_

- [x] 11. WP-B：Export_Tool 实现
  - [x] 11.1 新增 `backend/src/bin/quality_export.rs`（≤400 行）
    - 使用 `clap` derive 定义 CLI 参数：`--ids`（逗号分隔 UUID）、`--ids-file`（换行分隔文件）、`--stage`（可选过滤）、`--output`（输出路径）；`--ids` 与 `--ids-file` 互斥
    - 校验 `--stage` 合法性（使用 `VALID_STAGES`），非法时 stderr 输出合法值列表并 `exit(1)`
    - 从 `DATABASE_URL` 建立 `sqlx::PgPool`（只读连接），连接失败 `exit(1)`
    - `SELECT id, stage, grade, passed, overall_score, dimension_scores, is_bad_case, bad_case_category, skill_version_hash, created_at FROM app_quality_review WHERE id = ANY($1)`
    - 不存在的 ID → `eprintln!("WARN: review {} not found, skipped", id)`，继续
    - 序列化为 `BadCaseFixture` JSON（含 `exportedAt`、`reviewCount`、`schemaVersion: "1"`），写入 `--output`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.5_

  - [x] 11.2 为 Export_Tool 编写属性测试（Property 3）
    - **Property 3: Export_Tool fixture round-trip**
    - 随机评审记录集合，验证 `parse(export(reviews)) == reviews`（`serde_json` 序列化/反序列化等价）
    - **Validates: Requirements 4.2, 4.3, 4.8**

  - [x] 11.3 为 Export_Tool 编写属性测试（Property 4）
    - **Property 4: Export_Tool 只读性**
    - 执行 `quality-export` 前后，`app_quality_review` 表记录数和字段值保持不变
    - **Validates: Requirements 4.1**

- [x] 12. WP-B：Regression_Check_Tool 实现
  - [x] 12.1 新增 `backend/src/bin/quality_regression_check.rs`（≤350 行）
    - 使用 `clap` derive 定义 CLI 参数：`--fixture <path>`
    - 读取并解析 fixture JSON，校验 `schemaVersion` 和 `reviews` 字段存在；解析失败 → `exit(2)`，stderr 输出具体错误字段名，无 stdout 输出
    - 从 `DATABASE_URL` 建立 `sqlx::PgPool`
    - 批量查询 `SELECT id, passed FROM app_quality_review WHERE id = ANY($1)`
    - 对比每条记录：ID 不存在 → `eprintln!("WARN: review {} not found in DB, skipped", id)`，不计入分母；`fixture.passed != db.passed` → 计入退化列表
    - 计算 `regression_rate = regression_count / total_checked`
    - 输出 `RegressionReport` JSON 到 stdout
    - `regression_rate > 0.1` → `exit(1)`，否则 `exit(0)`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 12.2 为 Regression_Check_Tool 编写属性测试（Property 5）
    - **Property 5: Regression_Check_Tool 报告 round-trip 与退化率一致性**
    - 验证 `parse(report_json)` 等价于原始报告对象（round-trip）
    - 验证 `regressionRate == regressionCount / totalChecked`（metamorphic）
    - **Validates: Requirements 7.6, 7.7**

- [x] 13. WP-B：Fixture 目录与版本化管理
  - [x] 13.1 创建 fixture 目录结构与 README
    - 创建 `scripts/fixtures/quality/` 目录
    - 创建 `scripts/fixtures/quality/README.md`，说明 golden 集更新流程：（1）运行 Export_Tool 生成新 fixture；（2）提交 PR 并请求 CODEOWNER review；（3）在 PR 描述中说明新增/移除的 `quality_review_id` 及原因
    - _Requirements: 5.1, 5.3_

  - [x] 13.2 扩展 `.github/CODEOWNERS`
    - 新增 `scripts/fixtures/quality/  @<quality-owner>` 条目
    - _Requirements: 5.2_

- [x] 14. WP-B：CI Regression Workflow
  - [x] 14.1 新增 `.github/workflows/quality-regression.yml`
    - 触发方式：`workflow_dispatch` + `schedule: cron: '0 7 * * 1'`（UTC 周一 07:00）
    - 在 workflow 文件注释中说明暂停定时触发的方式（将 `schedule` 触发器注释掉）
    - `concurrency: group: quality-regression-${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true`
    - `permissions: contents: read`
    - Steps：`actions/checkout@v4`、`supabase/setup-cli@v1`、`dtolnay/rust-toolchain@stable`、`Swatinem/rust-cache@v2`
    - `supabase db start` + `supabase db reset --yes --no-seed`
    - `eval "$(supabase status -o env)"` 导出 `DATABASE_URL` 与 `SUPABASE_JWT_SECRET`
    - 遍历 `scripts/fixtures/quality/*.json`，对每个 fixture 调用 `cargo run --bin quality-regression-check -- --fixture $f`
    - 任意 `regression_rate > 10%` → `exit 1`
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 6.8, 6.9, 10.4_

- [x] 15. Final Checkpoint — 全量验证与提交准备
  - 运行 `yarn refactor:agent --full` 确保 OpenAPI 契约无漂移、`cargo test` 全绿、`flutter test` 全绿，ask the user if questions arise.

---

## Notes

- 标有 `*` 的子任务为可选项，可跳过以加快 MVP 交付
- 每个任务引用了具体需求条款，便于追溯
- Checkpoint 任务确保增量验证，避免积累问题
- 属性测试使用 `proptest` 库（已在 `[dev-dependencies]` 中），每个属性最少 100 次迭代
- 每个属性测试通过注释标注对应设计文档属性编号，格式：`// Feature: quality-benchmark-ops, Property N: <property_text>`
- `dimension_scores` 列为 `jsonb NULL`，旧客户端写入不受影响（最小侵入原则）
- 两个 CLI 二进制均为只读操作，不修改任何数据库记录

---

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2"] },
    { "id": 4, "tasks": ["2.3"] },
    { "id": 5, "tasks": ["2.4"] },
    { "id": 6, "tasks": ["3.1"] },
    { "id": 7, "tasks": ["3.2"] },
    { "id": 8, "tasks": ["3.3"] },
    { "id": 9, "tasks": ["4"] },
    { "id": 10, "tasks": ["5.1"] },
    { "id": 11, "tasks": ["5.2"] },
    { "id": 12, "tasks": ["6.1"] },
    { "id": 13, "tasks": ["7.1"] },
    { "id": 14, "tasks": ["7.2"] },
    { "id": 15, "tasks": ["7.3"] },
    { "id": 16, "tasks": ["7.4"] },
    { "id": 17, "tasks": ["8.1"] },
    { "id": 18, "tasks": ["9"] },
    { "id": 19, "tasks": ["10.1"] },
    { "id": 20, "tasks": ["10.2"] },
    { "id": 21, "tasks": ["11.1"] },
    { "id": 22, "tasks": ["11.2"] },
    { "id": 23, "tasks": ["11.3"] },
    { "id": 24, "tasks": ["12.1"] },
    { "id": 25, "tasks": ["12.2"] },
    { "id": 26, "tasks": ["13.1"] },
    { "id": 27, "tasks": ["13.2"] },
    { "id": 28, "tasks": ["14.1"] },
    { "id": 29, "tasks": ["15"] }
  ]
}
```
