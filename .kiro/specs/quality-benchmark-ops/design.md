# Design Document: quality-benchmark-ops

## Overview

本功能在已落地的 `app_quality_review` 表与质量 REST API 基础上，完成两个工作包：

**WP-A：人工抽检量表固化** — 将评审维度（画面/叙事/对口型/节奏/人设一致性等）、阈值与「放行/打回」规则书面化，通过 `dimension_scores jsonb NULL` 列扩展 `app_quality_review`，使 Flutter 评审表单与后端维度打分对齐。

**WP-B：Bad case 集版本化 + 发版前回归** — 提供只读导出工具将固定 `quality_review_id` 集合导出为 fixture，并在 `.github/workflows/quality-regression.yml` 中新增定时/手动触发的 CI job，在发版前对比通过率，同时明确 golden 集更新规则与 CODEOWNER 审查要求。

### 设计原则

- **最小侵入**：`dimension_scores` 列为 `jsonb NULL`，旧客户端写入不受影响；新二进制只读，不修改任何数据库记录。
- **契约优先**：所有新增字段同步更新 OpenAPI spec，`rust_api` 层与后端契约保持一致，CI 门禁自动检测漂移。
- **单文件 ≤800 行**：新增 Rust 文件按语义拆分（`dimension.rs`、`export.rs`、`regression.rs`），Flutter 新增 `dimension_score_form.dart` 独立 widget 文件。
- **全栈同里程碑**：遵循 `full-stack-delivery-covenant.md`，backend + frontend + 契约在同一 PR 集合内交付。

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter 质量工作台                                              │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐ │
│  │ DimensionScoreForm   │  │ ReviewDetailView                 │ │
│  │ (7 维度 1-10 滑块)   │  │ (维度评分展示 + 红色风险标签)    │ │
│  └──────────┬───────────┘  └──────────────────────────────────┘ │
│             │ rust_api.createQualityReview(dimensionScores)      │
└─────────────┼───────────────────────────────────────────────────┘
              │ HTTP POST/GET /api/v1/quality/reviews
┌─────────────▼───────────────────────────────────────────────────┐
│  Rust Backend (toonflow-server)                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ quality/dimension.rs                                      │   │
│  │  - VALID_DIMENSION_KEYS: [visual_consistency, ...]        │   │
│  │  - validate_dimension_scores(scores) -> Result<(), ApiError>│  │
│  │  - pass_threshold_met(overall, scores) -> bool            │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ quality/handlers/create.rs  (扩展)                        │   │
│  │  - 接收 dimension_scores: Option<serde_json::Value>       │   │
│  │  - 调用 validate_dimension_scores                         │   │
│  │  - INSERT ... dimension_scores = $N                       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
              │
