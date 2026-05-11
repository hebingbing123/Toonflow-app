# HTTP API 收敛 / 移除跟踪（原 SQLite/Electron 对齐面）

**竖切执行清单（B·其余域，已排优先级）**：[**`tasks-http-api-cleanup.md`**](./tasks-http-api-cleanup.md) · **H0 快照**：[**`http-api-cleanup-h0-inventory.md`**](./http-api-cleanup-h0-inventory.md)。  
**全栈**：每波须满足 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)（Rust + Flutter + 契约同窗口，除非 `tasks-http-api-cleanup` 标明 H0/docs-only）。

**范围说明（避免误解「一次做完本文档」）**：§一–§三多为**清单与依赖图**；§四进度表中 **C–D**（整棵 `*历史*` HTTP 模块删除、PG 删 **`legacy_id` 列**）与 **B·其余域**（**`harness`/jobs 整型 payload、`asset_extract` 体字段、`assets-generate` 队列语义** 等；**资产侧**：顶层 **`POST /api/v1/assets/*` 已删除**，兼容写读已收拢到 **`POST …/projects/{project_id}/assets/workbench/*`**）属于**多里程碑工程**，无法在单次门禁/提交内安全清空。实施时以 **阶段 B 按域竖切**为单位推进，每域通过后 **`yarn refactor:check`** 再合并。

## 术语（避免混谈）

> 术语约定：文档中新提法优先使用 **historical/import-era**；已发布迁移文件中的 `legacy_*` 名称视为历史审计轨迹，不做回写修改。见 `docs/plans/database-migration-history-policy.md`。

| 概念 | 含义 | 收敛难度 |
|------|------|----------|
| **HTTP 源码目录曾带 `历史` 字样** | ~~`narrative::历史`~~（已删）；制作域已更名为 **`production`**；资产工作台实现已迁至 **`assets/workbench_write`**、**`assets/workbench_query`** | 中：OpenAPI 路径参数名仍常见 `*_legacy_id`（DB 列语义） |
| **URL 字面段 `/…/历史/…`** | ~~`GET /api/v1/art-styles/历史/1`~~ → **`GET /api/v1/art-styles/numeric/{numeric_id}`**（画风） | 低–中：其余资源多以 path 参数名表达整型 id，而非字面 **`历史`** 段 |
| **请求体旧形状** | `projectId`、`camelCase` 与旧 Electron 对齐的 POST | 中：需换客户端 body + 后端 handler |
| **列 `legacy_id`（PG）** | 各 `app_*` 表常见整型外键/排序 | 低–高：属 **Schema**，可与 HTTP 分阶段 |
| **迁移工具 `toonflow-sqlite-import`** | `backend/src/bin/sqlite_import.rs` | 通常 **保留**（离线 SQLite → staging，非在线 HTTP） |

---

## 一、后端涉及文件（按目录）

### 1. 路由入口（改动时必看）

| 文件 | 说明 |
|------|------|
| `backend/src/app/router.rs` | ~~`rest_legacy::*`~~ **已移除**；~~**`narrative::历史`**~~ **已移除**；~~**`scripting::历史`**~~ **已并入 `scripting::scripts`**；**`production::router()`**（**`/api/v1/production/*`**） |
| `backend/src/main.rs` | 顶层 **`mod production`**、**`mod production_flow`** 等 |

### 2. 独立 历史 路由模块（整棵可随「该域下线」删除）

