# 设计文档：short-video-space-consistency

## 背景

本轮 review 发现：

- `POST /api/v1/projects` 对文本字段使用 `trim_opt`（trim + 空置 null），但 `PATCH /api/v1/projects/{id}` 的 `parse_optional_text_field` 默认 **不 trim**，导致写入语义不一致。
- `target_platforms` 在 PATCH 与 CREATE 的处理不一致：
  - 可能存入带空格的平台 id
  - 可能允许提供空数组绕过“must not be empty”的约束
- `candidateStatus` 在 readiness/overview/export-check 的比较逻辑应统一为 trim 后比较。

## 设计原则

- 兼容优先：尽量不改变现有可接受输入的大类（仍允许 null/省略），但修正明显的“空格绕过/空数组绕过”。
- 统一工具函数：将 PATCH 场景的 `FieldPatch<String>` 归一化抽象为小工具函数，避免散落重复实现。

## 方案

### 1) PATCH text patch normalization

新增本地 helper：

- `trim_text_patch(FieldPatch<String>) -> FieldPatch<String>`

语义：

- `Absent` 保持
- `Set(Some(s))`：trim 后为空 => `Set(None)`；否则 `Set(Some(trimmed))`
- `Set(None)` 保持

### 2) PATCH target_platforms normalization

- 将 array 中每个元素 trim + 过滤空
- 若字段出现（array），则调用 `validate_target_platforms`（该函数内部强制非空）

### 3) CREATE target_platforms normalization

- CREATE 时同样对元素 trim + 过滤空
- 若字段出现（Some），则调用 `validate_target_platforms`（强制非空）

### 4) export-check candidateStatus gate

- `row.candidate_status.as_deref().map(str::trim) == Some("pending")`

## 测试

- 依赖现有 validation integration tests；必要时补充：
  - PATCH 文本字段输入 `"   "` 写入应变为 null
  - target_platforms 中含空格/空字符串的行为
  - export-check candidateStatus 为 `" pending "` 仍阻断

## 风险

- `PATCH` 行为会更“干净”：以前可能写入带空格的字符串，现在会被 trim；属于兼容性风险较低的修正。
