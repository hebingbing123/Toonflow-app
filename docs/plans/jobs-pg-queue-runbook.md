# PG 任务队列（`app_generation_job`）运维与平台 Runbook

**真源**：队列实现 [`backend/src/jobs/queue/pg.rs`](../../backend/src/jobs/queue/pg.rs)、Worker [`backend/src/jobs/worker/mod.rs`](../../backend/src/jobs/worker/mod.rs)。  
**旁路队列（Redis / 云托管）**：仅当 [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A1 Gate** 评审通过后再上；本 Runbook 以 **Postgres 为默认真源**（与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) §7.1 一致）。  
**竖切清单**：[**`tasks-pg-queue-observability.md`**](./tasks-pg-queue-observability.md)。

---

## 1. 角色与目标

| 角色 | 目标 |
|------|------|
| **SRE / 运维** | 扩容 worker、读指标、处理 stuck `running`、对账 |
| **平台工程** | 指标进集中日志/告警；旁路队列 Gate 量化 |
| **产品** | 理解「排队 vs 调度延迟」与 `run_at_ms` 语义 |

---

## 2. 环境变量（必记）

| 变量 | 含义 |
|------|------|
| `DATABASE_URL` | Worker 与 API 共用 PG；未设置时 worker 不启动 |
| `WORKER_ID` | 写入 `app_generation_job.claimed_by`；多实例 **必须** 区分 |
| `JOB_QUEUE_METRICS_INTERVAL_SECS` | 结构化日志 **`event=job_queue_metrics`** 间隔秒数；**默认 60**；**0** 关闭 |

详见 `backend/README.md` 与 `backend/.env.example`。

---

## 3. 结构化指标：`job_queue_metrics`

Worker 周期性输出（`tracing`，便于 Datadog / Loki / CloudWatch 解析）：

| 字段 | 类型 | 含义 |
|------|------|------|
| `event` | 常量 | `job_queue_metrics` |
| `worker_id` | string | `WORKER_ID` 或 `default` |
| `pending` | int | 全部 `status = 'queued'`（**含**未到 `run_at_ms` 的排程） |
| `pending_claimable` | int | 当前 worker **可抢**的 queued（`run_at_ms` 空或已到期） |
| `running` | int | `running` |
| `dead` | int | `dead` |
| `failed_last_24h` | int | 近 24h 内进入过 `failed` 的行数（重试/故障信号） |
| `oldest_claimable_queued_age_secs` | int 或空 | 可抢队列中 **最老** `created_at` 距现在的秒数；无则省略 |
| `pending_by_kind` | JSON object | 最多 15 个 `kind` → 当前 **全部** queued 计数（含未来排程） |

**告警建议（平台级）**

- `pending_claimable` 持续高于阈值 + `oldest_claimable_queued_age_secs` 过大 → 扩容 worker 或排查执行过慢。
- `pending` ≫ `pending_claimable` 长期成立 → 大量未来排程占坑；检查调度/业务是否误写 `run_at_ms`。
- `failed_last_24h` 陡增 → 对接 LLM/外部 API/磁盘与 `last_error` 列。

---

## 4. 水平扩容 Worker

1. 多机或多进程各设 **不同** `WORKER_ID`。
2. 抢单依赖 **`FOR UPDATE SKIP LOCKED`**（与 [`pg.rs`](../../backend/src/jobs/queue/pg.rs) 中 `claim_next_job` 一致）；**同一 DB** 下线性扩展 claim 吞吐。
3. 扩容后观察 `job_queue_metrics`：`running` 分布与 `claimed_by` 是否分散。

---

## 5. Stuck `running` 排查

**症状**：`running` 长期不降、某 `claimed_by` 占满。

1. 查最长 running：

```sql
SELECT id, kind, owner_user_id, claimed_by,
       EXTRACT(EPOCH FROM (NOW() - updated_at))::bigint AS running_age_secs,
       left(coalesce(last_error, ''), 200) AS last_error_snip
FROM app_generation_job
WHERE status = 'running'
ORDER BY updated_at ASC
LIMIT 50;
```

2. **进程崩溃**：旧行可能残留 `running`；需 **人工** 将无对应 worker 的行改回 `queued` 或 `failed`（须书面变更窗口 + 备份）。产品化「租约/心跳」另立项。

3. **正常取消**：客户端走 **取消 job** REST（见 OpenAPI `jobs` tag）；worker 协作轮询见 `JOB_KIND_FLUTTER_PROBE` 等实现。

---

## 6. 与 API / 用户路径

- 用户列表：`GET /api/v1/jobs` 等；指标日志 **不替代** REST，仅供运维。
- 合并新 job kind 时：更新 OpenAPI + worker `execute_kind` 分支 + 本 Runbook「典型 kind」表（可选维护）。

---

## 7. 旁路队列 Gate（WP-A1，书面评审）

在引入 **Redis / 云托管第二队列** 前，建议在变更评审单中填写（示例阈值，按环境调参）：

| 指标 | 连续观察窗口 | 建议 Gate（示例） |
|------|----------------|------------------|
| `oldest_claimable_queued_age_secs` p95 | 7d | > 120s 且日峰值 > N 分钟 |
| PG `active` 会话或 `wait_event` 锁竞争 | 同上 | 文档化瓶颈 SQL |
| `failed_last_24h` / `pending_claimable` 比 | 同上 | 排除业务错误后仍异常 |

**未过 Gate**：仅保留 PG + 本 Runbook 指标；**过 Gate**：执行 [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A1** 双写/影子验证。

---

## 8. 备份与迁移

- 迁移前：见 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) **WP-B**、`supabase/migrations/`。
- 大版本升级：评估是否在维护窗 **清空或 drain** `queued`（业务决策），避免 worker 与 schema 变更竞态。

---

## 9. 日志中按 `job_id` 关联

- Worker 在 claim / succeed / fail / cancel 路径调用 **`observe::generation_job`**，输出 **`tracing::info!`** 结构化字段（与 **`event = job_queue_metrics`** 同级，便于同一索引过滤）：

| 字段 | 说明 |
|------|------|
| `event` | 常量 **`generation_job_phase`** |
| `job_id` | **`app_generation_job.id`**（UUID） |
| `user_id` | **`owner_user_id`** |
| `kind` | **`app_generation_job.kind`** |
| `phase` | **`claimed`** / **`succeeded`** / **`failed`** / **`cancelled`** |
| `worker_id` | 与 **`claimed_by`** 一致的 worker 标签（**`WORKER_ID`** 或 **`default`**） |
| `client_request_id` | 可选；来自入队 **`payload.client_request_id`** 或 **`payload.request_id`**（非空才用于 join；HTTP 若将 **`X-Request-Id`** 写入 payload 则可与网关日志关联） |

- HTTP 请求用 **`X-Request-Id`**；与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) **WP-F** trace 策略对齐时，在 span 中携带同一 **`job_id`**（或把 request id 写入上表 **`payload`** 键以便 join）。

---

## 10. 修订记录

- 与 **`tasks-pg-queue-observability` Q1–Q2** 同步：扩展 `QueueStats`、结构化 `job_queue_metrics`、本 Runbook 首版。
- **Q4**：§9 补充 **`generation_job_phase`** 字段表与 **`client_request_id`** join 说明。