| 路径 | 职责摘要 |
|------|----------|
| ~~`backend/src/projects/历史.rs`~~ | **已删除**（原 **`POST /api/v1/project/get-project`** 等）；项目 CRUD 仅 **`projects/routes.rs`**（**`/api/v1/projects`**） |
| `backend/src/projects/mod.rs` | 仅 **`pub mod routes`** |
| ~~`backend/src/narrative/历史/*`~~ | **已删除**（原 **`/api/v1/novels/*`**）；事件生成迁至 **`POST …/projects/{project_id}/novel-events/generate-events`**；`novels_workbench_http` / `novels_events` 的 **`postLegacy*`** 为 Dart 侧兼容包装，内部走 **`/api/v1/projects/{uuid}/novels*`** 与 **`…/novel-events*`** |
| `backend/src/narrative/mod.rs` | **`novels` / `events` / `storyboards`**（无 `历史`） |
| `backend/src/production/mod.rs` | **`POST /api/v1/production/*`** 路由表 |
| `backend/src/production/workbench/*.rs` | flow、storyboard、assets、video、edit_image… |
| ~~`backend/src/rest_legacy/*`~~ | **已删除**（原 **`POST /api/v1/general/*`**、**`POST /api/v1/tasks/*`**）；任务中心改 **`GET /api/v1/jobs/page`**、**`GET …/jobs/task-detail/{task_id}`** 等 |
| ~~`backend/src/scripting/历史.rs`~~ | **已删除**；**`POST …/projects/{project_id}/scripts/get-script-api`** 现由 **`scripting/scripts.rs`** 注册 |
| `backend/src/scripting/mod.rs` | **`agent` / `asset_extract` / `scripts`**（无 `历史` 子模块） |
| `backend/src/assets/workbench_write.rs` | 资产 **workbench 写路径** handler（**`POST …/projects/{project_id}/assets/workbench/{add,save,update,del,batch-delete,del-image}-assets`**）；**已删除**顶层 **`POST /api/v1/assets/*`** 注册 |
| `backend/src/assets/workbench_query/mod.rs` | workbench **读路径** re-export（nested、image-bundle、material、polling、batch_generation、upload_clip） |
| `backend/src/assets/workbench_query/*.rs` | 各 **`post_project_workbench_*`** 实现（语义对齐旧 **`get-assets-api`/`get-image`/…**，**`project_id`** 在 path，body 不再带整型 **`projectId`**） |
| `backend/src/assets/mod.rs` | 注册 **`…/assets/workbench/*`**（须在 **`{asset_legacy_id}`** 动态段之前）；`mod workbench_write`、`mod workbench_query`、单元测试 |

### 3. 路径含 `历史`、但**不在**上述 `历史` 目录的 REST（收敛时要同步 OpenAPI + Flutter）

| 路径 | 说明 |
|------|------|
| `backend/src/narrative/novels/*` | **主路径**：`GET\|POST /api/v1/projects/{project_id}/novels`，`GET\|PATCH\|DELETE …/novels/{novel_legacy_id}`（UUID 项目段；**`novel_legacy_id`** 仍为 **`app_novel.legacy_id`**）。**已删除** `…/projects/历史/{id}/novels*` |
| `backend/src/narrative/events/*` | **主路径**：`GET\|POST /api/v1/projects/{project_id}/novel-events`，`PATCH\|DELETE …/novel-events/{event_legacy_id}`，`POST …/batch-delete`。**已删除** `…/projects/历史/{id}/novel-events*` 与 **`POST /api/v1/novels/events/*`** |
| `backend/src/narrative/storyboards/*` | **主路径**：`…/projects/{project_id}/scripts/{script_legacy_id}/storyboards`、`…/projects/{project_id}/storyboards/{storyboard_legacy_id}`。**已删除** `…/scripts/历史/.../storyboards` 与 **`…/storyboards/历史/{id}`** |

### 4. 其它后端引用（制作域与 Harness）

| 文件 | 说明 |
|------|------|
| `backend/src/production_flow.rs` | 制作流程 JSON 加载、**`resolve_owned_production_scope`**（Harness + **`get-flow-data` / `save-flow-data`** / edit-image 上传归属校验） |
| `backend/src/harness/invoke/domain_production.rs` | **`crate::production_flow::load_owned_production_flow_json`**（与 **`/api/v1/production/get-flow-data`** 同源实现） |
| `backend/src/harness/invoke/domain_script.rs`（及同目录其它域） | 工具入参/上下文普遍假设 **项目/剧本/小说 `legacy_id`**；HTTP 改 UUID 时须同步 **WS attach / `agent.context.update` 契约与实现**（见 `docs/websocket-events.md`） |

### 5. 契约与集成测试

| 路径 | 说明 |
|------|------|
| `backend/src/app/contract_smoke_tests/production_http_smoke.rs` | 烟雾：**`/api/v1/production/*`**（无 DB → **503** 等） |
| `backend/src/app/contract_smoke_tests/skills_workbench_asset_posts.rs` | 烟雾：skills + workbench 资产 POST |
| `backend/src/app/contract_smoke_tests/asset_jobs_tasks_smoke.rs` | 烟雾：资产/jobs/tasks/project POST |
| `backend/src/app/contract_smoke_tests/*.rs`（其余） | 部分用例仍断言整型 id / 已删除的旧路径片段 |
| `backend/src/app/pg_contract_tests/mod.rs` 及 `*_suite.rs` | 需 DB 的契约；大量 `projects/历史`、`legacy_id` |

### 6. 数据迁移 CLI（一般**不**随 HTTP 历史 删除）

| 文件 | 说明 |
|------|------|
| `backend/src/bin/sqlite_import.rs` | SQLite → PG staging 导入 CLI（**`cargo run --bin toonflow-sqlite-import`**），**不等于**在线 HTTP |

### 7. 非 `*历史*` 目录名、但 URL 或 body 仍绑整型 `legacy_id`（易漏）

