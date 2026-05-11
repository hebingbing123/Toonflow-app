# HTTP API 收敛 — **H0** 盘点快照（B·其余域）

**主清单**：[**`tasks-http-api-cleanup.md`**](./tasks-http-api-cleanup.md) · **主文档**：[**`http-api-cleanup.md`**](./http-api-cleanup.md) · **Parity**：[**`electron-node-parity.md`**](./electron-node-parity.md)。

**目的**：为 **H1–H4** 全栈竖切提供「仍含整型 / 旧字段名」的 **可重复检索基线**；本文件 **不替代** `rg`，合并大改前请重跑下列命令并 diff。

---

## 1. 重跑命令（仓库根）

```bash
# Backend：asset_extract、jobs worker、相关域
rg -n "project_numeric_id|project_legacy_id|projectId" \
  backend/src/scripting/asset_extract \
  backend/src/settings/agent_memory \
  backend/src/assets/generate.rs \
  backend/src/jobs

# Flutter API 层（优先改 rust_api，再改工作台）
rg -n "project_numeric_id|project_legacy_id|projectId" \
  frontend/lib/rust_api
```

（`backend/src/assets/generate.rs` 若路径变化，改为 `rg backend/src/assets -g'*.rs' …`。）

---

## 2. 快照日期与说明

| 项 | 内容 |
|----|------|
| **快照日期** | 2026-05-07（随 PR 更新本表时请改日期） |
| **Parity** | 已对照 **`http-api-cleanup.md` §四**「B·其余域」行；**`electron-node-parity.md`** 中与 **整型 body / 队列 payload** 相关行须在 H3/H4 合并时同步更新。 |
| **agent_memory 路径** | 现为 **`backend/src/settings/agent_memory/**`**（非单文件 `agent_memory.rs`）。 |

---

## 3. `rg` 命中计数（快照，非穷尽解释）

> 数字为 **`rg -c`** 每文件匹配次数；用于判断 **热点文件**，不等于「必须改行数」。

### Backend（节选）

| 路径 | 近似命中 |
|------|-----------|
| `scripting/asset_extract/mod.rs` | 6 |
| `jobs/worker/asset_polish.rs` | 10 |
| `jobs/worker/voiceover.rs` | 8 |
| `jobs/worker/asset_image/generate.rs` | 5 |
| `jobs/worker/video/export.rs` | 6 |
| `jobs/worker/asset_image/batch.rs` | 6 |
| … | （完整列表以本地 `rg` 为准） |

### `frontend/lib/rust_api`（节选）

| 路径 | 近似命中 |
|------|-----------|
| `project/publish_api.dart` | 40 |
| `novels/rest_api.dart` | 23 |
| `production/routes.dart` | 21 |
| `assets/crud.dart` | 14 |
| `agents/memory.dart` | 13 |
| … | （完整列表以本地 `rg` 为准） |

---

## 4. H0 完成定义

- [x] **本快照文件**已入库；**维护者**须在 **H1 kickoff 前** 重跑 §1 并更新 §3 表格或附 PR 链接。
- [x] **`electron-node-parity.md`** 与 **`http-api-cleanup.md` §四** 已作为权威交叉阅读（逐行补 **🔀** 可与 **H1 同一 PR** 完成）。
- [x] **H1** 可引用本文件作 `rg` 基线。

---

*下一自动步骤：在单独 PR 中启动 **H1**（`settings/agent_memory` + Flutter memory + OpenAPI），仍须 **全栈同窗口**。*

---

## 5. D 波次 kickoff（2026-05-11）

> 结论先行：**D = schema + 队列 + 导入链路的联合窗口**，不能被当成“顺手删几个列名”的小清理。

### 5.1 已确认的阻塞面

- **Flutter 主路径/ops 面仍依赖整型兼容字段**：
  - `frontend/lib/rust_api/production/**` 大量请求体仍直接发送 `projectId` / `scriptId`
  - `frontend/lib/task_center/**` 深链与筛选仍读取 `project_numeric_id` / `script_numeric_id` / `storyboard_numeric_id`
  - `frontend/lib/agent_workspaces/**` 控制器与 attach 辅助仍保留 `projectIdController` / `numeric_id` 读法
- **后端 production / jobs / scope 仍以 numeric 语义为核心桥梁**：
  - `backend/src/production/flow_data/**`、`backend/src/scope/**`、`backend/src/jobs/worker/asset_image/**` 仍大量以 `project_numeric_id` / `script_numeric_id` / `asset_numeric_id` 串联路由、worker 与结果回写
  - `backend/src/jobs/notifications.rs`、`workspaces/ops_stats.rs`、jobs summary 仍读取 payload 中的 `project_numeric_id`
- **导入与 staging/promote 链路仍明确依赖历史/整型标识**：
  - `backend/src/bin/sqlite_import.rs` 继续写 `import_staging.snapshot`
  - `supabase/migrations/20260420120000_rename_legacy_staging_to_import_staging.sql` 之后的 `promote_import_snapshots()` 虽已把多数表切到 `numeric_id`，但导入映射仍以旧 SQLite id 为幂等锚点
  - 旧迁移文件与文档审计轨迹仍大量出现 `legacy_id` / `promote_legacy_from_staging()`，不能直接改写历史迁移，只能追加迁移
- **PG 契约测试目前大量把 `numeric_id` 当稳定测试锚点**：
  - `backend/src/app/pg_contract_tests/**` 广泛以 `created["numeric_id"]`、`DELETE ... WHERE numeric_id = $1`、`import_staging.snapshot` 清理为基准

### 5.2 对 D 波次的落地拆分建议

1. **先清客户端与 HTTP/worker 兼容面**：优先收 production、task center、agent workspaces 与 jobs deep-link/payload 的 numeric 依赖。
2. **再补 schema 设计**：明确哪些 `numeric_id` 继续保留为可读兼容 id，哪些 `legacy_id` 列才是真正可删对象。
3. **最后单独做迁移窗口**：新增 migration/backfill + `pg_contract_tests` 改造 + runbook/回滚说明，同窗完成，不与普通功能 PR 混压。

### 5.3 当前状态

- `tasks-http-api-cleanup.md` 的 **H5·D** 仍保持“独立窗口”
- `.kiro/specs/platform-completion-phase2/tasks.md` 已把 **H3** 从 `pending` 推进为 `in_progress`
- 本次仅完成 **盘点/落档**，**未执行 schema 变更**
