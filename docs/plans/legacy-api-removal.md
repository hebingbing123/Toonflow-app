# Legacy API 收敛 / 移除计划

## 术语（避免混谈）

| 概念 | 含义 | 收敛难度 |
|------|------|----------|
| **HTTP 模块名带 `legacy`** | `narrative::legacy`、`production_legacy` 等独立路由树 | 中–高：删路由前须改 Flutter |
| **URL 中含 `/legacy/{整型 id}`** | 如 `GET /api/v1/projects/legacy/1/assets` | 中：可逐步改为 UUID 路径 |
| **请求体旧形状** | `projectId`、`camelCase` 与旧 Electron 对齐的 POST | 中：需换客户端 body + 后端 handler |
| **列 `legacy_id`（PG）** | 各 `app_*` 表常见整型外键/排序 | 低–高：属 **Schema**，可与 HTTP 分阶段 |
| **迁移工具 `legacy_import`** | `backend/src/bin/legacy_import.rs` | 通常 **保留**（与「在线 API 废弃」无关） |

---

## 一、后端涉及文件（按目录）

### 1. 路由入口（改动时必看）

| 文件 | 说明 |
|------|------|
| `backend/src/app/router.rs` | `merge(projects::legacy)`、`rest_legacy::*`、`narrative::legacy`、`production_legacy`、`scripting::legacy` 等 |
| `backend/src/main.rs` | 顶层 `mod production_legacy`、`mod rest_legacy`（与 `lib` 式入口二选一场景以实际 crate 根为准） |

### 2. 独立 legacy 路由模块（整棵可随「该域下线」删除）

| 路径 | 职责摘要 |
|------|----------|
| `backend/src/projects/legacy.rs` | `POST /api/v1/project/*`（getProject、addProject、editProject…） |
| `backend/src/projects/mod.rs` | `pub mod legacy` |
| `backend/src/narrative/legacy/mod.rs` | 小说旧形：`/api/v1/novels/*` |
| `backend/src/narrative/legacy/dto.rs` | DTO |
| `backend/src/narrative/legacy/handlers.rs` | Handlers |
| `backend/src/narrative/legacy/extraction.rs` | 事件抽取任务 |
| `backend/src/narrative/legacy/tests.rs` | 单元测试 |
| `backend/src/narrative/mod.rs` | `pub mod legacy` |
| `backend/src/production_legacy/mod.rs` | 生产工作台旧路径 `/api/production/*`、等 |
| `backend/src/production_legacy/workbench/*.rs` | flow、storyboard、assets、video、edit_image… |
| `backend/src/rest_legacy/mod.rs` | 未收拢域入口 |
| `backend/src/rest_legacy/general.rs` | general 旧 POST |
| `backend/src/rest_legacy/tasks.rs` | tasks 旧形 |
| `backend/src/scripting/legacy.rs` | 脚本相关旧路由 |
| `backend/src/scripting/mod.rs` | `pub mod legacy` |
| `backend/src/assets/legacy.rs` | 资产 legacy 聚合 |
| `backend/src/assets/legacy_query/mod.rs` | 旧查询面入口 |
| `backend/src/assets/legacy_query/*.rs` | get_assets_api、get_image、material、polling、batch_generation、upload_clip 等 |
| `backend/src/assets/mod.rs` | `mod legacy`、`mod legacy_query`、测试 `use legacy::*` |

### 3. 路径含 `legacy`、但**不在**上述 `legacy` 目录的 REST（收敛时要同步 OpenAPI + Flutter）

| 路径 | 说明 |
|------|------|
| `backend/src/narrative/novels/*` | `…/projects/legacy/{id}/novels` |
| `backend/src/narrative/events/*` | `…/novel-events` 等 |
| `backend/src/narrative/storyboards/*` | `…/scripts/legacy/{id}/storyboards`、`…/storyboards/legacy/{id}` |

### 4. 其它后端引用（删 `production_legacy` 前需评估）

| 文件 | 说明 |
|------|------|
| `backend/src/harness/invoke/domain_production.rs` | `crate::production_legacy::load_owned_production_flow_json` |
| `backend/src/harness/invoke/domain_script.rs`（及同目录其它域） | 工具入参/上下文普遍假设 **项目/剧本/小说 `legacy_id`**；HTTP 改 UUID 时须同步 **WS attach / `agent.context.update` 契约与实现**（见 `docs/websocket-events.md`） |

### 5. 契约与集成测试