| 路径 | 说明 |
|------|------|
| `backend/src/projects/routes.rs` | **主路径**：`GET`/`PATCH`/`DELETE /api/v1/projects/{project_id}`、`GET …/stats`（UUID）。**已删除** `GET`/`PATCH`/`DELETE …/projects/历史/{legacy_id}` 与 `GET …/projects/历史/{legacy_id}/stats`（与竖切 1 对齐） |
| `backend/src/manuals/art_styles/*.rs` | `GET`/`PATCH`/`DELETE /api/v1/art-styles/numeric/{numeric_id}`、`GET …/numeric/{numeric_id}/cover`（磁盘文件名仍用 DB **`legacy_id`**，见 `AppState` 注释） |
| `backend/src/prompting/prompts/*.rs` | `GET`/`PATCH /api/v1/prompts/{numeric_id}`（对齐旧 `o_prompt.id` 1–3） |
| `backend/src/scripting/scripts.rs` | **主路径**：`POST …/projects/{project_id}/scripts`、`POST …/projects/{project_id}/scripts/batch-add`，`GET`/`PATCH`/`DELETE …/projects/{project_id}/scripts/{script_legacy_id}`。**已删除** `…/projects/历史/{id}/scripts` 与 **`…/scripts/历史/{id}`**（剧本本体 `GET`/`PATCH`/`DELETE`）；分镜列表/创建见 **`narrative/storyboards`** UUID 路径。旧 `POST …/scripts/batch-add` 已移除 |
| `backend/src/scripting/asset_extract/mod.rs` | 请求体 **`project_uuid`**（优先）+ legacy **`project_numeric_id`** + **`script_numeric_ids[]`** |
| `backend/src/assets/generate/handlers/*` | HTTP **`projectId`** 仍为 **`app_project.numeric_id`**（camelCase）；入队 payload **v2** 含 **`payload_schema_version`**、**`project_uuid`** + **`project_numeric_id`**（双写）；worker 见 [**`assets-generate-job-payload-v2.md`**](./assets-generate-job-payload-v2.md)；`cancel-generate` 仍按任务 **`id`**（numeric）协同取消 |
| `backend/src/settings/agent_memory.rs` | `project_id: i32`（**项目 历史 id**）+ `episodes_id` 等驼峰体；与 Harness/工作台「按 历史 项目」一致 |
| `backend/src/jobs/worker/*.rs`（如 `asset_image.rs`） | 生成结果回写、`/file` URL 模板中含 `project_legacy_id` / `asset_legacy_id` |

### 8. `app/router.rs` 全量 `merge` 与 历史 的隐性耦合

下列模块**不一定**在路径里写 `历史`，但常与上表或队列 payload 联动；收敛 HTTP 时勿只盯 `*历史*` 子模块：

| `merge` 项 | 与 历史 的关系 |
|------------|-------------------|
| `harness::http::router()` | `HarnessContext` 含 **`project_legacy_id` / `script_legacy_id`**；`harness/invoke/domain_*.rs` 大量 `p.legacy_id` SQL |
| `jobs::router()` | 任务行含 **`legacy_task_id`**；payload 常含 asset/script 整型 id |
| `settings::agent_memory::router()` | 见 §7 **`agent_memory.rs`** |
| `projects::routes::router()` | 见 §7 **`projects/routes.rs`** |
| `manuals::{director, art_styles, visual}` | 画风 **`/art-styles/numeric/...`**；手册域需单独 grep 整型 id 语义 |
| `scripting::{scripts, agent, asset_extract}` | scripts 路径见 §7；**`asset_extract`** 体字段 |
| `metering::usage`、`billing::router()` | 自行检索是否仍传 **`projectId`（整型）** 或仅 UUID |

### 9. Staging / 提升（非 HTTP，但与 `legacy_id` 列同源）

| 路径 | 说明 |
|------|------|
| `supabase/migrations/*` + `import_staging` / `promote_import_snapshots()` | PG 契约与 **`pg_contract_tests`** 大量依赖；**删列 `legacy_id`** 前必须与此链路一起设计 |
| `backend/src/app/pg_contract_tests/mod.rs` 等 | 显式使用隔离用 **`legacy_id` 区间**、清理 `import_staging` |

---

## 二、前端涉及文件（`历史` 字符串命中；含 URL/字段/目录名）

以下为 **`frontend/lib` 下 `*.dart` 且包含 `历史` 的清单**（用于全量替换/收敛时检索；部分仅为注释或 `legacyId` 字段名）。

### `rust_api/`（API 封装层，优先改）

