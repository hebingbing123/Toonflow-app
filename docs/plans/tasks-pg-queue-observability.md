# 竖切任务：PG 任务队列观测与容量（WP-A0）

**母路线**：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A0**、[`harness-rust-flutter.md`](./harness-rust-flutter.md) §7.1（PG 为默认真源）。  
**门禁**：每合并一批涉及 `backend/` 的改动前跑 `yarn refactor:check`。

**全栈**：本清单以 **运维可观测** 为主；凡新增 **用户/运营可读 REST**（如 Q2 方案 B），**同一里程碑**须含 **`frontend/`**（内部运维屏或设置里「队列健康」卡片）+ `rust_api`；仅日志/Runbook 的条目在节首已隐含 **`(ops-only)`**。总约定见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

**优先级说明**：先做本清单（运维可观测、Gate 可量化），再考虑 [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A1**（旁路队列）。

---

## 0. 现状速记（改代码前读）

| 项 | 位置 |
|----|------|
| PG 入队 / 抢单 / 完成 / 失败 | `backend/src/jobs/queue/pg.rs`（`FOR UPDATE SKIP LOCKED`） |
| `Queue` trait、`QueueStats` | `backend/src/jobs/queue/types.rs` |
| Worker 主循环、claim、`observe::generation_job` | `backend/src/jobs/worker/mod.rs` |
| 任务 REST 列表/摘要 | `backend/src/jobs/handlers/` |

`Queue::stats()` 已实现 **queued / running / dead** 计数，但 **未必** 有周期性导出或运维 HTTP 面 — 以下竖切补齐。

---

## 竖切 Q1：队列深度指标（低侵入）`(ops-only)`

**目标**：进程内周期性输出 **pending / running / dead**（调用现有 `stats()`），便于日志聚合与告警。

- [x] **Backend**：在 worker 中增加 **可配置间隔** `JOB_QUEUE_METRICS_INTERVAL_SECS`（默认 **60**；**0**=关闭），与 500ms 抢单 tick 解耦。
- [x] **Backend**：使用 `tracing::info!`（结构化字段：`pending`, `running`, `dead`, `worker_id`, `event=job_queue_metrics`）。
- [x] **Docs**：`backend/README.md` + `backend/.env.example` 已说明。

**验收**：本地起 worker + DB，日志中可见间隔性指标；无 DB 时行为与现 worker 一致（不 panic）。**无 Flutter 交付物**（本节 ops-only）。

---

## 竖切 Q2：「排队过久 / 按 kind」诊断 SQL 或只读 API

**目标**：支持排障：最老 **可认领** queued 年龄、24h 内 `failed`、**按 `kind` 分布**（与 worker 抢单语义一致）。

- [x] **方案 A（已落地）**：扩展 **`QueueStats`** + **`PgQueue::stats()`**：`pending_claimable`、`failed_last_24h`、`oldest_claimable_queued_age_secs`、`pending_by_kind_json`（至多 15 kind）；并入 **`job_queue_metrics`** 日志。**Flutter**：无（ops-only）；若上 **方案 B** REST 再单列全栈 WP）。
- [x] **与 H3 核对**：`assets-generate` payload v2 增加 **`project_uuid`** 不改变 **`kind`**；按 kind 聚合与 **`payload->>'project_numeric_id'`** 任务过滤仍有效（见 [**`assets-generate-job-payload-v2.md`**](./assets-generate-job-payload-v2.md)）。
- [x] **方案 B**（可选）：**Backend** `GET /api/v1/jobs/queue/stats` + **`TOONFLOW_INTERNAL_OPS_TOKEN` / `X-Toonflow-Internal-Token`** + OpenAPI + Flutter 只读卡片（`INTERNAL_OPS_TOKEN` dart-define）— 见 `backend/README.md`。
- [x] OpenAPI：已含 `getJobQueueStatsV1` / `JobQueueStatsResponse`。

**验收**：`cargo test` jobs 全绿；`yarn refactor:check`。

---

## 竖切 Q3：Runbook 文档（必做交付物）`(ops-only)`

**目标**：运维可复制粘贴执行：水平扩 worker、识别 **stuck `running`**、取消语义、与备份/迁移关系。

- [x] **Docs**：[**`jobs-pg-queue-runbook.md`**](./jobs-pg-queue-runbook.md)（指标字段、扩容、SQL、WP-A1 Gate、与 trace 关联）。
- [x] **Docs**：与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) **WP-B**、[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A0/A1** 交叉引用。

**验收**：Reviewer 按 Runbook 能在 staging 走通「扩副本 → 读 `job_queue_metrics` → 对照 SQL」。**无 Flutter**。

---

## 竖切 Q4：与 trace / `request_id` 对齐（与 harness WP-F 同里程碑收口）

**目标**：`generation.job.*` 与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F 一致时，job_id **已进入** `observe::generation_job`；本竖切核对 **日志字段可被日志管道 join**（字段名与 span 约定与 harness PR 一并合并）。

- [x] **Backend**：**`observe::generation_job`** 输出 **`event = generation_job_phase`** 的 **`info`** 结构化字段（**`job_id`**、**`user_id`**、**`kind`**、**`phase`**、**`worker_id`**、可选 **`client_request_id`**）；worker 全路径已传入 **`kind`** / **`worker_id`**。**`POST /api/v1/jobs`** 与带 **`HeaderMap`** 的 **`enqueue_generation_job`** 调用在 **`payload`** 未自带 id 时写入 **`X-Request-Id` → `client_request_id`**。
- [x] **Docs**：Runbook **§9** 已写 **`job_id`** / **`event`** 过滤与可选 **`client_request_id`** join。
- [ ] **Flutter**：若 harness PR 已暴露 **用户可见** trace/job 关联（如质量工作台），须同步 UI；否则本节 **Backend+Docs 为主**，与 harness WP-F 同一 PR 门禁。

**验收**：与 harness 观测 PR 同一门禁绿即可。

---

## 完成定义（DoD）

- [x] Q1 + Q2 方案 A + Q3 **已完成**。
- [x] Q4：**Backend + Runbook** 已完成「job 日志可 join」最小核对（**`generation_job_phase`**）；待 **harness WP-F** 或产品面再补 span / Flutter 可见关联。
- [x] [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A0** 可标「Runbook / 扩展指标 / Gate 模板已落地」（Q4 仍可与 harness 联调）。
- [x] `yarn refactor:check` 全绿（每批合并前执行）。
