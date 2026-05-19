# 竖切任务：HTTP API 收敛 — **B·其余域**（按风险排序）

**主文档**：[`http-api-cleanup.md`](./http-api-cleanup.md)（清单、进度表、阶段 C–D）。  
**门禁**：每波合并 `yarn refactor:check`；契约三件套 **OpenAPI + contract_smoke + pg_contract**（涉及 DB 时）同 PR。

**全栈**：**H0** 可仅文档；**H1–H4** 凡改对外 REST/WS，**同一合并窗口**须 **`backend/` + `frontend/lib/rust_api` + 用户主路径 UI**（禁止只合 Rust）；与 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md) 一致。**H5** 以契约与删码为主，触 UI 则同上。

**优先级**（已替你排好）：先 **低耦合、易回滚** 的 HTTP/契约，再动 **jobs payload / worker**，最后 **Harness WS 与 REST 同一里程碑**，避免「REST 新、Agent 旧」断裂（见主文档 §七风险表）。

---

## 波次 H0：盘点与 parity 对齐（半日–1 日）

- [x] 对照 [`http-api-cleanup.md`](./http-api-cleanup.md) §四进度表，确认 **B·其余域** 子项在 [`electron-node-parity.md`](./electron-node-parity.md) 有对应行或子表（缺则补一行 🔀/备注）— **基线已读**；大改前须再 diff。
- [x] **`rg` 基线**：命令与热点文件计数快照见 [**`http-api-cleanup-h0-inventory.md`**](./http-api-cleanup-h0-inventory.md)（路径已更新为 `settings/agent_memory/` 目录）。
- [x] Flutter `rust_api`：同快照 §3；**文件 → 屏幕** 细表随 **H1** 在 Issue/PR 中展开。

**验收**：无代码行为变更或仅 docs；可单独 commit。

---

## 波次 H1：`settings::agent_memory` 请求体与文档（中风险）

**触点**：`backend/src/settings/agent_memory/`；Flutter `rust_api/agents/memory.dart`、`settings_memory_config_api.dart`、工作台 `agent_memory.dart`。

- [x] 产品/契约：**`projectUuid`**（`app_project.id`）与 legacy **`projectId`**（numeric）并存；OpenAPI 仍为 `serde_json::Value` 体/query 占位，行为以本仓库 REST 为准（H4 再收紧 Harness WS 矩阵）。
- [x] 后端：UUID 优先解析 + 旧体兼容；冲突时 **400**；无 DB smoke 下缺 id **400**（先于 503）；单测与契约 smoke 覆盖。
- [x] Flutter：主路径 **`projectUuid`**（列表匹配到 numeric 时）；仍支持仅 numeric（未匹配列表时）。
- [x] **Harness**：**H4** 已增加 **`projectUuid`** / **`scriptUuid`**（见 [`harness-ws-context-matrix.md`](./harness-ws-context-matrix.md)）。

**验收**：`yarn refactor:check`；相关 `contract_smoke` / widget 测试更新。

---

## 波次 H2：`scripting::asset_extract` 体字段（中风险）

**触点**：`backend/src/scripting/asset_extract/mod.rs`；调用方 `rust_api` + 工作台。

- [x] 设计：body 增加 **`project_uuid`**（**`app_project.id`**），保留 **`project_numeric_id`** 兼容；与 **`assets::resolve_owned_project_numeric_from_uuid_or_legacy_id`** 对齐（与 H1 同一解析语义）。
- [x] 后端 + OpenAPI（仍为 schema ref 路径；导出可解析）+ smoke（缺项目 **400**）。
- [x] Flutter 主路径发 **`project_uuid`**（有 UUID 时）；`startScriptAssetExtract` 仍接受 legacy numeric。

**验收**：同 H1。

---

## 波次 H3：`assets-generate` + `app_generation_job` payload（高风险，单独里程碑）

**触点**：`backend/src/assets/generate/handlers/*`、`backend/src/jobs/payload_project.rs`、`backend/src/jobs/worker/asset_image/*`、`asset_polish.rs`；队列 JSON payload。

- [x] **设计先行**：[**`assets-generate-job-payload-v2.md`**](./assets-generate-job-payload-v2.md)（版本号、双写、在途 v1、回滚）。
- [x] 实现：入队 **`payload_schema_version`: 2** + **`project_uuid`**（主语义）；worker 经 **`resolve_project_numeric_from_job_payload`** 兼容仅 numeric 的旧 payload。
- [x] OpenAPI：HTTP body 未改（仍为 camelCase projectId compat 入口）；队列 payload 为内部契约，目标语义已转向 **UUID-first** — parity 见设计文档与 `http-api-cleanup.md` §七。
- [x] 与 [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md) Q2：`pending_by_kind_json` 不按 payload 字段分组；`/jobs/page` 的 **`project_id`** 查询参数目前仍是 legacy numeric filter，因此兼容窗口内继续依赖 payload 中双写保留的 **`project_numeric_id`**，但不改变整体 **UUID-first** 收敛方向。

**验收**：`yarn refactor:check`；staging 长跑生成任务建议在发布说明中勾选（本仓库 CI 以门禁为准）。

---

## 波次 H4：Harness HTTP / WS 上下文与整型 id（高风险，与 H1/H2 收口）

**触点**：`backend/src/harness/http.rs`、`backend/src/harness/invoke/domain_*.rs`、`docs/websocket-events.md`、Flutter `agent_workspaces`。