- `rust_api/assets_api.dart`
- `rust_api/assets_crud.dart`
- `rust_api/assets_generate.dart`
- `rust_api/assets_images.dart`
- `rust_api/assets_models.dart`
- `rust_api/art_styles.dart`
- `rust_api/catalog_memory_models.dart`
- `rust_api/core.dart`
- `rust_api/index.dart`
- `rust_api/novels_events.dart`
- `rust_api/novels_events_models.dart`
- `rust_api/novels_workbench_http.dart`
- `rust_api/novels_models.dart`
- `rust_api/novels_rest_api.dart`
- `rust_api/production.dart`
- `rust_api/project_overview.dart`
- `rust_api/projects_rest_extra.dart`
- `rust_api/projects_rest_compat.dart`
- `rust_api/prompts_api.dart`
- `rust_api/scripts_api.dart`
- `rust_api/scripts_storyboards_models.dart`
- `rust_api/settings_about_danger.dart`
- `rust_api/settings_agent_deploy.dart`
- `rust_api/settings_memory_config_api.dart`
- `rust_api/skills_api.dart`
- `rust_api/status_auth_me.dart`
- `rust_api/storyboards_api.dart`
- `rust_api/system_status_api.dart`
- `rust_api/tasks_center_rest.dart`

### `home_page/`（工作台 / 探针 / 兼容区）

- `home_page.dart`
- `home_page/agent_workspaces/controller.dart`
- `home_page/agent_workspaces/contexts/production/support.dart`
- `home_page/agent_workspaces/contexts/script/support.dart`
- `home_page/project_editor/dialog/actions.dart`
- `home_page/project_editor/dialog/content.dart`
- `home_page/project_editor/editor.dart`
- `home_page/project_editor/http_probes/general_probe.dart`
- `home_page/project_editor/http_probes/project_probe.dart`
- `home_page/project_editor/http_probes/tasks_probe.dart`
- `home_page/project_editor/assets/assets.dart`
- `home_page/project_editor/assets/clip_upload.dart`
- `home_page/project_editor/assets/compatibility/crud.dart`
- `home_page/project_editor/assets/compatibility/images.dart`
- `home_page/project_editor/assets/compatibility/relations.dart`
- `home_page/project_editor/assets/corner_scape.dart`
- `home_page/project_editor/assets/dialogs.dart`
- `home_page/project_editor/assets/generation/dialog.dart`
- `home_page/project_editor/assets/generation/section.dart`
- `home_page/project_editor/assets/generation/support.dart`
- `home_page/project_editor/assets/images.dart`
- `home_page/project_editor/assets/support.dart`
- `home_page/project_editor/assets/workbench.dart`
- `home_page/project_editor/novels/compatibility/actions.dart`
- `home_page/project_editor/novels/events/actions.dart`
- `home_page/project_editor/novels/events/section.dart`
- `home_page/project_editor/novels/support.dart`
- `home_page/project_editor/novels/workbench.dart`
- `home_page/project_editor/scripts/probe.dart`
- `home_page/project_editor/scripts/scripts.dart`
- `home_page/project_editor/scripts/workbench.dart`
- `home_page/projects/controller.dart`
- `home_page/projects/previews.dart`
- `home_page/projects/section.dart`
- `home_page/projects/workbenches/agent_memory.dart`
- `home_page/quality_reviews/previews.dart`
- `home_page/script_editor/batch_dialog.dart`
- `home_page/script_editor/editor.dart`
- `home_page/script_editor/storyboards.dart`
- `home_page/script_editor/support.dart`
- `home_page/storyboard_editor/editor.dart`
- `home_page/storyboard_editor/support.dart`
- `home_page/system_probes/account/settings.dart`
- `home_page/system_probes/content.dart`
- `home_page/system_probes/models_catalog/settings_probe.dart`
- `home_page/task_center/controller.dart`
- `home_page/task_center/previews.dart`
- `home_page/task_center/section.dart`
- `home_page/task_center/support.dart`

> **说明**：若某文件仅含 `legacyId` 模型字段，收敛 HTTP 后可能**只改名段/模型**而未必删文件。

### `frontend/test/`（契约/工作台回归）

以下测试文件正文含 `历史` 字样（与项目 历史 id、探针 URL 等相关）；改 API 后需同步更新：

- `frontend/test/agent_workspaces_section_test.dart`
- `frontend/test/novel_workbench_support_test.dart`
- `frontend/test/project_assets_generation_workbench_support_test.dart`
- `frontend/test/project_editor_assets_workbench_support_test.dart`
- `frontend/test/projects_section_test.dart`
- `frontend/test/script_workbench_support_test.dart`
- `frontend/test/script_workspace_support_test.dart`
- `frontend/test/storyboard_workbench_support_test.dart`
- `frontend/test/task_center_section_test.dart`

---

## 三、文档与配置