| 路径 | 说明 |
|------|------|
| `backend/src/app/contract_smoke_tests/production_legacy.rs` | 烟雾：生产 legacy |
| `backend/src/app/contract_smoke_tests/skills_legacy_asset_posts.rs` | 烟雾：skills + 旧资产 POST |
| `backend/src/app/contract_smoke_tests/asset_jobs_tasks_legacy_post.rs` | 烟雾：资产/jobs/tasks/旧 project POST |
| `backend/src/app/contract_smoke_tests/*.rs`（其余） | 多处用例含 `/legacy/` 或 `legacy_id` 断言 |
| `backend/src/app/pg_contract_tests/mod.rs` 及 `*_suite.rs` | 需 DB 的契约；大量 `projects/legacy`、`legacy_id` |

### 6. 数据迁移 CLI（一般**不**随 HTTP legacy 删除）

| 文件 | 说明 |
|------|------|
| `backend/src/bin/legacy_import.rs` | SQLite → PG 导入工具；名称含 legacy，**不等于**在线 API |

### 7. 非 `*legacy*` 目录名、但 URL 或 body 仍绑整型 `legacy_id`（易漏）

| 路径 | 说明 |
|------|------|
| `backend/src/projects/routes.rs` | `GET`/`PATCH`/`DELETE /api/v1/projects/legacy/{legacy_id}`、`GET …/stats`（与 `projects::legacy` 旧 POST 并存，删路由时要一起盘点） |
| `backend/src/manuals/art_styles/*.rs` | `GET`/`PATCH`/`DELETE /api/v1/art-styles/legacy/{id}`、`GET …/cover`（封面落盘路径也按 `legacy_id` 命名，见 `AppState` 注释） |
| `backend/src/prompting/prompts/*.rs` | `GET`/`PATCH /api/v1/prompts/{legacy_id}`（对齐旧 `o_prompt.id` 1–3） |
| `backend/src/scripting/scripts.rs` | `…/projects/legacy/{id}/scripts`、`GET`/`PATCH`/`DELETE …/scripts/legacy/{id}` |
| `backend/src/scripting/asset_extract/mod.rs` | 请求体 **`project_legacy_id`** + **`script_legacy_ids[]`**（无 `/legacy/` 段但语义同旧栈） |
| `backend/src/assets/generate.rs` | `assets-generate` 各 handler：`project_id`/`project_legacy_id`、`asset_legacy_id`、`legacy_image_id` 入队 payload；`cancel-generate` 按 **`legacy_image_id`** 协同取消 |
| `backend/src/settings/agent_memory.rs` | `project_id: i32`（**项目 legacy id**）+ `episodes_id` 等驼峰体；与 Harness/工作台「按 legacy 项目」一致 |
| `backend/src/jobs/worker/*.rs`（如 `asset_image.rs`） | 生成结果回写、`/file` URL 模板中含 `project_legacy_id` / `asset_legacy_id` |

### 8. `app/router.rs` 全量 `merge` 与 legacy 的隐性耦合

下列模块**不一定**在路径里写 `legacy`，但常与上表或队列 payload 联动；收敛 HTTP 时勿只盯 `*legacy*` 子模块：

| `merge` 项 | 与 legacy 的关系 |
|------------|-------------------|
| `harness::http::router()` | `HarnessContext` 含 **`project_legacy_id` / `script_legacy_id`**；`harness/invoke/domain_*.rs` 大量 `p.legacy_id` SQL |
| `jobs::router()` | 任务行含 **`legacy_task_id`**；payload 常含 asset/script 整型 id |
| `settings::agent_memory::router()` | 见 §7 **`agent_memory.rs`** |
| `projects::routes::router()` | 见 §7 **`projects/routes.rs`** |
| `manuals::{director, art_styles, visual}` | 画风域显式 **`/art-styles/legacy/...`**；手册域需单独 grep `legacy` |
| `scripting::{scripts, agent, asset_extract}` | scripts 路径见 §7；**`asset_extract`** 体字段 |
| `metering::usage`、`billing::router()` | 自行检索是否仍传 **`projectId`（整型）** 或仅 UUID |

### 9. Staging / 提升（非 HTTP，但与 `legacy_id` 列同源）

| 路径 | 说明 |
|------|------|
| `supabase/migrations/*` + `legacy_staging` / `promote_legacy_from_staging()` | PG 契约与 **`pg_contract_tests`** 大量依赖；**删列 `legacy_id`** 前必须与此链路一起设计 |
| `backend/src/app/pg_contract_tests/mod.rs` 等 | 显式使用隔离用 **`legacy_id` 区间**、清理 `legacy_staging` |

