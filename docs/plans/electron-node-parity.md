# Electron / Node 后端 → Rust 后端 Parity 清单

**目的**：把「用 Rust 重写完整后端」从口号拆成**可勾选、可排序**的条目；与文首 YAML **`product-shipping-bar`**、**`decommission-electron`** 对齐。  
**维护**：旧路由由 `src/core.ts` 生成 **`src/router.ts`**（`@routes-hash`）；新增或删除 `src/routes/**/*.ts` 后应复核本表对应行。

## 1. 约定

| 维度 | 旧栈（Electron 内嵌 Node） | 新栈（`backend/`） |
|------|------------------------------|---------------------|
| HTTP 前缀 | `/api/...`（无版本段） | `/api/v1/...` |
| 鉴权 | JWT，`o_setting.tokenKey` | Supabase **`Authorization: Bearer`**（`SUPABASE_JWT_SECRET` 校验） |
| 主库 | SQLite（Knex 等） | **Supabase Postgres** + RLS（见 `supabase/migrations/`） |
| 实时 | Socket.IO（`src/socket/`） | **`GET /api/v1/ws`** + Harness 协议（`docs/websocket-events.md`） |
| 静态文件 | `/oss`、`/skills` 图片、`/assets` | **未在 Rust MVP 中复刻**；由 CDN/对象存储或独立静态服务承接（产品决定） |

## 2. 状态图例

| 符号 | 含义 |
|------|------|
| ✅ | 已在 Rust 提供等价或明确替代能力（见 OpenAPI / 实现） |
| 🟡 | 部分覆盖：竖切、子集、或仅数据模型一部分 |
| ⏳ | 未在 Rust 实现；需新迁移 + 路由 +（通常）Flutter 接线 |
| 🔀 | **不追求路径一对一**：换设计（如登录迁 Supabase、迁移工具独立二进制） |

## 3. 按旧路由前缀总览（对应 `src/router.ts`）