| 路径 | 说明 |
|------|------|
| `docs/openapi.yaml` | 仍含 **`legacy_id`/`novel_legacy_id`** 等 path 参数名（DB 语义）；字面 URL 段 **`/历史/`** 已收敛（如画风 **`/numeric/`**） |
| `docs/websocket-events.md` | 少量 `历史` 提及；随契约改 |
| `docs/plans/harness-rust-flutter.md` | 总路线；收敛完成后可更新「parity/兼容区」描述 |
| `docs/plans/electron-node-parity.md` | 旧 `src/router.ts` 前缀 ↔ Rust 路径对照；**删 历史 HTTP 前**应用其表核对是否仍有仅整型路径的客户端 |
| `docs/plans/master-detailed-parity-audit.md` | 对照 `master:src/routes/**`、`socket`、`agents` 的审计方法；防「HTTP 删了但 Harness/工作流仍依赖旧语义」 |
| 根目录 **`data/`**、**`scripts/`**、**`docs/`** 中的旧布局与脚本 | 非 OpenAPI 字面 历史，但与 **master 双源数据 / Electron 脚本** 相关；见 **§八** |
| `supabase/migrations/*.sql` | 多表含 `legacy_id` 列；属 **Schema 波次**，见下文 |

---

## 四、推荐实施方案与步骤（可勾选）

### 实施进度（滚动更新）

| 阶段/项 | 状态 | 备注 |
|--------|------|------|
| **E（§八）** | 已完成 | 根 `data/` 收敛、`scripts/` 清理、多语言 `docs/README.*` 截断等见 §8 表格 |
| **A** | 部分 | OpenAPI 已对「按 历史 项目 id」的 get/patch/delete/stats 标 `deprecated`；全量 `merge` 列表与「API→屏幕」表可由本文件 §一/§二 继续维护 |
| **B·竖切 1：项目 UUID** | 已落地（主路径） | 后端：`GET\|PATCH\|DELETE /api/v1/projects/{project_id}`、`GET …/stats`。Flutter `updateProjectByProjectId` / `deleteProjectByProjectId`；**已删除** `…/projects/历史/{id}` 项目详情与 stats 旧路径；**已删除** **`POST /api/v1/project/get-project`** / **`add-project`** / **`edit-project`** / **`delete-project`**（`projects::历史`），`postProject*` compat 走 **`/api/v1/projects`** |
| **B·竖切 2：项目资产 REST（UUID 项目段）** | 已落地（主路径） | 后端：`/api/v1/projects/{project_id}/assets` 全树（含 corner-scape、图片 CRUD、`scripts/{sid}/assets/{aid}` 关联）。资产仍用 **`asset_legacy_id`** 路径段。Flutter `rust_api` 主路径为 `fetchProjectAssetsByProjectId`、`createProjectAssetUnderProject` 等；项目编辑器资产 UI 已切 UUID。**已删除** HTTP **`…/projects/历史/.../assets*`** 与 **`…/projects/历史/.../scripts/.../assets/...` 的 PUT/DELETE**；OpenAPI 与 `pg_contract` 已对齐 |
| **B·竖切 3：项目小说 REST（UUID 项目段）** | 已落地（主路径） | 后端：`GET\|POST /api/v1/projects/{project_id}/novels`，`GET\|PATCH\|DELETE …/novels/{novel_legacy_id}`。Flutter `novels_rest_api` 与项目编辑器小说列表/工作台已切 UUID。**已删除** `…/projects/历史/{id}/novels*` 与 **`narrative::历史`**（**`/api/v1/novels/*`**） |
| **B·竖切 4：项目小说事件 REST（UUID 项目段）** | 已落地（主路径） | 后端：`GET\|POST …/novel-events`，`PATCH\|DELETE …/{event_legacy_id}`，`POST …/batch-delete`，**`POST …/generate-events`**。**已删除** `…/projects/历史/.../novel-events*` 与 **`POST /api/v1/novels/events/*`** |
| **B·竖切 5：叙事分镜 REST（UUID 项目段）** | 已落地（主路径） | 后端：`GET\|POST …/projects/{project_id}/scripts/{script_legacy_id}/storyboards`，`GET\|PATCH\|DELETE …/projects/{project_id}/storyboards/{storyboard_legacy_id}`（分镜仍为 **`storyboard_legacy_id`**）。Flutter `storyboards_api` 与剧本编辑器分镜列表/单条编辑仅 UUID 路径。**已删除** `scripts/历史/.../storyboards` 与 **`storyboards/历史/{id}`** |
| **B·竖切 6：剧本 CRUD（UUID 项目段）** | 已落地（主路径） | 后端：`POST …/projects/{project_id}/scripts`，`GET\|PATCH\|DELETE …/projects/{project_id}/scripts/{script_legacy_id}`；创建逻辑与 advisory lock 与旧路径一致。Flutter `scripts_api` 与剧本编辑器/项目「新建空剧本」主路径已切 UUID。**已删除** `POST …/projects/历史/.../scripts` 与 **`…/scripts/历史/{id}`** 剧本本体 CRUD（分镜 REST 见 **B·竖切 5**） |
| **B·竖切 7：`get-script-api`（UUID 项目段）** | 已落地（主路径） | 后端：`POST …/projects/{project_id}/scripts/get-script-api`（workspace 成员 scope helper + body 可选 `name`）。Flutter `postScriptsGetScriptApiByProjectId`；剧本/项目脚本工作台与 probe 主路径已切 UUID。旧 `POST …/scripts/get-script-api` **已删除** |
| **B·竖切 8：`batch-add` 剧本（UUID 项目段）** | 已落地（主路径） | 后端：`POST …/projects/{project_id}/scripts/batch-add`（body 仅 **`data`**，与 历史 插入/锁一致）。Flutter `postScriptsBatchAddByProjectId`；项目剧本批量工作台与 probe 主路径已切 UUID。旧 `POST …/scripts/batch-add` **已删除** |
| **B·资产 workbench（旧 `/api/assets` 兼容面）** | 已落地 | **已删除**顶层 **`POST /api/v1/assets/*`**；**`POST …/projects/{project_id}/assets/workbench/{nested,image-bundle,upload-clip,material-data,batch-generation-data,polling-image-assets,polling-prompt-assets,add-assets,save-assets,update-assets,del-assets,batch-delete,del-image}`**（OpenAPI / **`contract_smoke`** / **`pg_contract`** / Flutter **`rust_api/assets_images.dart`** 已对齐） |
| **B·其余域** | 部分 | **`harness`** / **`jobs`** 整型 payload、**`asset_extract`** **`project_legacy_id`** 体、**`settings::agent_memory`**、**`assets-generate`** 与 worker **`legacy_*` id** 等仍待竖切；制作 HTTP 模块已更名为 **`production`**（路径不变）；**文档**：`backend/README.md`、`docs/plans/harness-rust-flutter.md`、`electron-node-parity.md` 等与 **UUID 项目段**主路径对齐 |
| **C–D** | 未做 | 大块删 `*历史*` 模块与删 PG `legacy_id` 列 |

