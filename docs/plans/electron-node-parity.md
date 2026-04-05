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
| `/api/artStyle/*` | 画风库 CRUD / 抽 prompt | 🟡 | **`app_art_style` + REST**；**`promote_legacy_from_staging()`** 含 **`o_artStyle`→`app_art_style`**（**`owner_user_id`** 见迁移说明）；**`GET`/`POST /api/v1/art-styles`**、**`GET`/`PATCH`/`DELETE …/art-styles/legacy/{id}`**（RLS）；**`POST /api/v1/art-styles/extract-prompt`**（OpenAI 形 **`image_url`**，对齐 **`extractStylePrompt`** 系统提示词；空 **`images`** / 全空白项 → **400**；合法体、**无 LLM** → **503** **`llm_not_configured`**）；Flutter **`fetchArtStyles`** / **`extractArtStylePrompt`**；**无 DB 烟雾**（CRUD）→ **503**；**`contract_smoke`**：**`POST …/extract-prompt`** → **`llm_not_configured`**；**`pg_contract`** **`art_styles_crud_roundtrip`** / **`promote_staging_*`**；旧 **base64→OSS 封面**仍 ⏳ |
| `/api/assets/*` | 素材 CRUD、轮询出图等 | 🟡 | **CRUD（无出图）**：**`POST/GET/PATCH/DELETE …/projects/legacy/{id}/assets`**；**`GET` 列表**：**`{ items, total }`**，可选 **`script_legacy_id`**、**`asset_type`**、**`name`**、**`page`/`limit`**（对齐 **`getAssetsApi`** 分页/筛选；无父子资产层级）；**`stats.role_count`**；**`GET …/assets/{aid}/images`** 返回 **`cover_legacy_image_id`**（**`metadata.imageId`**）与每项 **`selected`**，**`PATCH …/assets/{aid}`** 可写 **`cover_legacy_image_id`**（校验对应 **`app_asset_image.legacy_image_id`**），部分对齐 **`/api/assets/getImage`** 与封面写入（无 OSS 署名 **`filePath`**）；Flutter **`rust_api`**：**`fetchProjectAssetsByLegacyId`**（含 **`page`/`limit`**）、**`fetchProjectAssetByLegacyIds`**、**`createProjectAssetUnderLegacy`**、**`patchProjectAssetByLegacyIds`**、**`deleteProjectAssetByLegacyIds`**、**`linkScriptToAssetByLegacyIds`** / **`unlinkScriptFromAssetByLegacyIds`**；项目详情对话框探针（**`script_legacy_id`** 下拉筛选 + 列表行 + **GET 首条资产详情** + **GET 分页 page=1&limit=2** + **GET 筛选 asset_type+name** + **GET 当前剧本+分页** `script_legacy_id`+`page`/`limit`）；**无 DB 烟雾**：**`GET …/assets?page=1&limit=2`**、**`GET …/assets?script_legacy_id&asset_type&name&page&limit`** → **503** **`database_error`**；**出图轮询 / 批量生成**仍 ⏳ |
| `/api/assetsGenerate/*` | 素材批量生成 / polish | 🟡 | **`POST /api/v1/assets-generate/generate`**、**`polish-prompt`**、**`batch-generate`**、**`batch-polish`**：校验旧 JSON 体后 **501**（出图 / 润色与 **`app_generation_job`** + LLM 管线绑定后再实现） |
| `/api/cornerScape/getAllAssets` | 角落素材 | 🟡 | **`POST /api/v1/projects/legacy/{id}/assets/corner-scape`**（JWT）：父级资产（**`metadata.assetsId`** 缺失或 JSON **`null`**）、**`types`** 可选过滤、**role → scene → tool** 排序；**`history_images`** 来自 **`app_asset_image`**（**`state = '已完成'`**；含可选 **`legacy_image_id`** 对齐 **`o_image.id`**）；**`metadata`** 为父 **`app_asset`** 快照；**`GET`/`POST …/assets/{aid}/images`** 列表（含任意 **`state`**，按 **`sort_index`/`created_at`**）/写入、**`GET …/images/{image_id}`** 单条、**`PATCH`/`DELETE …/images/{image_id}`** 更新/删除 **`app_asset_image`**（**`PATCH`** 至少一改；**`state`** 清空则不再计入 corner **`history_images`**）；Flutter **`fetchProjectAssetImagesByLegacyIds`** / **`fetchProjectAssetImageByLegacyIds`** / **`createProjectAssetImage`** / **`patchProjectAssetImageByLegacyIds`** / **`deleteProjectAssetImageByLegacyIds`**；项目对话框 **POST 首条资产图片**；**`pg_contract`** 插入后 **`GET` 列表** 与 **`GET` 单条** 并经 **`PATCH`** 验证 corner 过滤 |
| `/api/general/generalStatistics` | 多项目统计 | ✅ `GET /api/v1/projects/summary`（含 **`novel_count`**、**`role_count`**、**`art_style_count`**、**`video_count`**（占位 **0**）） | 单项目见 **`…/stats`**（**`novel_count`** + **`role_count`** 等） |
| `/api/general/getSingleProject`、`updateProject` | 项目读写 | 🟡 | **`GET`/`PATCH …/projects/legacy/{id}`** 为主；另 **`POST /api/v1/general/get-single-project`**（**`{ id }`**）→ **`{ data: [ProjectRow] }`**；**`POST …/general/update-project`** 补丁 **`intro`**、**`type`**（写入 **`mode`**）、**`artStyle`**、**`videoRatio`**、**`projectType`**（至少一项） |
| `/api/login/login` | 本地账号登录 | 🔀 | **Supabase Auth**（Flutter `supabase_flutter`） |
| `/api/migrate/migrateData` | 数据迁移 | 🔀 | **`toonflow-legacy-import`** + **`promote_legacy_from_staging()`**（含 **`o_novel`→`app_novel`**、**`o_assets`→`app_asset`**、**`o_scriptAssets`→`app_script_asset`**、**`o_artStyle`→`app_art_style`**、**`o_prompt`→`app_user_prompt`**、**`o_image`→`app_asset_image`**（**`legacy_image_id`** 幂等）；返回 **`asset_images_upserted`** 等九列；非 HTTP 热路径） |
| `/api/modelSelect/getModelList`、`getModelDetail` | 模型目录 | ✅ `GET /api/v1/models`、`/api/v1/models/detail`、**`GET /api/v1/models/text-default`**（旧 **`getTextModel`** 占位 **`"123"`** + 目录默认 **`default_model_id`**；可选 **`TOONFLOW_DEFAULT_TEXT_MODEL_ID`**） | 静态 JSON 嵌入 |
| `/api/novel/*` | 小说与事件管线 | 🟡 | **`app_novel` + REST**：**`GET`/`POST …/projects/legacy/{id}/novels`**（**`search`/`page`/`limit`**）、**`GET`/`PATCH`/`DELETE …/novels/{nid}`**；**`POST /api/v1/novels/get-novel-data`**、**`POST …/get-novel-index`**（**`projectId`** = 项目 **`legacy_id`**）；**`POST …/novels/batch-delete`**（**`ids`** = **`app_novel.legacy_id`**，无 **`o_event*`** 级联）；Flutter **`rust_api`**：**`fetchProjectNovelsByLegacyId`** 等；项目详情探针；**无 DB 烟雾** → **503**；**`pg_contract`** 含 CRUD；旧 **批量新增 + cleanNovel 事件管线**、**`o_event*`** 仍 ⏳ |
| `/api/other/getVersion` | 版本号 | ✅ `GET /api/v1/version` | |
| `/api/other/deleteAllData` | 清空数据 | 🟡 | **`POST /api/v1/settings/danger/delete-all-data`**：体 **`{}`**，JWT 后 **501**（无本地 SQLite 全表清） |
| `/api/production/**` | 分镜图/视频工作台、流、导出 | 🟡 | **Storyboard** 已有 **`app_storyboard` + REST**；**`docs/openapi.yaml`** **`production`** 下列出旧栈对应 **`POST /api/v1/production/*`**：**六条** strict 体（**`get-production-data`**、**`get-flow-data`**、**`save-flow-data`**、**`workbench/generate-video`**、**`storyboard/polling-image`**、**`export-image`**）校验后 **501**；其余 **POST** 为 **`ProductionLegacyJsonStubBody`**（须 **JSON object**）后 **501**（**`o_video`** / OSS / 时间线仍待 **`jobs`** + 存储） |
| `/api/project/*` | 项目、导演/视觉手册 | 🟡 | CRUD + `director_manual` 等已在 PG；**`POST /api/v1/project/get-project`**（**`{}`**）→ **`{ data: [ProjectRow] }`**；**`POST …/project/delete-project`**（**`{ id }`**）等同 **`DELETE …/projects/legacy/{id}`**；**`POST …/project/add-project`** / **`POST …/project/edit-project`** 对齐旧 **`addProject`** / **`editProject`**（全量字符串字段；**`type`+`mode`** → 单列 **`app_project.mode`**）；**`GET`/`POST /api/v1/visual-manual`** 读 **`data/skills/art_skills/*`**；Flutter **`fetchVisualManualV1`** / **`fetchVisualManualPostV1`** + 首页探针（GET）；导演手册等旧路径仍 ⏳ |
| `/api/script/*` | 剧本 CRUD、导出、抽素材 | 🟡 | CRUD ✅；**export** / **poll** / **`extract-assets`** ✅；**`PUT/DELETE …/projects/legacy/{p}/scripts/{s}/assets/{a}`** 维护 **`app_script_asset`** ✅；**`POST /api/v1/scripts/get-script-api`**（**`projectId`** + 可选 **`name`**）→ 剧本列表 + **`relatedAssets`**（**`legacy_id`**）；Flutter **`exportScriptsZip`**、**`pollScriptExtractState`**、**`startScriptAssetExtract`** 项目详情探针；旧 prompt 对齐见 **`SCRIPT_ASSET_EXTRACT_PROMPT_PATH`** |
| `/api/scriptAgent/*` | 剧本 Agent 计划数据 | 🟡 | **`POST /api/v1/script-agent/get-plan-data`**、**`set-plan-data`**、**`update-data`**：校验旧 JSON 体后 **501**（无 **`o_agentWorkData`** 等价表）；🔀 实时流仍以 **Harness WS** 为主 |
| `/api/setting/about/*` | 更新检查、安装包 | 🟡 | **`POST /api/v1/settings/about/check-update`**：**`source`** 同旧枚举，**不拉 OSS**，**`needUpdate: false`**、**`latestVersion`** = 服务端 **`CARGO_PKG_VERSION`**；**`POST …/download-app`** 校验 **`url`** 后 **501**（本地安装/解压仅 Electron）；OpenAPI **`postAboutCheckUpdateV1`** / **`postAboutDownloadAppV1`**；Flutter 探针 |
| `/api/setting/agentDeploy/*` | 本地 Agent 部署配置 | 🟡 | **`POST /api/v1/settings/agent-deploy/list`**：**`{}`** 体返回 **`initDB`** 四条默认行（静态，无 PG）；**`POST …/deploy-model`**、**`POST …/set-key`** 校验后 **501**（不落库、HTTP 不写密钥）；OpenAPI **`postSettingsAgentDeployListV1`** 等 |
| `/api/setting/dbConfig/clearData` | 清库 | 🟡 | **`POST /api/v1/settings/danger/clear-database`**（旧为 **GET**；SaaS 用 **POST** 体 **`{}`**）：JWT 后 **501** |
| `/api/setting/dev/*` | Dev 开关 | 🟡 | **`GET /api/v1/settings/dev/switch-ai-tool`**（**`value`** **`"0"`**/**`"1"`**，来自 **`TOONFLOW_SWITCH_AI_DEV_TOOL`**，对齐 **`getSwitchAiDevTool`**）；**`PUT`** 校验后 **501** **`not_implemented`**（无 **`o_setting`** 写入；对齐 **`updateSwitchAiDevTool`** 动词，运维改 env）；OpenAPI **`getSwitchAiDevToolV1`** / **`putSwitchAiDevToolV1`**；Flutter **`fetchSwitchAiDevToolV1`** / **`putSwitchAiDevToolV1`** + 首页探针 |
| `/api/setting/fileManagement/openFolder` | 打开本地目录 | 🔀 | 桌面端本地能力，非 HTTP |
| `/api/setting/getTextModel` | 文本模型配置 | 🟡 | 旧实现仅为占位 **`data: "123"`**；Rust **`GET /api/v1/models/text-default`** 保留 **`legacy_placeholder`** 并返回可用 **`default_model_id`**（见模型目录行）； per-user 持久化仍可与 **`vendorConfig`** 合并设计 |
| `/api/setting/loginConfig/*` | 用户密码 | 🔀 | Supabase 账户体系 |
| `/api/setting/memoryConfig/*` | 记忆配置 UI | 🟡 | **RAG / 摘要数值与 ONNX 路径**：**`GET`/`POST /api/v1/settings/memory-config`**（**camelCase**，默认同 **`initDB`** **`o_setting`**；进程内 **`RwLock`**，重启复位）；**`delAllMemory`** → **`POST /api/v1/settings/memory-config/clear-agent-memories`**（需 **`projectId`+`agentType`**，等同 **`agents/memory/clear`** **`clearType: all`**，非 SQLite 全表删）；OpenAPI **`postSettingsClearAgentMemoriesV1`** 等；Flutter 探针 |
| `/api/setting/promptManage/*` | Prompt 模板 | 🟡 | **`app_user_prompt` + REST**：**`GET /api/v1/prompts`**（恒为 **3** 条，**`id`** **1–3** 对齐旧 **`o_prompt.id`**；无行时 **`data`** 来自服务端默认文件 **`backend/data/prompt_defaults/*.txt`**，与 **`initDB`** 种子一致）；**`GET /api/v1/prompts/{legacy_id}`** 单条（合并规则同列表）；**`PATCH /api/v1/prompts/{legacy_id}`** 仅更新 **`data`**（**upsert**）；Flutter **`fetchPromptsV1`** / **`fetchPromptByLegacyIdV1`** 首页探针；**无 DB 烟雾** → **503**；**`pg_contract`** **`prompts_list_patch_roundtrip`**（含 **`GET …/prompts/2`**） |
| `/api/setting/skillManagement/*` | Skills 列表/读写 | 🟡 | Rust：**`GET /api/v1/skills*`** + **`PUT /api/v1/skills/content`**（覆盖已存在文件，对齐 **`saveSkillContent`**）+ **`POST /api/v1/skills/content`**（**新建**文件，父目录自动建；已存在 → **409**）+ **`DELETE /api/v1/skills/content`**（删单个文件 → **204**；不存在 → **404**；目录/非文件 → **400**）+ **`GET /api/v1/skills/binary?path=`**（**`data/skills` 下图片**原始字节 + **`Content-Type`**，供 **`visual-manual`** 的 **`image`** 相对路径替代旧 OSS URL；**png/jpeg/gif/webp/svg**，上限 **25MB**）；Flutter **`fetchSkillsBinaryV1`** + 首页探针（**`_smoke/binary_probe.png`**） |
| `/api/setting/vendorConfig/*` | 供应商与密钥 | 🟡 | 密钥不落 HTTP；**`GET …/settings/vendors/summary`** 无密钥摘要；**`POST …/settings/vendors/model-test`** 校验 **`modelName`/`type`/`id`** 后 **501**；**`addVendor`/`updateVendor`/`deleteVendor`/`enableVendor`/`updateCode`/`getCodeByLink`** → **`POST …/vendors/{add,update,delete,enable,update-code,code-from-link}`** 校验后 **501**（无 **`o_vendorConfig`** / 无 vm2 / 无出站拉取） |
| `/api/task/getProject`、`getTaskApi`、`getTaskCategories`、`taskDetails` | 任务中心 | 🟡 | **`GET /api/v1/jobs*`** + 聚合 **`kinds`/`status` summary**；**`POST /api/v1/tasks/get-project`**（**`{}`**）→ **`{ data: [{ id, name }] }`**（**`legacy_id`**）；**`POST …/get-task-categories`** → **`{ data: [{ taskClass }] }`**；**`POST …/get-task-api`** 分页 **`app_generation_job`**（**`taskClass`/`state`/`projectId`** 过滤，**`projectId`** 对 **`payload.project_legacy_id`**）；**`POST …/task-details`** 校验 **`taskId`** 后 **501**（数字 **`o_tasks.id`** 未映射 UUID） |
| `/api/test/test` | 测试路由 | ✅ | **`GET /api/v1/ping`** — JSON **`{"ok":true}`**（旧栈为纯文本 **`ok`**） |

### 3.1 Socket.IO（非 REST）

| 旧模块 | Rust / 说明 |
|--------|-------------|
| `src/socket/routes/scriptAgent.ts` | 🔀 **`harness.*` WS** + channel attach；完整 parity 见 Harness 文档与 Flutter 探针 |
| `src/socket/routes/productionAgent.ts` | 同上 |

## 4. Rust 已暴露 HTTP 面（权威列表）

以 **`docs/openapi.yaml`** 为准（节选标签）：`system`、`session`、`settings`、`projects`、`general`、`art_styles`、`novels`、`assets`、`scripts`、`storyboards`、`production`、`skills`、`harness`、`jobs`、`tasks`、`usage`、`prompts`、`models`、`agents`、`webhooks`。  
**WebSocket**：`externalDocs` → `docs/websocket-events.md`。  
**可选 PG 回归**：**`backend/src/app/mod.rs`** 中 **`app::pg_contract_tests::projects_create_stats_delete_roundtrip`**（**`cargo test pg_contract -- --ignored`**）在删项目前覆盖 **`GET …/stats`**（**`role_count`**/**`novel_count`**/**`video_count`** 等随创建资产、小说、删小说变化）、**`GET …/projects/summary`**（**`video_count = 0`**；全局 **`role_count`**/**`script_count`** ≥ 单项目 **`stats`**；**`asset_count`** ≥ 1）、**创建剧本/资产、`GET …/assets/{aid}`**、**`POST …/assets/corner-scape`**（**role/scene** 排序、**`types`** 过滤、**`metadata.assetsId`** 数值则排除子资产、**`app_asset_image`** 历史；**`GET …/assets/…/images`** 列表；**`PATCH`** **`state`** 清空后 corner 不再列出）、**`GET …/assets` 按 **`asset_type`/`name`** 筛选（命中 1 条与 0 条）**、**`GET …/assets` 按剧本筛选、`PUT` 剧本–资产关联、分页查询、`DELETE` 取消关联后筛选为空**、**`POST/GET/PATCH/DELETE …/novels`**（含 **`search`+分页列表**）。另 **`promote_staging_populates_assets_and_links`**：向 **`legacy_staging.snapshot`** 写入 **`o_project`/`o_script`/`o_assets`/`o_scriptAssets`/`o_artStyle`/`o_prompt`/`o_image`** 后执行 **`promote_legacy_from_staging()`**，断言 **`app_asset`/`app_script_asset`/`app_art_style`** 与 **`GET …/assets`**、**`GET …/assets?script_legacy_id=`**、**`GET …/art-styles`** 一致，**`POST …/assets/corner-scape`** 中 **`history_images`** 含提升的 **`o_image`**（**`state=已完成`**），且 **`GET …/prompts`** 中 **`id=1`** 反映 **`o_prompt`** 正文（需 **`legacy_user_map`** 与 **`auth.users`** 中 **`CONTRACT_USER_SUB`** 已存在）。**无 DB 烟雾**：**`contract_smoke_tests`** 对 **`GET /api/v1/ping`**、**`GET`/`POST`/`PATCH`/`DELETE …/assets`（含单条路径）**、**`POST …/assets/corner-scape`**（无 Bearer → **401**；**`types`** 含非法值 → **400**；无 DB → **503**）、**`GET …/assets/…/images`**、**`PATCH`/`DELETE …/assets/…/images/{uuid}`**（无 Bearer → **401**；**`project_legacy_id≤0`** → **400**；无 DB → **503**）、**`GET …/assets?page=1&limit=2`**、**`GET …/assets`（组合 **`script_legacy_id`/`asset_type`/`name`/`page`/`limit`**）**、**`PUT`/`DELETE …/scripts/…/assets/…`**、**`GET`/`POST`/`PATCH`/`DELETE …/novels`**（含 **`GET …/novels?page&limit`**）、**`POST …/projects`**、**`GET`/`PATCH`/`DELETE …/projects/legacy/{id}`**、**`GET …/projects/legacy/{id}/stats`**、**`POST …/projects/legacy/{id}/scripts`**、**`GET`/`PATCH`/`DELETE …/scripts/legacy/{id}`**、**`GET`/`POST …/scripts/legacy/{id}/storyboards`**、**`GET`/`PATCH`/`DELETE …/storyboards/legacy/{id}`**、**`GET …/projects`**、**`GET`/`POST …/jobs`**（含 **`kinds`**/**`kinds/summary`**/**`status/summary`**、**`{id}`**、**`cancel`**/**`retry`**）、**`POST …/tasks/get-project`**/**`get-task-categories`**（**`{}`** + JWT → **503** 无 DB）、**`POST …/tasks/get-task-api`**（**`page`** 非法或 **`limit`** 越界 → **400**；合法体 + JWT 无 DB → **503**）、**`POST …/tasks/task-details`**（JWT → **501**）**、`**`POST …/general/get-single-project`**（JWT 无 DB → **503**）、**`POST …/general/update-project`**（仅 **`id`** → **400**；含补丁 + JWT 无 DB → **503**）、**`POST …/scripts/get-script-api`**（JWT 无 DB → **503**）**、`**`POST …/novels/get-novel-data`**/**`get-novel-index`**（JWT 无 DB → **503**）、**`POST …/novels/batch-delete`**（**`ids:[]`** → **400**；否则 JWT 无 DB → **503**）**、`**`POST …/project/get-project`**/**`delete-project`**/**`add-project`**/**`edit-project`**（无 Bearer → **401**；合法体 + JWT 无 DB → **503**；**`delete-project`**/**`edit-project`** 未知 **`id`** 需 DB 才得 **404**）**、`**`GET …/usage/summary`**、**`POST …/agents/memory/query|clear|append`**、**`GET`/`POST …/visual-manual`**（无 Bearer → **401**；有 JWT → **200**）、**`GET …/models/text-default`**（无 Bearer → **401**；有 JWT → **200**）、**`GET …/settings/vendors/summary`**（无 Bearer → **401**；有 JWT → **200**）、**`POST …/settings/vendors/model-test`**（**`type`** 非法 → **400**；合法体 → **501**）、**`POST …/settings/vendors/add`**/**`update`**/**`delete`**/**`enable`**/**`update-code`**/**`code-from-link`**（JWT → **501**；**`update`** 空 **`id`** 或 **`code-from-link`** 空 **`link`** → **400**）、**`POST …/settings/danger/delete-all-data`**/**`clear-database`**（**`{}`** + JWT → **501**）、**`POST …/production/get-production-data`**/**`get-flow-data`**/**`save-flow-data`**/**`workbench/generate-video`**/**`storyboard/polling-image`**/**`export-image`**（JWT → **501**）；**OpenAPI** 所列其余 **`POST …/production/*`**（**JSON object** + JWT → **501**；非 **object** 例 **`[]`** → **400**，样例 **`…/production/assets/get-assets-data`**）、**`POST …/settings/agent-deploy/list`**（无 Bearer → **401**；**`{}`** + JWT → **200**）、**`POST …/settings/agent-deploy/deploy-model`**/**`set-key`**（JWT → **501**）、**`POST …/script-agent/get-plan-data`**/**`set-plan-data`**/**`update-data`**（无 Bearer → **401**；合法体 + JWT → **501**）、**`POST …/assets-generate/generate`**/**`polish-prompt`**/**`batch-generate`**/**`batch-polish`**（JWT → **501**）、**`GET …/skills/binary`**（无 Bearer → **401**；**`path=… .md`** → **400**；**`path=_smoke/binary_probe.png`** → **200**）、**`GET …/skills/content`**、**`PUT …/skills/content`**（无 Bearer → **401**；**`..` path 或文件不存在** → **400**）、**`POST …/skills/content`**（无 Bearer → **401**；非法 **`..` path** → **400**；已存在文件 → **409**）、**`DELETE …/skills/content`**（无 Bearer → **401**；**`..` path** → **400**；不存在 → **404**；成功 → **204**；与 **`GET`/`PUT`/`POST`** 同路径 **POST→GET→DELETE→GET 404** 回合）、**`POST …/scripts/export`**/**`extract-state/poll`**/**`extract-assets`**、**`GET …/prompts`**、**`GET …/prompts/{id}`**（**`id`**∈**1–3**）、**`PATCH …/prompts/{id}`** 无 DB → **503** `database_error`；**`GET`/`PATCH …/prompts/<非 1–3>`** → **404**；**`GET …/me`**（有 JWT、无 DB → **200**，**`plan_tier`** 默认 **`free`**）；**`GET …/settings/dev/switch-ai-tool`**（无 Bearer → **401**；有 JWT → **200**）、**`PUT …/settings/dev/switch-ai-tool`**（无 Bearer → **401**；**`value`** 非 **0/1** → **400**；合法体 → **501** **`not_implemented`**）；**`GET`/`POST …/settings/memory-config`**（无 Bearer → **401**；同一 **`AppState`** 下 **GET 默认** + **POST** 后 **GET** 回读）；**`POST …/settings/memory-config/clear-agent-memories`**（无 Bearer → **401**；有 JWT、无 DB → **503**）；**`POST …/settings/about/check-update`**（无 Bearer → **401**；有 JWT → **200** **`needUpdate: false`**）；**`POST …/settings/about/download-app`**（无 Bearer → **401**；非法 **`url`** → **400**；合法 **`https://…`** → **501**）；**`GET …/projects/summary`**（无 Bearer → **401**；有 JWT、无 DB → **503**）、**`GET`/`POST …/art-styles`**、**`POST …/art-styles/extract-prompt`**（无 Bearer → **401**；**`images:[]`** 等 → **400**；否则无 **LLM** → **`llm_not_configured`**）、**`GET`/`PATCH`/`DELETE …/art-styles/legacy/{id}`** 同上；**`POST /api/v1/webhooks/billing`**（无效 HMAC → **401**；合法 **`x-toonflow-signature`**、无 **DB pool** → **503** **`database_error`**；并行测试 **`tokio::sync::Mutex`** 串行）。另 **`art_styles_crud_roundtrip`**、**`prompts_list_patch_roundtrip`**（**`#[ignore]`**）分别覆盖画风 **CRUD** 与 **prompts** 列表/**PATCH** 回读。

## 5. 分波实施建议（把「完整后端」拆成可合并的 PR）

下列顺序可按团队并行度调整；每一波应带 **OpenAPI 增量 + 迁移（若需）+ `contract_smoke` 或 PG 测试**。

| 波次 | 目标 | 依赖 |
|------|------|------|
| **A（当前基线）** | 项目/剧本/分镜、jobs、usage、memory、models、skills **GET** + **PUT/POST/DELETE …/skills/content**、harness、billing webhook、me | 已有 |
| **B** | **Script**：export + poll + **extract-assets** ✅（**`20260406120000_app_asset.sql`**） | 任务化/可观测加固、prompt 与旧库逐字对齐可选 |
| **C** | **Novel + event** 全表与 REST | **`app_novel` + 项目下 REST** ✅；**事件 / outline 等**仍待迁移、RLS |
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
