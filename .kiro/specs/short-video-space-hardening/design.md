# 设计文档：short-video-space-hardening

## 设计目标

- **聚合端点不因脏数据崩溃**：任何来自 `app_generation_job.payload` 的字段都视为不可信输入。
- **状态门槛不可绕过**：对比字符串时统一 trim；必要时补充 lower/enum 映射。
- **回流信息可定位**：发布作业在 draft/target 上留“最后一次尝试摘要”，让 UI 能在不查 attempts 的情况下给用户可行动信息。

## 关键设计

### 1) SQL cast 安全模式（job payload）

统一使用三段式：

- `j.payload ? 'storyboard_numeric_id'`
- `(j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'`
- `(j.payload->>'storyboard_numeric_id')::int = ...`

此模式已在 workbench meta 查询中采用；本 spec 要求覆盖所有聚合端点。

### 2) gate 字段比较统一 trim

- `candidateStatus`：`TRIM(COALESCE(...,'')) <> 'pending'`

避免 `" pending"` 等输入造成 gate 误判。

### 3) publish 回流摘要

- draft：`metadata.last_publish_result`
- target：`extra.last_publish_result`

使用 JSONB merge（`||`）追加/覆盖，保留历史 attempts 仍由 `publish_attempts` 承载。

### 4) publish 输入校验

- 在 prepare 阶段（targets input-only validation）提前返回 blocking issues，避免进入 worker 后才失败。

## 风险与回滚

- SQL predicate 变化是向后兼容的：仅减少 500 风险，不改变正常数据的语义。
- publish 回流只写 JSONB 字段：失败可回滚 commit，不影响核心表结构。