---

## 二、前端涉及文件（`legacy` 字符串命中；含 URL/字段/目录名）

以下为 **`frontend/lib` 下 `*.dart` 且包含 `legacy` 的清单**（用于全量替换/收敛时检索；部分仅为注释或 `legacyId` 字段名）。

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
- `rust_api/novels_legacy_api.dart`
- `rust_api/novels_models.dart`
- `rust_api/novels_rest_api.dart`
- `rust_api/production.dart`
- `rust_api/project_overview.dart`
- `rust_api/projects_legacy.dart`
- `rust_api/projects_legacy_compat.dart`
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
- `rust_api/tasks_legacy.dart`

### `home_page/`（工作台 / 探针 / 兼容区）

- `home_page.dart`
- `home_page/agent_workspaces/controller.dart`
- `home_page/agent_workspaces/contexts/production/support.dart`
- `home_page/agent_workspaces/contexts/script/support.dart`
- `home_page/project_editor/dialog/actions.dart`
- `home_page/project_editor/dialog/content.dart`
- `home_page/project_editor/editor.dart`
- `home_page/project_editor/legacy/general_probe.dart`
- `home_page/project_editor/legacy/project_probe.dart`
- `home_page/project_editor/legacy/tasks_probe.dart`
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

以下测试文件正文含 `legacy` 字样（与项目 legacy id、探针 URL 等相关）；改 API 后需同步更新：

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
| `docs/openapi.yaml` | 大量 `/legacy/` 与旧形 body；收敛时逐路径 `deprecated` 或删除 |
| `docs/websocket-events.md` | 少量 `legacy` 提及；随契约改 |
| `docs/plans/harness-rust-flutter.md` | 总路线；收敛完成后可更新「parity/兼容区」描述 |
| `docs/plans/electron-node-parity.md` | 旧 `src/router.ts` 前缀 ↔ Rust 路径对照；**删 legacy HTTP 前**应用其表核对是否仍有仅整型路径的客户端 |
| `docs/plans/master-detailed-parity-audit.md` | 对照 `master:src/routes/**`、`socket`、`agents` 的审计方法；防「HTTP 删了但 Harness/工作流仍依赖旧语义」 |
| 根目录 **`data/`**、**`scripts/`**、**`docs/`** 中的旧布局与脚本 | 非 OpenAPI 字面 legacy，但与 **master 双源数据 / Electron 脚本** 相关；见 **§八** |
| `supabase/migrations/*.sql` | 多表含 `legacy_id` 列；属 **Schema 波次**，见下文 |

---

## 四、推荐实施方案与步骤（可勾选）

### 阶段 A：盘点与契约标记（低风险）

1. 自 `backend/src/app/router.rs` 导出完整 **legacy 相关 `merge` 列表**，与 OpenAPI 路径 diff。
2. 自 Flutter `rust_api/*.dart` 建立 **API → 屏幕入口** 表（谁调用谁）。
3. 对「计划废弃」的 operationId 在 OpenAPI 加 **`deprecated: true`**（可选同步生成客户端告警）。

### 阶段 B：按域竖切（每一域：后端 ⇄ 前端 ⇄ 文档 ⇄ 测试）

对单一域（例如「项目资产 CRUD」）重复：

1. **设计目标契约**（仅 UUID 路径或统一 query；禁止双义 body）。
2. **后端**：实现新路由或扩展现有 `projects/routes`；必要时短期 **双轨**（新旧并存）。
3. **Flutter**：主路径切到新 API；折叠区/probe 下线或改调新 API。
4. **OpenAPI / smoke / pg_contract**：删旧或改为测新路径。
5. **删除**旧 `router()` 注册与死代码；跑 `yarn refactor:check`。

### 阶段 C：大块 legacy 模块删除顺序（建议）

1. `projects::legacy`（旧 `POST /api/v1/project/*`）— 与 `projects_legacy` / compat 封装绑定。
2. `narrative::legacy`（`/api/v1/novels/*`）— 与 `novels_legacy_api` 绑定。
3. `rest_legacy::{general,tasks}`。
4. `scripting::legacy`。
5. `assets/legacy*`（与 `assets_crud` / legacy_query 全部迁移后）。
6. `production_legacy` — **最后**：依赖多、`harness` 有引用，需单独迁移 `load_owned_production_flow_json` 或等价能力。

**顺序补充（与 §7–§8 对齐）**：