| 旧前缀 | 功能域 | Rust / 契约 | 备注 |
|--------|--------|-------------|------|
| `/api/agents/clearMemory`、`getMemory` | Agent 记忆 | ✅ `POST /api/v1/agents/memory/clear`、`query`；append 见 OpenAPI | 旧「按 type 清」语义已对齐方向 |
| `/api/artStyle/*` | 画风库 CRUD / 抽 prompt | ⏳ | 需 PG 表或并入 `metadata` 策略 |
| `/api/assets/*` | 素材 CRUD、轮询出图等 | 🟡 | **CRUD（无出图）**：**`POST/GET/PATCH/DELETE …/projects/legacy/{id}/assets`**；**`GET` 列表**：**`{ items, total }`**，可选 **`script_legacy_id`**、**`asset_type`**、**`name`**、**`page`/`limit`**（对齐 **`getAssetsApi`** 分页/筛选；无父子资产层级）；**`stats.role_count`**；Flutter **`rust_api`**：**`fetchProjectAssetsByLegacyId`**（含 **`page`/`limit`**）、**`fetchProjectAssetByLegacyIds`**、**`createProjectAssetUnderLegacy`**、**`patchProjectAssetByLegacyIds`**、**`deleteProjectAssetByLegacyIds`**、**`linkScriptToAssetByLegacyIds`** / **`unlinkScriptFromAssetByLegacyIds`**；项目详情对话框探针（**`script_legacy_id`** 下拉筛选 + 列表行 + **GET 首条资产详情** + **GET 分页 page=1&limit=2** + **GET 筛选 asset_type+name** + **GET 当前剧本+分页** `script_legacy_id`+`page`/`limit`）；**无 DB 烟雾**：**`GET …/assets?page=1&limit=2`**、**`GET …/assets?script_legacy_id&asset_type&name&page&limit`** → **503** **`database_error`**；**出图轮询 / 批量生成**仍 ⏳ |
| `/api/assetsGenerate/*` | 素材批量生成 / polish | ⏳ | 与 jobs + LLM 管线绑定 |
| `/api/cornerScape/getAllAssets` | 角落素材 | ⏳ | |
| `/api/general/generalStatistics` | 多项目统计 | ✅ `GET /api/v1/projects/summary` | 单项目见 `…/stats` |
| `/api/general/getSingleProject`、`updateProject` | 项目读写 | 🟡 | 读写在 **`/api/v1/projects/legacy/{id}`** 等；旧「单项目」形态用 legacy id 映射 |
| `/api/login/login` | 本地账号登录 | 🔀 | **Supabase Auth**（Flutter `supabase_flutter`） |
| `/api/migrate/migrateData` | 数据迁移 | 🔀 | **`toonflow-legacy-import`** + promote 迁移（非 HTTP 热路径） |
| `/api/modelSelect/getModelList`、`getModelDetail` | 模型目录 | ✅ `GET /api/v1/models`、`/api/v1/models/detail` | 静态 JSON 嵌入 |
| `/api/novel/*` | 小说与事件管线 | ⏳ | 大块域；需表设计与竖切 |
| `/api/other/getVersion` | 版本号 | ✅ `GET /api/v1/version` | |
| `/api/other/deleteAllData` | 清空数据 | ⏳ | 高危；需显式策略与审计 |
| `/api/production/**` | 分镜图/视频工作台、流、导出 | 🟡 | **Storyboard** 已有 **`app_storyboard` + REST**；**轮询出图、视频轨、export** 等仍 ⏳ |
| `/api/project/*` | 项目、导演/视觉手册 | 🟡 | CRUD + `director_manual` 等已在 PG；**`getVisualManual` 类「拼 skills 目录 + 图」**仍 ⏳ |
| `/api/script/*` | 剧本 CRUD、导出、抽素材 | 🟡 | CRUD ✅；**export** / **poll** / **`extract-assets`** ✅；**`PUT/DELETE …/projects/legacy/{p}/scripts/{s}/assets/{a}`** 维护 **`app_script_asset`** ✅；Flutter **`exportScriptsZip`**、**`pollScriptExtractState`**、**`startScriptAssetExtract`** 项目详情探针；旧 prompt 对齐见 **`SCRIPT_ASSET_EXTRACT_PROMPT_PATH`** |
| `/api/scriptAgent/*` | 剧本 Agent 计划数据 | ⏳ | 🔀 部分能力由 **Harness WS** 替代，持久化结构需对齐 |
| `/api/setting/about/*` | 更新检查、安装包 | ⏳ | 多为桌面分发；Web/桌面分流 |
| `/api/setting/agentDeploy/*` | 本地 Agent 部署配置 | ⏳ | 与「云端 Rust + 用户密钥」模型不同，需产品定稿 |
| `/api/setting/dbConfig/clearData` | 清库 | ⏳ | 同 deleteAllData |
| `/api/setting/dev/*` | Dev 开关 | ⏳ | |
| `/api/setting/fileManagement/openFolder` | 打开本地目录 | 🔀 | 桌面端本地能力，非 HTTP |
| `/api/setting/getTextModel` | 文本模型配置 | ⏳ | 与 vendor / 环境变量策略合并设计 |
| `/api/setting/loginConfig/*` | 用户密码 | 🔀 | Supabase 账户体系 |
| `/api/setting/memoryConfig/*` | 记忆配置 UI | 🟡 | 读写在 Rust 为 **`agents/memory/*`**；配置项细表可 ⏳ |
| `/api/setting/promptManage/*` | Prompt 模板 | ⏳ | 需 PG 或 skills 策略 |
| `/api/setting/skillManagement/*` | Skills 列表/读写 | 🟡 | Rust：**只读** `GET /api/v1/skills*`；**saveSkillContent**（写盘）⏳ |
| `/api/setting/vendorConfig/*` | 供应商与密钥 | ⏳ | SaaS 下多为 **服务端 env + billing**；见 **`saas-product-spec`** |
| `/api/task/getProject`、`getTaskApi`、`getTaskCategories`、`taskDetails` | 任务中心 | 🟡 | **`GET /api/v1/jobs*`** + 聚合 **`kinds`/`status` summary**；旧「任务分类」映射需产品确认 |
| `/api/test/test` | 测试路由 | ⏳ | 可改为 Rust 内部测试或删除 |

### 3.1 Socket.IO（非 REST）

| 旧模块 | Rust / 说明 |
|--------|-------------|
| `src/socket/routes/scriptAgent.ts` | 🔀 **`harness.*` WS** + channel attach；完整 parity 见 Harness 文档与 Flutter 探针 |
| `src/socket/routes/productionAgent.ts` | 同上 |

## 4. Rust 已暴露 HTTP 面（权威列表）

