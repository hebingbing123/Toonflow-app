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