### 阶段 A：盘点与契约标记（低风险）

1. 自 `backend/src/app/router.rs` 导出完整 **历史 相关 `merge` 列表**，与 OpenAPI 路径 diff。
2. 自 Flutter `rust_api/*.dart` 建立 **API → 屏幕入口** 表（谁调用谁）。
3. 对「计划废弃」的 operationId 在 OpenAPI 加 **`deprecated: true`**（可选同步生成客户端告警）。

### 阶段 B：按域竖切（每一域：后端 ⇄ 前端 ⇄ 文档 ⇄ 测试）

对单一域（例如「项目资产 CRUD」）重复：

1. **设计目标契约**（仅 UUID 路径或统一 query；禁止双义 body）。
2. **后端**：实现新路由或扩展现有 `projects/routes`；必要时短期 **双轨**（新旧并存）。
3. **Flutter**：主路径切到新 API；折叠区/probe 下线或改调新 API。
4. **OpenAPI / smoke / pg_contract**：删旧或改为测新路径。
5. **删除**旧 `router()` 注册与死代码；跑 `yarn refactor:check`。

### 阶段 C：大块 历史 模块删除顺序（建议）

1. ~~`projects::历史`（旧 `POST /api/v1/project/get-project` 等）~~ **已删除**；Flutter `projects_rest_compat` 仍保留 compat 封装，内部走 **`GET`/`POST`/`PATCH`/`DELETE /api/v1/projects*`**。
2. ~~`narrative::历史`（`/api/v1/novels/*`）~~ **已删除**；`novels_workbench_http` 保留 **`postLegacy*`** 名，内部仅调 UUID REST。
3. ~~`rest_legacy::{general,tasks}`~~ **已删除**。
4. ~~`scripting::历史`~~ **已并入 `scripting::scripts`**（路由不变）。
5. ~~**`assets/历史*` + `legacy_query`**~~：**已重命名**为 **`workbench_write` / `workbench_query`**；HTTP 仍在 **`…/projects/{project_id}/assets/workbench/*`**；**`assets-generate`/worker** 与队列 **`legacy_image_id`** 等仍待后续竖切。
6. **Production HTTP**：目录 **`backend/src/production/`**（模块名 **`production`**，**`/api/v1/production/*`** 不变）；流程 JSON 在 **`production_flow`**，Harness **只**依赖 **`production_flow`** 读合并后的 flow。