以 **`docs/openapi.yaml`** 为准（节选标签）：`system`、`session`、`projects`、`assets`、`scripts`、`storyboards`、`skills`、`harness`、`jobs`、`usage`、`models`、`agents`、`webhooks`。  
**WebSocket**：`externalDocs` → `docs/websocket-events.md`。  
**可选 PG 回归**：**`backend/src/app/mod.rs`** 中 **`app::pg_contract_tests::projects_create_stats_delete_roundtrip`**（**`cargo test pg_contract -- --ignored`**）在删项目前覆盖 **创建剧本/资产、`GET …/assets/{aid}`**、**`GET …/assets` 按 **`asset_type`/`name`** 筛选（命中 1 条与 0 条）**、**`GET …/assets` 按剧本筛选、`PUT` 剧本–资产关联、分页查询、`DELETE` 取消关联后筛选为空**。**无 DB 烟雾**：**`contract_smoke_tests`** 对 **`GET`/`POST`/`PATCH`/`DELETE …/assets`（含单条路径）**、**`GET …/assets?page=1&limit=2`**、**`GET …/assets`（组合 **`script_legacy_id`/`asset_type`/`name`/`page`/`limit`**）**、**`PUT`/`DELETE …/scripts/…/assets/…`** 断言 **503** `database_error`。

## 5. 分波实施建议（把「完整后端」拆成可合并的 PR）

下列顺序可按团队并行度调整；每一波应带 **OpenAPI 增量 + 迁移（若需）+ `contract_smoke` 或 PG 测试**。

| 波次 | 目标 | 依赖 |
|------|------|------|
| **A（当前基线）** | 项目/剧本/分镜、jobs、usage、memory、models、skills 只读、harness、billing webhook、me | 已有 |
| **B** | **Script**：export + poll + **extract-assets** ✅（**`20260406120000_app_asset.sql`**） | 任务化/可观测加固、prompt 与旧库逐字对齐可选 |
| **C** | **Novel + event** 全表与 REST | 新迁移、RLS |
| **D** | **Assets + assetsGenerate**（含轮询出图与 PG 资产表） | D 通常依赖 C 或项目维度 |
| **E** | **Production 剩余**：视频轨、批量出图、export 等 | jobs、对象存储、可能 CDN |
| **F** | **Setting 云端化**：prompt、vendor（非密钥明文）、skill 写（若仍要） | `saas-product-spec`、合规 |
| **G** | **静态资源策略**：原 `/oss`、`/assets`、skills 图片 URL | 运维与产品 |
| **H** | **deleteAllData / clearData**：受控运维 API 或仅 CLI | 审计与权限 |

完成 **A–H** 中与产品 PRD **blocking** 的条目 + **`quality-bar`** 验收 + 灰度后，才可把 **`decommission-electron`** 标为完成。

## 6. 重构完成后的旧代码清理

与 **`harness-rust-flutter.md`** YAML **`decommission-electron`**、**§11.1.1** 一致：**parity 与灰度完成后**，应 **下线并删除或归档** 旧 Electron + Node 服务端实现，避免双栈长期共存、文档与 CI 分叉。

| 类别 | 建议动作 |
|------|----------|
| 旧 HTTP/WS | 移除 **`src/routes/**`**、**`src/socket/**`**、**`src/app.ts`**、**`src/router.ts`**、**`src/core.ts`** 等（以仓库为准） |
| 根 Node 元数据 | 收缩 **`package.json`** 中仅服务旧栈的 **dependencies / scripts** |
| CI | 去掉仅旧栈的 workflow；保留 **`refactor-monorepo`** / **`refactor-check`** 与新发布链路 |
| 迁移工具 | **`legacy_import`** 等可暂留；迁移期结束后再归档或迁出 |
| 安全网 | 大删前打 **git tag** 保留可检出旧栈的提交 |

**新栈唯一主路径**：**`backend/`**（Rust + Harness）+ **`frontend/`**（Flutter）。

## 7. 与本仓库其它文档的关系

- **`docs/plans/harness-rust-flutter.md`**：总路线图；**`rust-backend-mvp`** 是后端 **首条验收条**，不是完整 parity。
- **`product-shipping-bar`**：本文件为其 **parity 主表**；回归矩阵与灰度方案可另起 `docs/plans/` 短文或在 CI 中编码。
- **旧代码清理**：见上文 **§6** 与主计划 **§11.1.1**、**`decommission-electron`**。
