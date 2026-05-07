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

**触点**：`backend/src/settings/agent_memory.rs`；Flutter `settings_memory_config_api.dart` / 工作台 `agent_memory.dart`。

- [ ] 产品/契约：是否引入 **`project_id` UUID** 与旧整型 **并存期**； deprecation 策略写 OpenAPI。
- [ ] 后端：实现 UUID 优先解析 + 旧体兼容（若仍需要）；单测覆盖。
- [ ] Flutter：主路径改新体；折叠区保留兼容调用直至删除日。
- [ ] **Harness**：若 Agent attach 仍传整型项目 id，在本波或 **H4** 同一里程碑内定义 **WS `agent.context.update`** 是否增加 `projectUuid`（见主文档 §七）。

**验收**：`yarn refactor:check`；相关 `contract_smoke` / widget 测试更新。

---

## 波次 H2：`scripting::asset_extract` 体字段（中风险）

**触点**：`backend/src/scripting/asset_extract/mod.rs`；调用方 `rust_api` + 工作台。

- [ ] 设计：body 从 **`project_numeric_id`** 迁到 **UUID 项目 id**（或 query 与 path 统一）。
- [ ] 后端 + OpenAPI + smoke。
- [ ] Flutter 全主路径切换；删除或 deprecate 旧 helper。

**验收**：同 H1。

---

## 波次 H3：`assets-generate` + `app_generation_job` payload（高风险，单独里程碑）

**触点**：`backend/src/assets/generate.rs`、`backend/src/jobs/worker/*.rs`、队列 JSON payload。

- [ ] **设计先行**（1 页即可）：payload **版本号**、双写期、在途任务兼容、回滚。
- [ ] 实现：worker 同时识别 v1/v2 payload 或迁移脚本清空队列窗口。
- [ ] OpenAPI + parity 表「队列语义」行更新。
- [ ] 与 [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md) Q2 协调：改 schema 后指标查询仍正确。

**验收**：压测或 staging 长跑一批生成任务；`yarn refactor:check`。

---

## 波次 H4：Harness HTTP / WS 上下文与整型 id（高风险，与 H1/H2 收口）

**触点**：`backend/src/harness/http.rs`、`backend/src/harness/invoke/domain_*.rs`、`docs/websocket-events.md`、Flutter `agent_workspaces`。

- [ ] 书面矩阵：每个 attach 字段 **REST 来源** vs **WS 载荷** vs **DB 列（legacy_id）**。
- [ ] 实现：按矩阵补 UUID 或统一「仅 UUID path + 内部 resolve legacy」。
- [ ] Flutter：attach 与工具探测参数同步改。
- [ ] **禁止**：仅合并 REST 而不合并 WS 客户端可用路径。

**验收**：Harness 相关测试 + 手工 WS 探针清单；`yarn refactor:check`。

---

## 波次 H5：阶段 C–D（仅主文档排期后动）

- [ ] **C**：删除已无注册的死模块（主文档 §四「C–D 未做」）— **每删一批** 跑全门禁 + parity diff。
- [ ] **D**：删 PG `legacy_id` 列 — **独立窗口**；依赖 `import_staging` / promote 方案（见主文档 §七）。

**验收**：单独发布说明 + DBA 签字类流程（若适用）。

---

## 建议排期顺序（复制到周计划）

1. **H0** → **H1** → **H2**（可部分并行不同人，但 H1/H4 WS 需同周对齐）。  
2. **H3** 独占 1 个里程碑，避免与 H2 同周混压。  
3. **H4** 与 H1 尾部或 H3 前完成第一轮矩阵，避免断裂期过长。  
4. **H5** 仅在 B·其余域打勾后再开 kickoff。