**顺序补充（与 §7–§8 对齐）**：

- **`assets-generate` + `jobs` worker**：与 **`legacy_image_id` / `asset_legacy_id` payload** 强耦合；改 REST 路径不等于改队列语义，需 **双写 payload 或 worker 迁移** 单独排期。
- **`harness` + `agent_memory`**：若 HTTP 改为 UUID 主键，须定义 **WS 上下文**（是否仍传整型 `projectId`、是否新增 `projectUuid`）并改 Flutter attach 路径，否则易出现「REST 已新、Agent 仍旧」的断裂。

### 阶段 D：Schema（可选、独立窗口）

1. 确认是否仍需要 **整型**对外暴露；若否，仅 HTTP 收敛即可先不动列。
2. 若需删 `legacy_id` 列：新迁移、`UPDATE` 回填、双写期、再删列 —— **备份与回滚预案** 必备。
3. 2026-05-11 kickoff 结论：在真正删列前，至少还要先收掉三类依赖面：
   - Flutter `production` / `task_center` / `agent_workspaces` 对 `projectId`、`*_numeric_id` 的主路径消费
   - 后端 `production/flow_data`、`scope`、`jobs/worker`、jobs summaries/notifications 对 `project_numeric_id` 等 payload/查询锚点的依赖
   - `import_staging` / `promote_import_snapshots()` 与 `pg_contract_tests` 把 `numeric_id` 当幂等与清理基准的测试/导入链路

### 阶段 E：根目录 `data/` / `scripts/` / `docs/` 卫生（可与 API 并行）

按 **§八** 勾选：去掉 **`data/` 与 `backend/data/` 双源**、清理无引用的 **Electron/NSIS** 脚本、刷新 **README** 中仍指向旧 `data/serve` 的说明。

---

## 五、门禁（每波合并前）

- `bash scripts/refactor-check.sh`（或等价的 `yarn refactor:check`）通过。
- 禁止仅改后端路由而不改 Flutter 可执行路径。

---

## 六、与 `master` 的关系（对照方法，防遗漏）

`master` **不**再作为运行真源，但用作 **路由与行为清单** 的交叉校验，避免只删了 Rust 里文件名带 `历史` 的模块、却漏掉「新模块里的整型 id 路径」或「旧 Socket 域」。

建议每次大删改前执行：

1. **旧 HTTP 面**：`git show master:src/router.ts` 与 `git ls-tree -r master -- src/routes` — 与 `docs/plans/electron-node-parity.md` §3 左列前缀对照，确认每个旧前缀在当前 OpenAPI 中仍有**明确替代**或已标 🔀。
2. **旧实时面**：`git ls-tree -r master -- src/socket` — 与 `docs/websocket-events.md` + `backend/src/harness` 对照（见 **`master-detailed-parity-audit.md`** §2.3）。
3. **旧 Agent 工具**：`git ls-tree -r master -- src/agents` — 与 `backend/src/harness/invoke` 工具注册表对照，避免删 HTTP 后 Harness 仍引用已删加载函数。
4. **当前权威**：仍以 **`docs/openapi.yaml`** + **`backend/src/app/router.rs` 全量 `merge`** + Flutter `rust_api` 调用为准；上列仅防漏项。
5. **旧数据与打包脚本**：`git ls-tree -r master -- data scripts docs` 与当前分支 diff（见 **§八**），识别「双源目录」与「已无引用」的脚本/资源。

---

## 七、风险与常见漏洞（Review 摘要）

| 风险 | 说明 |
|------|------|
| **只改 URL 不改队列** | `app_generation_job` payload、`worker` 反查仍用 **`legacy_id`/`legacy_image_id`**；删路由前确认无在途任务或做好 payload 版本迁移。 |
| **只改 REST 不改 Harness** | `HarnessContext`、各 `domain_*` 工具仍以整型项目/剧本 id 查库；需 **同一里程碑** 内定义新上下文字段并改 Flutter WS 客户端。 |
| **制作 HTTP 面过早删除** | **`production::router()`** 仍为产品工作台真源；流程合并逻辑在 **`production_flow`**，删路由前须完整迁移 Flutter/契约。 |
| **OpenAPI / smoke / pg_contract 不同步** | 仅删 `router()` 会导致 CI 仍测旧路径或反之；每域保持 **契约三件套** 同 PR。 |
| **画风 / Prompts** | 画风 URL 已用 **`/art-styles/numeric/...`**；**`prompts/{numeric_id}`** 对应旧 **`o_prompt.id`** 槽位 1–3，不在已删的 **`narrative::历史`** 树内。 |
| **Staging 与删列** | `import_staging`、`promote_import_snapshots` 与 **`import_user_map`** 等；删 `legacy_id` 列前须完成数据迁移与回归。 |
| **双源 `data/`** | 仓库根 **`data/`** 与 **`backend/data/`** 均跟踪大量 **`skills/`**、**`models/`**；Rust 运行时与 `include_str!` 均指向 **`backend/data/`**（如 `prompting/skills.rs`、`vendor/catalog.rs`）。根目录树易与 **`backend/data/`** 漂移、误改无效副本。 |

