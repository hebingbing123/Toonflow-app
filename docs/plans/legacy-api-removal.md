# Legacy API 收敛 / 移除计划

## 目标与边界

在 **无旧 Electron/Node 线上服务**、**客户端与数据可控** 的前提下，将「为旧 SQLite / 旧路由形状保留的 HTTP 面」逐步收敛为 **仅保留一套清晰的新契约**（以 UUID + REST 为主），并减少心智负担与重复实现。

**注意**：Postgres 表中的列名 **`legacy_id`（整型）** 与 HTTP 路径里的 **`/legacy/`` 不是同一概念。

- **列 `legacy_id`**：迁移与排序、对账时常仍有用；是否删除列属于 **Schema 迁移**，需单独设计，可与 HTTP 收敛 **并行或后置**。
- **路径 `/api/v1/.../legacy/{id}`**：属于 **对外 API 形状**；收敛时优先改客户端调用，再删路由。

## 为何不能「一键删目录」

- **Flutter** 仍广泛调用 `projects/legacy`、`novels_legacy_api`、`projects_legacy_compat`、各 `compatibility/` 与 `legacy/` probe（见 `frontend/lib/rust_api/*`、`home_page/project_editor/**`）。
- **OpenAPI / `contract_smoke_tests` / `pg_contract_tests`** 将上述路径列为契约与回归真源。
- **路线图**（`docs/plans/harness-rust-flutter.md`）已记录「parity / 正式工作台 + 兼容折叠区」并存形态；去掉 legacy 前需 **产品确认**：哪些折叠区可删、哪些正式入口已 100% 覆盖旧能力。

## 推荐实施顺序（全栈一起动，但分波交付）

### 波 0：冻结现状（1–2 天）

- 列出 **所有** 含 `legacy` 的 **HTTP 路由**（`backend/src/app/router.rs` 与各 `::legacy::router`）。
- 列出 **Flutter** 侧每个 legacy 调用的 **唯一调用点**（按 feature 分组）。
- 在 OpenAPI 中为「拟废弃」路径打 **`deprecated: true`**（可选，便于代码检索与客户端告警）。

### 波 1：选一条竖切试点（建议：项目下资源只读 → 再写）

- 例如：**项目资产** 已以 `GET/POST/PATCH …/projects/legacy/{id}/assets` 为主；先保证 **仅 UUID 路径**（若后端尚无则补）与 **Flutter 主路径** 切换，再标记旧路径 deprecated，最后删路由与测试。
- 验收：`yarn refactor:check`、关键 `pg_contract_tests` 场景更新或替换。

### 波 2：小说 / 事件 / 任务 等同理

- `narrative::legacy`、`rest_legacy::tasks`、`projects::legacy` 等按 **调用量与风险** 排序；每波：**后端双轨（短期）→ 前端切换 → 删旧轨**。

### 波 3：生产 / 脚本 legacy

- `production_legacy`、`scripting::legacy` 工作量大，建议在所有 CRUD 竖切完成后再动。

### 波 4：Schema（可选）

- 若产品确认 **永不再暴露整型 id**，再评估：`legacy_id` 列保留（内部）、或只读、或迁移脚本后删除 —— **需备份与迁移窗口**。

## 门禁

- 每波合并前：**OpenAPI 可解析**、**契约/烟雾测试更新**、**Flutter analyze** 通过（与 `scripts/refactor-check.sh` 一致）。
- 禁止「只删后端路由、客户端未改」的合并。

## 与 `master` 的关系

`master` 仅作 **历史对照**；移除 legacy **不以恢复 master 代码为目标**，而以 **当前仓库契约 + 产品行为** 为准。

---

*文档版本：随首波试点更新 checklist 与路径表。*