- **`assets-generate` + `jobs` worker**：与 **`legacy_image_id` / `asset_legacy_id` payload** 强耦合；改 REST 路径不等于改队列语义，需 **双写 payload 或 worker 迁移** 单独排期。
- **`harness` + `agent_memory`**：若 HTTP 改为 UUID 主键，须定义 **WS 上下文**（是否仍传整型 `projectId`、是否新增 `projectUuid`）并改 Flutter attach 路径，否则易出现「REST 已新、Agent 仍旧」的断裂。

### 阶段 D：Schema（可选、独立窗口）

1. 确认是否仍需要 **整型**对外暴露；若否，仅 HTTP 收敛即可先不动列。
2. 若需删 `legacy_id` 列：新迁移、`UPDATE` 回填、双写期、再删列 —— **备份与回滚预案** 必备。

### 阶段 E：根目录 `data/` / `scripts/` / `docs/` 卫生（可与 API 并行）

按 **§八** 勾选：去掉 **`data/` 与 `backend/data/` 双源**、清理无引用的 **Electron/NSIS** 脚本、刷新 **README** 中仍指向旧 `data/serve` 的说明。

---

## 五、门禁（每波合并前）

- `bash scripts/refactor-check.sh`（或等价的 `yarn refactor:check`）通过。
- 禁止仅改后端路由而不改 Flutter 可执行路径。

---

## 六、与 `master` 的关系（对照方法，防遗漏）

`master` **不**再作为运行真源，但用作 **路由与行为清单** 的交叉校验，避免只删了 Rust 里文件名带 `legacy` 的模块、却漏掉「新模块里的整型 id 路径」或「旧 Socket 域」。

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
| **`production_legacy` 过早删除** | `domain_production` 等仍 `load_owned_production_flow_json`；须先抽 **独立模块** 或迁到 `projects`/`narrative` 等非 legacy 包。 |
| **OpenAPI / smoke / pg_contract 不同步** | 仅删 `router()` 会导致 CI 仍测旧路径或反之；每域保持 **契约三件套** 同 PR。 |
| **画风 / Prompts 漏网** | `art-styles/legacy`、`prompts/{legacy_id}` 不在 `narrative::legacy` 树内；易被「按目录删 legacy」误伤或遗漏。 |
| **Staging 与删列** | `legacy_staging`、`promote_legacy_from_staging` 与 **`legacy_user_map`** 等；删 `legacy_id` 列前须完成数据迁移与回归。 |
| **双源 `data/`** | 仓库根 **`data/`** 与 **`backend/data/`** 均跟踪大量 **`skills/`**、**`models/`**；Rust 运行时与 `include_str!` 均指向 **`backend/data/`**（如 `prompting/skills.rs`、`vendor/catalog.rs`）。根目录树易与 **`backend/data/`** 漂移、误改无效副本。 |

---

## 八、根目录 `data/`、`scripts/`、`docs/`（master 遗留面）

与 **HTTP `legacy` 模块**不同：这里多是 **旧 Electron/Node 时代的目录布局与脚本**，或 **与当前真源重复的静态资源**。建议在「decommission-electron」或仓库瘦身里程碑中**单独勾选**，避免与 API 竖切混在同一 PR。

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
| **契约与路线** | **`openapi.yaml`**、**`websocket-events.md`**、**`plans/*.md`**、**`migration/*.md`** — **保留**；其中 migration 文档描述 SQLite→PG，与 **在线 legacy API** 是两件事，但同属「旧栈退场」叙事。 |
| **多语言 README** | **`docs/README.{en,ja,ru,th,vi,zhtw}.md`** 已截断为 **短入口**：删除 Docker/PM2/开发/目录树/相关仓库/**微信社群**/长版许可证与致谢；统一指向根 **`README.md`** + **`LICENSE`** + `backend`/`frontend`/路线图链接。 |
| **静态图** | **`docs/*.png`**、`sponsored/`、`atomgitLogo.svg` 等 — 营销/展示用，非 API legacy；仅在做 **文档归档** 时评估是否迁出仓库。 |

### 8.4 `.gitignore` 中与旧栈相关的条目（提示）

根 **`.gitignore`** 仍忽略 **`data/serve/`**、**`data/oss/*`**、**`data/test.sqlite`**、**`router.ts`** 等，对应旧 Node 本地运行习惯；全栈迁 Rust/Flutter 后可在清理旧文档时 **同步收紧或注释说明**，避免误以为仍需这些目录。

---

*文档版本：含 §8 根目录 data/scripts/docs 与 master 对照；实施时按阶段 B 逐域勾选并更新「进度」小节（可自行追加）。*
