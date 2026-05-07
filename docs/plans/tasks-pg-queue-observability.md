# 竖切任务：PG 任务队列观测与容量（WP-A0）

**母路线**：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) **WP-A0**、[`harness-rust-flutter.md`](./harness-rust-flutter.md) §7.1（PG 为默认真源）。  
**门禁**：每合并一批涉及 `backend/` 的改动前跑 `yarn refactor:check`。

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

## 竖切 Q1：队列深度指标（低侵入）

**目标**：进程内周期性输出 **pending / running / dead**（调用现有 `stats()`），便于日志聚合与告警。

- [ ] 在 worker 或独立轻量任务中增加 **可配置间隔**（如 `JOB_QUEUE_METRICS_INTERVAL_SECS`，默认 60；0=关闭），避免每 500ms tick 打 DB。
- [ ] 使用 `tracing::info!`（结构化字段：`pending`, `running`, `dead`, `worker_id`）与现有 `worker_id_label()` 一致。
- [ ] 文档：环境变量说明写入下方 Runbook 或 `backend/README.md` 小节。

**验收**：本地起 worker + DB，日志中可见间隔性指标；无 DB 时行为与现 worker 一致（不 panic）。

---

## 竖切 Q2：「排队过久 / 按 kind」诊断 SQL 或只读 API

**目标**：支持排障：最老 `queued` 年龄、`failed` 近窗计数、**按 `kind` 分组** pending（可二选一或分两 PR）。

- [ ] **方案 A（推荐先做）**：扩展 `QueueStats` + `pg.rs` 单次查询（或第二个 `stats_extended()`），增加：`oldest_queued_age_secs`、`optional: top kinds json`。
- [ ] **方案 B**：新增内部运维 REST（如 `GET /api/v1/jobs/queue-metrics`，**强鉴权** / 仅 admin — 若尚无 admin 角色则先只做日志+Q1，避免暴露面扩大）。
- [ ] OpenAPI：若走 REST，必须更新导出与 `contract_smoke` 最小用例。

**验收**：`cargo test` jobs 相关；若动 OpenAPI，`yarn refactor:check`。

---

## 竖切 Q3：Runbook 文档（必做交付物）

**目标**：运维可复制粘贴执行：水平扩 worker、识别 **stuck `running`**、取消语义、与备份/迁移关系。

- [ ] 新建 `docs/plans/jobs-pg-queue-runbook.md`（或并入 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) WP-B 交叉链）。
- [ ] 章节至少包含：连接串与 worker 副本数、`SKIP LOCKED` 行为说明、`claimed_by` / 取消路径、**stuck running** 人工处理 SQL 模板、与 `GET /api/v1/jobs*` 对照读法。
- [ ] **WP-A1 Gate**：书面阈值模板（例：p95 claim 延迟、PG 锁等待、写入 TPS）— 满足哪些指标才开 Redis/云队列评审。

**验收**：Reviewer 按 Runbook 能在 staging 走通一遍「扩副本 → 压测 → 读指标」。

---

## 竖切 Q4：与 trace / `request_id` 对齐（与 harness WP-F 同里程碑收口）

**目标**：`generation.job.*` 与 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F 一致时，job_id **已进入** `observe::generation_job`；本竖切核对 **日志字段可被日志管道 join**（字段名与 span 约定与 harness PR 一并合并）。

- [ ] 核对 `observe` 与 worker 路径字段名；若缺 `job_id`/`kind` 统一键名，小补 `tracing` span。
- [ ] 在 Runbook 中写一句：如何在集中日志里按 `job_id` 过滤。

**验收**：与 harness 观测 PR 同一门禁绿即可。

---

## 完成定义（DoD）

- [ ] Q1 + Q3 **必完成**；Q2 至少完成 **方案 A 或 B 之一**。
- [ ] Q4：若 harness WP-F 已合并，则 **同一发布窗口** 内完成本清单字段核对；否则单独 PR 完成「job 日志可 join」最小核对，Runbook 注明待 WP-F 联调项。
- [ ] [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) WP-A0 表格可打勾「Runbook / 指标 / Gate 模板已落地」。
- [ ] `yarn refactor:check` 全绿。