---

## 八、根目录 `data/`、`scripts/`、`docs/`（master 遗留面）

与 **HTTP `历史` 模块**不同：这里多是 **旧 Electron/Node 时代的目录布局与脚本**，或 **与当前真源重复的静态资源**。建议在「decommission-electron」或仓库瘦身里程碑中**单独勾选**，避免与 API 竖切混在同一 PR。

### 8.1 `data/`（仓库根）

| 现状 | 说明 |
|------|------|
| **与 `master` 同源** | `master` 上即存在 **`data/skills/**`**、**`data/models/**`**、**`data/assets/ending.mp4`** 等；当前分支仍 **git 跟踪**（约 **200+** 文件量级，与 **`backend/data/`** 条目数接近）。 |
| **真源** | [`docs/plans/harness-rust-flutter.md`](harness-rust-flutter.md) **§v1** 已约定：技能与打包数据 **统一在 `backend/data/`**（`CARGO_MANIFEST_DIR`），**不应**在仓库根长期保留第二套 `data/skills`。 |
| **运行时** | 服务端读 **`backend/data/skills`**、**`backend/data/models_catalog.json`**、**`backend/data/prompt_defaults`** 等；未发现 Rust 以仓库根 **`data/`** 为读取根路径。 |
| **建议步骤** | 1）`diff -rq data/skills backend/data/skills`（及 models 若有）确认差异；2）以 **`backend/data/`** 为准合并后 **从 Git 删除根 `data/` 下与之一致的树**（保留若确有外部脚本仍引用根路径则先改脚本）；3）大文件删除走 **git filter** 或 LFS 策略若需缩历史体积。 |
| **进度（已做）** | 已删除根目录 **`data/skills/`**（与 `backend/data/skills` 一致）；**`data/models/all-MiniLM-L6-v2`** 迁至 **`backend/data/models/`**（此前仅根目录有跟踪，避免误删唯一 ONNX 副本）；**`data/assets/ending.mp4`**、**`data/update.json`** 迁至 **`backend/data/archive/`**；**`backend/README.md`** 已去掉「根目录副本」表述。 |

### 8.2 `scripts/`

| 文件 | 说明 |
|------|------|
| **`refactor-check.sh`** | 现行 CI/门禁，**保留**。 |
| **`license.ts`** | **已从 Git 删除**；根 **`package.json`** 已移除 **`license`** script（原依赖 **`license-checker`** 已不在 `devDependencies`）。第三方清单可后续用 **`cargo deny`** 等单独引入。 |
| **`installer.nsh`** | **已删除**（无 electron-builder 引用）。 |
| **`logo.ico` / `logo.png`** | **已删除**（`scripts/` 下旧安装包素材，无代码引用）。 |

### 8.3 `docs/`

| 类别 | 说明 |
|------|------|
| **契约与路线** | **`openapi.yaml`**、**`websocket-events.md`**、**`plans/*.md`**、**`migration/*.md`** — **保留**；其中 migration 文档描述 SQLite→PG，与 **在线 历史 API** 是两件事，但同属「旧栈退场」叙事。 |
| **多语言 README** | **`docs/README.{en,ja,ru,th,vi,zhtw}.md`** 已截断为 **短入口**：删除 Docker/PM2/开发/目录树/相关仓库/**微信社群**/长版许可证与致谢；统一指向根 **`README.md`** + **`LICENSE`** + `backend`/`frontend`/路线图链接。 |
| **静态图** | **`docs/*.png`**、`sponsored/`、`atomgitLogo.svg` 等 — 营销/展示用，非 API 历史；仅在做 **文档归档** 时评估是否迁出仓库。 |

### 8.4 `.gitignore` 中与旧栈相关的条目（提示）

根 **`.gitignore`** 仍忽略 **`data/serve/`**、**`data/oss/*`**、**`data/test.sqlite`**、**`router.ts`** 等，对应旧 Node 本地运行习惯；全栈迁 Rust/Flutter 后可在清理旧文档时 **同步收紧或注释说明**，避免误以为仍需这些目录。

---

*文档版本：含 §8 根目录 data/scripts/docs 与 master 对照；实施时按阶段 B 逐域勾选并更新「进度」小节（可自行追加）。*
