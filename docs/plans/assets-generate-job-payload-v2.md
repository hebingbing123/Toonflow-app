# `assets-generate` → `app_generation_job.payload` v2（HTTP H3）

**范围**：`POST /api/v1/assets-generate/generate`、`polish-prompt`、`batch-generate`、`batch-polish` 入队写入的 JSON payload；对应 worker：`jobs/worker/asset_image/{generate,batch}.rs`、`asset_polish.rs` 中 **`source` 以 `assets-generate.` 开头** 的路径。

## 版本

| `payload_schema_version` | 语义 |
|--------------------------|------|
| **缺省 / `1`**（隐含） | 仅 **`project_numeric_id`**（历史行为）。 |
| **`2`** | **UUID-first + legacy fallback 双写**：**`project_uuid`**（`app_project.id`，主语义）+ **`project_numeric_id`**（任务中心按 numeric 过滤、兼容旧 worker）。 |

新入队统一写 **`payload_schema_version`: 2**；其中 **`project_uuid`** 是目标主语义，**`project_numeric_id`** 仅为当前兼容窗口保留。

## Worker 兼容（v1 / v2）

**`resolve_project_numeric_from_job_payload`**（`backend/src/jobs/payload_project.rs`）：

- 仅有 **`project_numeric_id`** → 与 v1 一致（校验归属）。
- 仅有 **`project_uuid`** → 查库解析 numeric（归属校验）。
- 二者皆有 → 与 HTTP 层相同：**必须指向同一项目**，否则失败任务。

不要求停机清空队列：在途 **v1** 任务照常执行。

## 回滚

- **代码回滚**：worker 若退回旧实现，仍只读 **`project_numeric_id`**；只要 enqueue 侧仍写入 numeric（当前双写保留），旧 worker 可继续跑。
- **停止写 UUID**：可从 handler 去掉 `project_uuid` / `payload_schema_version` 字段（不推荐长期）；观测与排障会弱化。

## 观测（Q2）

**`QueueStats.pending_by_kind_json`** 按 **`kind`** 聚合，与 payload 内字段无关。**`/jobs/page?project_id=`** 当前仍使用 **`payload->>'project_numeric_id'`**，所以兼容窗口内继续双写以保证过滤不变；这不改变整体 **UUID-first** 迁移方向。

## 后续（非本竖切）

- **v3**（未来）：若移除 **`project_numeric_id`**，需同步任务列表过滤与 observability SQL；独立里程碑。
- **生产域** batch payload（`production.*` source）仍可按同一 helper 渐进对齐。