┌─────────────▼───────────────────────────────────────────────────┐
│  PostgreSQL (Supabase)                                           │
│  app_quality_review                                              │
│  + dimension_scores jsonb NULL                                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  CLI 工具 (独立二进制)                                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ bin/quality_export.rs                                     │   │
│  │  cargo run --bin quality-export -- --ids ... --output ... │   │
│  │  只读：SELECT from app_quality_review                     │   │
│  │  输出：scripts/fixtures/quality/<stage>_<YYYYMMDD>.json   │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ bin/quality_regression_check.rs                           │   │
│  │  cargo run --bin quality-regression-check -- --fixture .. │   │
│  │  只读：对比 fixture.passed vs DB.passed                   │   │
│  │  输出：JSON 报告到 stdout，退出码 0/1/2                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  CI (.github/workflows/quality-regression.yml)                  │
│  trigger: workflow_dispatch | schedule (UTC Mon 07:00)          │
│  1. supabase db start + reset                                   │
│  2. for each scripts/fixtures/quality/*.json:                   │
│       cargo run --bin quality-regression-check -- --fixture $f  │
│  3. 任意 regression_rate > 10% → exit 1                        │
└─────────────────────────────────────────────────────────────────┘
```


---

## Components and Interfaces

### WP-A：维度打分扩展

#### 1. DB Migration

新增 migration 文件 `supabase/migrations/20260601120000_quality_review_dimension_scores.sql`：

```sql
-- 为 app_quality_review 新增 dimension_scores 列
-- 回滚方式：ALTER TABLE app_quality_review DROP COLUMN IF EXISTS dimension_scores
ALTER TABLE public.app_quality_review
    ADD COLUMN IF NOT EXISTS dimension_scores jsonb NULL;

COMMENT ON COLUMN public.app_quality_review.dimension_scores IS
    '维度评分 JSON 对象，键为维度名（visual_consistency/narrative_coherence/lip_sync/pacing/character_consistency/dialogue_naturalness/faithfulness），值为 1-10 整数';
```

#### 2. Rust 后端：`quality/dimension.rs`（新增，≤200 行）

```rust
// 合法维度键枚举
pub const VALID_DIMENSION_KEYS: &[&str] = &[
    "visual_consistency",
    "narrative_coherence",
    "lip_sync",
    "pacing",
    "character_consistency",
    "dialogue_naturalness",
    "faithfulness",
];

/// 校验 dimension_scores JSON 对象
/// - 键必须是 VALID_DIMENSION_KEYS 之一
/// - 值必须是 1-10 整数
/// 返回 Err(ApiError::BadRequest) 含错误码 invalid_dimension_key 或 dimension_score_out_of_range
pub fn validate_dimension_scores(scores: &serde_json::Value) -> Result<(), ApiError>;

/// 放行阈值判断：overall_score >= 6 且无分值 <= 3 的维度
pub fn pass_threshold_met(overall_score: Option<i16>, dimension_scores: Option<&serde_json::Value>) -> bool;
```

#### 3. Rust 后端：扩展 `types.rs`

在 `QualityReview` 和 `CreateQualityReviewBody` 中新增字段：

```rust
// QualityReview（响应模型）
pub dimension_scores: Option<serde_json::Value>,  // camelCase: dimensionScores

// CreateQualityReviewBody（请求体）
pub dimension_scores: Option<serde_json::Value>,  // camelCase: dimensionScores
```

#### 4. Rust 后端：扩展 `validate.rs`

在 `validate_create_review_body` 中调用 `validate_dimension_scores`：

```rust
if let Some(scores) = body.dimension_scores.as_ref() {
    if !scores.is_null() {
        validate_dimension_scores(scores)?;
    }
}
```

#### 5. Rust 后端：扩展 `handlers/create.rs`

INSERT 语句新增 `dimension_scores` 参数绑定，RETURNING * 自动包含新列。

#### 6. OpenAPI spec 扩展

在 `openapi_spec/shell.rs` 或 `openapi_spec/generated/` 中为 `dimensionScores` 字段添加 schema：

```yaml
dimensionScores:
  type: object
  nullable: true
  additionalProperties:
    type: integer
    minimum: 1
    maximum: 10
  description: |
    维度评分对象。合法键：visual_consistency, narrative_coherence, lip_sync,
    pacing, character_consistency, dialogue_naturalness, faithfulness。
    值范围 1-10（含边界）。
```

同时在 `components/schemas` 中新增 `BadCaseFixture` schema（见 WP-B）。

#### 7. Flutter `rust_api` 层扩展

在 `frontend/lib/rust_api/quality/models.dart` 中扩展：

```dart
// QualityReview 新增字段
final Map<String, int>? dimensionScores;

// CreateQualityReviewBody 新增字段
final Map<String, int>? dimensionScores;

// fromJson 解析
dimensionScores: json['dimensionScores'] == null
    ? null
    : Map<String, int>.from(
        (json['dimensionScores'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num).toInt()),
        ),
      ),

// toJson 序列化（CreateQualityReviewBody）
put('dimensionScores', dimensionScores);
```

#### 8. Flutter UI：`dimension_score_form.dart`（新增，≤400 行）

新增独立 widget 文件 `frontend/lib/quality_reviews/dimension_score_form.dart`，包含：

- `DimensionScoreFormWidget`：展示 7 个维度的 1-10 评分滑块（`Slider` 或 `TextFormField`），支持可选跳过
- `DimensionScoreDisplayWidget`：详情视图中展示各维度评分（中文标签 + 分值），`null`/空时显示「暂无维度评分」
- `hasDimensionRisk(Map<String, int>? scores) -> bool`：判断是否存在分值 ≤ 3 的维度，用于列表视图红色标签
- 量表版本字符串从 `docs/plans/quality-rubric.md` 顶部 `version:` 字段读取（编译时常量或运行时读取）

维度中文标签映射：

| 键 | 中文标签 |
|---|---|
| `visual_consistency` | 画面/人设一致性 |
| `narrative_coherence` | 叙事连贯性 |
| `lip_sync` | 对口型 |
| `pacing` | 节奏 |
| `character_consistency` | 人设一致性 |
| `dialogue_naturalness` | 对白自然度 |
| `faithfulness` | 与原著/设定符合度 |

#### 9. Flutter UI：扩展 `workbench_view.dart`

- 在创建表单区域嵌入 `DimensionScoreFormWidget`，收集 `dimensionScores` 并传入 `CreateQualityReviewBody`
- 在详情视图区域嵌入 `DimensionScoreDisplayWidget`
- 在列表视图中，对 `hasDimensionRisk(review.dimensionScores)` 为 true 的记录添加红色 `Chip` 标签
- 在表单顶部展示量表版本字符串

---

### WP-B：Bad case 导出与 CI 回归

#### 10. Rust 二进制：`bin/quality_export.rs`（新增，≤400 行）

```
cargo run --bin quality-export -- --ids <id1,id2,...> --output <path>
cargo run --bin quality-export -- --ids-file <path> --output <path>
cargo run --bin quality-export -- --ids <id1,...> --stage storyboard_panel --output <path>
```

CLI 参数（使用 `clap` derive）：

```rust
#[derive(Parser)]
struct Args {
    #[arg(long, value_delimiter = ',', conflicts_with = "ids_file")]
    ids: Vec<Uuid>,
    #[arg(long, conflicts_with = "ids")]
    ids_file: Option<PathBuf>,
    #[arg(long)]
    stage: Option<String>,
    #[arg(long)]
    output: PathBuf,
}
```

执行流程：
1. 解析参数，校验 `--stage` 合法性（使用 `VALID_STAGES`）
2. 从 `DATABASE_URL` 环境变量建立 `sqlx::PgPool`（只读连接）
3. `SELECT id, stage, grade, passed, overall_score, dimension_scores, is_bad_case, bad_case_category, skill_version_hash, created_at FROM app_quality_review WHERE id = ANY($1)`
4. 不存在的 ID → `eprintln!("WARN: review {} not found, skipped", id)`，继续
5. 序列化为 `BadCaseFixture` JSON，写入 `--output` 路径
6. 数据库连接失败 → `eprintln!("ERROR: ..."); std::process::exit(1)`

#### 11. Rust 二进制：`bin/quality_regression_check.rs`（新增，≤350 行）

```
cargo run --bin quality-regression-check -- --fixture <path>
```

执行流程：
1. 读取并解析 fixture JSON，校验 `schemaVersion` 和 `reviews` 字段存在
   - 解析失败 → `eprintln!("ERROR: ..."); std::process::exit(2)`
2. 从 `DATABASE_URL` 建立 `sqlx::PgPool`
3. 批量查询 `SELECT id, passed FROM app_quality_review WHERE id = ANY($1)`
4. 对比每条记录：
   - ID 不存在 → `eprintln!("WARN: review {} not found in DB, skipped", id)`，不计入分母
   - `fixture.passed != db.passed` → 计入退化列表
5. 计算 `regression_rate = regression_count / total_checked`
6. 输出 JSON 报告到 stdout（见数据模型）
7. `regression_rate > 0.1` → `std::process::exit(1)`，否则 `exit(0)`

#### 12. CI Workflow：`.github/workflows/quality-regression.yml`

```yaml
# 暂停定时触发：将下方 schedule 触发器注释掉即可；workflow_dispatch 保持可用
name: Quality Regression
on:
  workflow_dispatch:
  schedule:
    - cron: '0 7 * * 1'  # UTC 每周一 07:00

concurrency:
  group: quality-regression-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with: { version: latest }
      - uses: dtolnay/rust-toolchain@stable
      - uses: Swatinem/rust-cache@v2
        with: { workspaces: backend }
      - name: Start local Supabase
        run: |
          supabase db start
          supabase db reset --yes --no-seed
      - name: Export DATABASE_URL
        run: |
          eval "$(supabase status -o env)"
          echo "DATABASE_URL=${DB_URL}" >> $GITHUB_ENV
          echo "SUPABASE_JWT_SECRET=${JWT_SECRET}" >> $GITHUB_ENV
      - name: Run regression checks
        run: |
          set -euo pipefail
          total_files=0; total_records=0; total_regressions=0
          for fixture in scripts/fixtures/quality/*.json; do
            [ -f "$fixture" ] || continue
            total_files=$((total_files + 1))
            cd backend
            cargo run --bin quality-regression-check -- --fixture "../$fixture"
            cd ..
          done
          echo "Checked $total_files fixture files"
```

#### 13. Fixture 目录结构

```
scripts/fixtures/quality/
├── README.md                          # golden 集更新流程说明
├── storyboard_panel_20260601.json     # 示例 fixture
└── video_prompt_20260601.json         # 示例 fixture
```

#### 14. CODEOWNERS 扩展

在 `.github/CODEOWNERS` 中新增：

```
scripts/fixtures/quality/  @<quality-owner>
```

#### 15. 量表文档：`docs/plans/quality-rubric.md`（新增）

顶部包含版本标识：

```markdown
version: 2026-06-01

# 质量评审量表（Rubric）
```

包含 7 个维度定义、评分说明、Pass_Threshold 规则、抽样批次规则。


---

## Data Models

### BadCaseFixture（导出 JSON 格式）

```json
{
  "exportedAt": "2026-06-01T10:00:00Z",
  "reviewCount": 3,
  "schemaVersion": "1",
  "reviews": [
    {
      "id": "uuid-...",
      "stage": "storyboard_panel",
      "grade": "D",
      "passed": false,
      "overall_score": 4,
      "dimension_scores": {
        "visual_consistency": 3,
        "lip_sync": 5
      },
      "is_bad_case": true,
      "bad_case_category": "character_break",
      "skill_version_hash": "abc123",
      "created_at": "2026-05-20T08:00:00Z"
    }
  ]
}
```

### RegressionReport（回归检查 stdout JSON）

```json
{
  "fixtureFile": "scripts/fixtures/quality/storyboard_panel_20260601.json",
  "totalChecked": 10,
  "regressionCount": 1,
  "regressionRate": 0.10,
  "regressions": [
    {
      "id": "uuid-...",
      "fixturePassed": false,
      "currentPassed": true
    }
  ]
}
```

### Rust 数据结构

```rust
// quality/dimension.rs
#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BadCaseFixture {
    pub exported_at: chrono::DateTime<chrono::Utc>,
    pub review_count: usize,
    pub schema_version: String,  // 当前为 "1"
    pub reviews: Vec<FixtureReview>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct FixtureReview {
    pub id: Uuid,
    pub stage: Option<String>,
    pub grade: Option<String>,
    pub passed: Option<bool>,
    pub overall_score: Option<i16>,
    pub dimension_scores: Option<serde_json::Value>,
    pub is_bad_case: bool,
    pub bad_case_category: Option<String>,
    pub skill_version_hash: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegressionReport {
    pub fixture_file: String,
    pub total_checked: usize,
    pub regression_count: usize,
    pub regression_rate: f64,  // 0.0-1.0
    pub regressions: Vec<RegressionItem>,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegressionItem {
    pub id: Uuid,
    pub fixture_passed: Option<bool>,
    pub current_passed: Option<bool>,
}
```

### Cargo.toml 新增二进制目标

```toml
[[bin]]
name = "quality-export"
path = "src/bin/quality_export.rs"
test = false

[[bin]]
name = "quality-regression-check"
path = "src/bin/quality_regression_check.rs"
test = false
```


---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

本功能包含纯函数逻辑（维度校验、放行阈值判断、fixture 序列化/反序列化、退化率计算），适合属性测试。使用 `proptest` 库（已在 `[dev-dependencies]` 中）。

**Property Reflection（去冗余）：**
- 需求 2.5/2.6/2.8 均为 dimension_scores round-trip，合并为 Property 1
- 需求 4.2/4.3/4.8 均为 fixture round-trip，合并为 Property 3
- 需求 7.6/7.3 均为 report round-trip，合并为 Property 5
- 需求 3.2/3.3/3.4 均为前端校验/组装逻辑，合并为 Property 6
- 需求 8.3 为独立的风险标记属性，保留为 Property 7

---

### Property 1: dimension_scores 写入读取 round-trip

*For any* 合法的 `dimension_scores` 对象（键为 7 个已定义维度名之一，值为 1-10 整数），将其写入 `app_quality_review` 后，通过 `GET /api/v1/quality/reviews/{id}` 或列表接口读取，返回的 `dimensionScores` 字段应与写入值等价（`decode(encode(x)) == x`）。

**Validates: Requirements 2.5, 2.6, 2.8**

---

### Property 2: dimension_scores 校验与放行阈值一致性

*For any* `overall_score`（0-15 范围内随机）和 `dimension_scores`（随机键值对），`pass_threshold_met(overall_score, dimension_scores)` 的返回值应当且仅当 `overall_score >= 6` 且 `dimension_scores` 中无分值 ≤ 3 的维度时为 `true`。

**Validates: Requirements 1.2**

---

### Property 3: Export_Tool fixture round-trip

*For any* 合法的评审记录集合（随机 `stage`、`grade`、`passed`、`overall_score`、`dimension_scores` 组合），`quality-export` 导出的 JSON 文件经 `serde_json::from_str` 解析后，应得到与原始记录等价的 `BadCaseFixture` 对象（`parse(export(reviews)) == reviews`）。

**Validates: Requirements 4.2, 4.3, 4.8**

---

### Property 4: Export_Tool 只读性

*For any* 合法输入参数，执行 `quality-export` 前后，`app_quality_review` 表的记录数和所有字段值应保持不变（Export_Tool 不修改任何数据库记录）。

**Validates: Requirements 4.1**

---

### Property 5: Regression_Check_Tool 报告 round-trip 与退化率一致性

*For any* 合法的 fixture 输入，`quality-regression-check` 输出的 JSON 报告满足两个不变量：
1. **Round-trip**：`parse(report_json)` 等价于原始报告对象
2. **Metamorphic**：`regressionRate == regressionCount / totalChecked`（退化率与计数严格一致）

**Validates: Requirements 7.6, 7.7**

---

### Property 6: Flutter 维度评分表单校验与组装一致性

*For any* 维度分值输入（随机整数），Flutter 表单的行为应满足：
- 分值在 1-10 范围内 → 校验通过，组装后的 `dimensionScores` JSON 中对应键值与输入等价
- 分值超出 1-10 范围 → 校验失败，显示错误提示，不发起网络请求

**Validates: Requirements 3.2, 3.3, 3.4**

---

### Property 7: 风险标记与分值规则一致性

*For any* `dimensionScores` 对象，`hasDimensionRisk(scores)` 的返回值应当且仅当存在至少一个分值 ≤ 3 的维度时为 `true`，且列表视图中对应记录的红色标签显示状态与该函数返回值一致。

**Validates: Requirements 8.3**


---

## Error Handling

### 后端 API 错误

| 场景 | HTTP 状态码 | 错误码 | 响应体 |
|---|---|---|---|
| `dimension_scores` 包含未定义维度键 | 400 | `invalid_dimension_key` | `{ "error": "invalid_dimension_key", "invalidKeys": ["unknown_dim"] }` |
| `dimension_scores` 中分值超出 1-10 | 400 | `dimension_score_out_of_range` | `{ "error": "dimension_score_out_of_range", "outOfRangeKeys": [{"key": "lip_sync", "value": 0}] }` |
| `dimension_scores` 不是 JSON 对象 | 400 | `invalid_dimension_scores` | `{ "error": "invalid_dimension_scores", "message": "must be a JSON object" }` |

错误响应通过现有 `bad_request_i18n` 辅助函数生成，支持中英双语。

### Export_Tool 错误处理

| 场景 | 行为 |
|---|---|
| 指定 ID 不存在 | `stderr: WARN: review <id> not found, skipped`，继续导出其余记录，退出码 0 |
| 数据库连接失败 | `stderr: ERROR: database connection failed: <msg>`，退出码 1 |
| `--ids` 与 `--ids-file` 同时提供 | `clap` 自动报错，退出码 2 |
| `--stage` 值非法 | `stderr: ERROR: invalid stage: <val>, valid: [...]`，退出码 1 |
| 输出路径不可写 | `stderr: ERROR: cannot write to <path>: <msg>`，退出码 1 |

### Regression_Check_Tool 错误处理

| 场景 | 行为 |
|---|---|
| fixture JSON 解析失败 | `stderr: ERROR: invalid fixture: <field>`，退出码 2，无 stdout 输出 |
| fixture 缺少 `schemaVersion` 或 `reviews` | `stderr: ERROR: missing required field: <field>`，退出码 2 |
| 数据库中 ID 不存在 | `stderr: WARN: review <id> not found in DB, skipped`，不计入分母 |
| `regressionRate > 0.1` | stdout 输出完整报告，退出码 1 |
| `regressionRate <= 0.1` | stdout 输出完整报告，退出码 0 |

### Flutter 前端错误处理

| 场景 | 行为 |
|---|---|
| 维度分值超出 1-10 | 控件旁显示错误提示文本，阻止提交，不发起网络请求 |
| `dimensionScores` 为 null 或空对象 | 详情视图显示「暂无维度评分」占位文本，不抛出异常 |
| 后端返回 `invalid_dimension_key` | 通过现有 `ensureHttpSuccess` 抛出 `RustApiException`，上层 UI 显示错误 snackbar |

---

## Testing Strategy

### 单元测试（`cargo test`）

**新增测试文件：`backend/src/prompting/quality/dimension_tests.rs`**

覆盖场景（需求 9.4）：

1. **合法输入**：所有 7 个维度键合法且值在 1-10 内 → `validate_dimension_scores` 返回 `Ok(())`
2. **非法键名**：包含未定义维度键 → 返回 `Err(ApiError::BadRequest)` 含 `invalid_dimension_key`
3. **越界分值**：值为 0 或 11 → 返回 `Err(ApiError::BadRequest)` 含 `dimension_score_out_of_range`
4. **放行阈值**：`overall_score=6` 且无 D 级维度 → `pass_threshold_met` 返回 `true`
5. **打回阈值**：`overall_score=5` 或存在分值 ≤ 3 的维度 → `pass_threshold_met` 返回 `false`

**属性测试（proptest）：**

```rust
// Feature: quality-benchmark-ops, Property 2: 放行阈值一致性
proptest! {
    #![proptest_config(ProptestConfig::with_cases(200))]
    #[test]
    fn prop_pass_threshold_consistent_with_rules(
        overall_score in prop::option::of(0i16..=15),
        dim_scores in prop::collection::hash_map(
            prop_oneof![Just("visual_consistency"), Just("lip_sync"), Just("pacing")],
            1i64..=10,
            0..=3,
        ),
    ) {
        let scores_json = serde_json::to_value(&dim_scores).unwrap();
        let result = pass_threshold_met(overall_score, Some(&scores_json));
        let expected = overall_score.map_or(false, |s| s >= 6)
            && dim_scores.values().all(|&v| v > 3);
        prop_assert_eq!(result, expected);
    }
}

// Feature: quality-benchmark-ops, Property 5: 退化率计算一致性
proptest! {
    #![proptest_config(ProptestConfig::with_cases(200))]
    #[test]
    fn prop_regression_rate_equals_count_over_total(
        total_checked in 1usize..=100,
        regression_count in 0usize..=100,
    ) {
        let regression_count = regression_count.min(total_checked);
        let report = RegressionReport {
            fixture_file: "test.json".into(),
            total_checked,
            regression_count,
            regression_rate: regression_count as f64 / total_checked as f64,
            regressions: vec![],
        };
        let json = serde_json::to_value(&report).unwrap();
        let parsed: RegressionReport = serde_json::from_value(json).unwrap();
        prop_assert!((parsed.regression_rate - (regression_count as f64 / total_checked as f64)).abs() < 1e-10);
    }
}
```

**属性测试（proptest）— dimension_scores round-trip：**

```rust
// Feature: quality-benchmark-ops, Property 1: dimension_scores round-trip
proptest! {
    #![proptest_config(ProptestConfig::with_cases(200))]
    #[test]
    fn prop_dimension_scores_roundtrip(
        scores in prop::collection::hash_map(
            prop_oneof![
                Just("visual_consistency"),
                Just("narrative_coherence"),
                Just("lip_sync"),
                Just("pacing"),
                Just("character_consistency"),
                Just("dialogue_naturalness"),
                Just("faithfulness"),
            ],
            1i64..=10,
            0..=7,
        ),
    ) {
        let original = serde_json::to_value(&scores).unwrap();
        let serialized = serde_json::to_string(&original).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&serialized).unwrap();
        prop_assert_eq!(original, parsed);
    }
}
```

**属性测试（proptest）— fixture round-trip：**

```rust
// Feature: quality-benchmark-ops, Property 3: fixture round-trip
proptest! {
    #![proptest_config(ProptestConfig::with_cases(100))]
    #[test]
    fn prop_fixture_roundtrip(
        review_count in 0usize..=20,
        passed_flags in prop::collection::vec(prop::option::of(any::<bool>()), 0..=20),
    ) {
        let reviews: Vec<FixtureReview> = passed_flags.into_iter().take(review_count)
            .map(|passed| FixtureReview {
                id: Uuid::new_v4(),
                stage: Some("storyboard_panel".into()),
                grade: Some("B".into()),
                passed,
                overall_score: Some(7),
                dimension_scores: None,
                is_bad_case: false,
                bad_case_category: None,
                skill_version_hash: None,
                created_at: Utc::now(),
            })
            .collect();
        let fixture = BadCaseFixture {
            exported_at: Utc::now(),
            review_count: reviews.len(),
            schema_version: "1".into(),
            reviews,
        };
        let json = serde_json::to_string(&fixture).unwrap();
        let parsed: BadCaseFixture = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(fixture.review_count, parsed.review_count);
        prop_assert_eq!(fixture.schema_version, parsed.schema_version);
        prop_assert_eq!(fixture.reviews.len(), parsed.reviews.len());
    }
}
```

### Widget 测试（`flutter test`）

**新增测试文件：`frontend/test/quality_reviews/dimension_score_form_test.dart`**

覆盖场景（需求 9.5）：

1. **合法输入（分值 1 和 10）**：
   - 输入分值 1 → 无错误提示，`dimensionScores` 包含对应键值
   - 输入分值 10 → 无错误提示，`dimensionScores` 包含对应键值
2. **越界输入（分值 0 和 11）**：
   - 输入分值 0 → 显示错误提示文本，不触发提交回调
   - 输入分值 11 → 显示错误提示文本，不触发提交回调
3. **null 安全性**：`dimensionScores` 为 null 时，`DimensionScoreDisplayWidget` 显示「暂无维度评分」，不抛出异常
4. **回填测试**：传入 `dimensionScores = {"lip_sync": 7}` 时，对应控件初始值为 7

### 集成测试（CI）

- **`supabase-migrations` job**（已有）：应用新 migration，验证 `dimension_scores` 列存在
- **`quality-regression.yml`**（新增）：端到端验证 Export_Tool + Regression_Check_Tool 流程
- **`openapi-contract` job**（已有）：验证 `dimensionScores` 和 `BadCaseFixture` schema 无漂移

### 测试配置

- 属性测试最少 100 次迭代（`ProptestConfig::with_cases(100)` 或更高）
- 每个属性测试通过注释标注对应设计文档属性编号
- Tag 格式：`// Feature: quality-benchmark-ops, Property N: <property_text>`