- [x] 书面矩阵：每个 attach 字段 **REST 来源** vs **WS 载荷** vs **DB 列（legacy_id）** — [`harness-ws-context-matrix.md`](./harness-ws-context-matrix.md)。
- [x] 实现：WS **`projectUuid`** / **`scriptUuid`** + legacy **`project_id`** / **`script_id`**；有 PG 时校验归属（numeric-only 路径由 [`attach_resolve.rs`](../../backend/src/harness/ws/attach_resolve.rs) 收敛）。
- [x] Flutter：`agent_workspaces` attach 双写 UUID（可选字段）+ numeric。
- [x] **禁止**：仅合并 REST 而不合并 WS 客户端可用路径 — 本里程碑 Rust + Flutter 同 PR 门禁。

**验收**：Harness 相关测试 + 手工 WS 探针清单；`yarn refactor:check`。

---

## 波次 H5：阶段 C–D（仅主文档排期后动）

- [ ] **C**：删除已无注册的死模块（主文档 §四「C–D 未做」）— **每删一批** 跑全门禁 + parity diff。
  - [x] **C0（模块根冲突）**：删除与 **`transformation/`**、**`performance_rework/`** 子目录并存的遗留顶层 **`transformation.rs`** / **`performance_rework.rs`**（否则 `mod foo` 只加载顶层文件，拆分目录被静默忽略）。
  - [x] **C1（测试重导出噪音）**：**`memory/style_selection/mod.rs`** 去掉未被子测试经 **`generate::`** 引用的 **`#[cfg(test)] pub(in generate) use …`** 项，避免 `cargo clippy --all-targets --all-features` 下 **unused_imports**（默认门禁仍为 `clippy` 无 `--all-features`）。
  - [x] **C2（cfg / sqlx / dead_code 小修）**：`Cargo.toml` 声明 **`migrate`** 空 feature（`check-cfg`）；**`sqlx`** 依赖增加 **`migrate`**（`#[sqlx::test]` + `PgPool` 在 **`--features migrate`** 下可用）；**`callback_validation_tests`** 修正 **`#[cfg(all(test, feature = "migrate"))]`** 多余括号笔误；**`dialogue_risk` / `observation`** 未接线符号改 **`#[allow(dead_code)]`**；**`e2e_regression_suite`** 忽略用例 **`_token`** + **`E2ETestContext`** **`#[allow(dead_code)]`**。
  - [x] **C3（all-features clippy）**：清理 **`cargo clippy --all-targets --all-features -D warnings`** 下的一批 lint（测试常量 assert、URI needless borrow、`module_inception`、视频生成测试 **`type_complexity`** 等）；提交 **`b306fe98`**。
  - [x] **C4（未注册孤儿模块）**：删除 **`backend/src/services/video_encoder.rs`**（仅文件存在、未在 `services/mod.rs` 声明、模块树不可达、全仓无 `video_encoder` 调用点），避免后续误接线或重复实现。
  - [x] **C5（窄域路由导出收口）**：在 `app/router`、`projects/routes`、`production/workbench/track`、`scripting/scripts` 及直接关联做窄扫描；确认本轮（含本次复扫）无“可安全整文件删除”的未注册孤儿模块。删除 `backend/src/production/workbench/track/mod.rs` 中未注册且无调用的 `batch-select-video` re-export（`__path_post_workbench_batch_select_video`、`post_workbench_batch_select_video`），保留 `videos.rs` 实现体待后续功能决策，避免误删潜在预留能力。
  - [x] **C6（遗留 `.backup` 源文件）**：删除 `backend/src/production/workbench/video/generate.rs.backup`、`video_prompt_memory/mod.rs.backup`（未参与模块树，体积大且易与主线漂移）。
- [ ] **D**：删 PG `legacy_id` 列 — **独立窗口**；依赖 `import_staging` / promote 方案（见主文档 §七）。
  - **D 批次当前状态（2025-01-27 更新）**：
    - ✅ **依赖盘点完成**（H3.1/H3.2）：Flutter `rust_api` 与主路径 UI 已完成 UUID-first 迁移；`storyboard_editor`、`script_editor`、`short_video_space` 生产 API 调用均已 UUID-only。
    - ✅ **后端分析完成**（H3.3）：所有 handler 均已实现 UUID-first + numeric fallback 双路径；无可安全移除的 legacy-only handler。
    - ✅ **OpenAPI 废弃注解已添加**（H3.4）：`{script_numeric_id}`、`{storyboard_numeric_id}`、`{novel_numeric_id}`、`{asset_numeric_id}` 路径参数已在合并管道（`openapi_spec/merge/overlay.rs`）中标注 `deprecated: true`，并附迁移说明；`cargo run --bin export-openapi` 验证通过。
    - ✅ **数据迁移评估完成**（H3.5）：创建 `supabase/migrations/20260527120000_backfill_job_payload_project_uuid.sql`，将 `project_uuid` 回填到仅含 `project_numeric_id` 的 `app_generation_job` payload 中（安全、幂等、仅增量）；评估文档见 `.tmp/H3.5_migration_evaluation.md`。
    - 🔴 **列删除仍阻塞**：`promote_import_snapshots()` 函数以 `numeric_id` 为冲突解析键（无 UUID-based import 路径）；`pg_contract_tests` 验证 numeric ID 行为。列删除需独立发布窗口 + DBA 评估（预计 6-9 个月）。

**验收**：单独发布说明 + DBA 签字类流程（若适用）。

---

## 建议排期顺序（复制到周计划）

1. **H0** → **H1** → **H2**（可部分并行不同人，但 H1/H4 WS 需同周对齐）。  
2. **H3** 独占 1 个里程碑，避免与 H2 同周混压。  
3. **H4** 与 H1 尾部或 H3 前完成第一轮矩阵，避免断裂期过长。  
4. **H5** 仅在 B·其余域打勾后再开 kickoff。
