# Electron / Node 后端 → Rust 后端 Parity 清单

**目的**：把「用 Rust 重写完整后端」从口号拆成**可勾选、可排序**的条目；与文首 YAML **`product-shipping-bar`**、**`decommission-electron`** 对齐。  
**维护**：旧路由由 `src/core.ts` 生成 **`src/router.ts`**（`@routes-hash`）；新增或删除 `src/routes/**/*.ts` 后应复核本表对应行。

**阅读提醒**：本文同时承担 **parity 真源** 与 **兼容层盘点** 两种角色，因此会保留大量 numeric / legacy / compat 术语。引用其中的 project/script/jobs scope 现状时，应优先结合 [`product-deep-links.md`](../product-deep-links.md)、[`harness-ws-context-matrix.md`](./harness-ws-context-matrix.md)、[`tasks-http-api-cleanup.md`](./tasks-http-api-cleanup.md) 与 [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) 的较新 **UUID-first** 结论阅读。

## 0. 术语约定（避免 `legacy` 误读）

- 本仓库 **Postgres schema** 已逐步把 SQLite 时代的 `legacy_*` 统一收敛为：
  - **`numeric_*`**：SQLite-era 的整型标识（仍用于兼容路径/排序/可读 id）
  - **`import_*`**：导入期映射（例如 import user map）
  - **`import_staging`**：SQLite 快照 staging
- 本文档里出现的 `legacy_*`：
  - 若是 **Flutter/HTTP 兼容封装**的字段/函数名：属于兼容层命名，可能暂留
  - 若是在描述 **数据库列/落盘路径**：应以当前 schema 的 `numeric_*` 为准

## 1. 约定

| 维度 | 旧栈（Electron 内嵌 Node） | 新栈（`backend/`） |
|------|------------------------------|---------------------|
| HTTP 前缀 | `/api/...`（无版本段） | `/api/v1/...` |
| 鉴权 | JWT，`o_setting.tokenKey` | Supabase **`Authorization: Bearer`**（`SUPABASE_JWT_SECRET` 校验） |
| 主库 | SQLite（Knex 等） | **Supabase Postgres** + RLS（见 `supabase/migrations/`） |
| 实时 | Socket.IO（`src/socket/`） | **`GET /api/v1/ws`** + Harness 协议（`docs/websocket-events.md`） |
| 静态文件 | `/oss`、旧 **`/assets`** 静态路由、`/skills` 图片 URL | **Rust**：**`GET /api/v1/skills/binary?path=`**（`data/skills` 下受控文件）；**素材历史图** **`GET …/projects/{project_id}/assets/…/images/{id}/file`**（**`project_id`** UUID；**`https?`** 跳转或 **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** 下 PNG）；**不再复刻**旧栈 **`/oss`** 等 bulk 静态挂载（CDN/对象存储或独立服务，产品决定） |

## 2. 状态图例

| 符号 | 含义 |
|------|------|
| ✅ | 已在 Rust 提供等价或明确替代能力（见 OpenAPI / 实现） |
| 🟡 | 部分覆盖：竖切、子集、或仅数据模型一部分 |
| ⏳ | 未在 Rust 实现；需新迁移 + 路由 +（通常）Flutter 接线 |
| 🔀 | **不追求路径一对一**：换设计（如登录迁 Supabase、迁移工具独立二进制） |

### 2.1 前缀行计数快照（§3 表，约）

| 符号 | 行数 | 含义 |
|------|------|------|
| ✅ | **26** | 能力已对齐或明确替代（agents 记忆行、**`artStyle/*`**、**`assets/*`**、**`assetsGenerate/*`**、**`generalStatistics`**、**`general/getSingleProject+updateProject`**、**`project/*`**、**`quality/*`**、**`modelSelect`**（含旧 **`getTextModel`** / **`GET …/models/text-default`**）、**`novel/*`**、**`getVersion`**、**`deleteAllData`**、**`clearData`**、**`scriptAgent`**（REST 面）、**`test`**、**`setting/dev`**、**`setting/about`**、**`setting/agentDeploy`**、**`setting/memoryConfig`**、**`setting/promptManage`**、**`setting/skillManagement`**、**`setting/vendorConfig`**、**`task`**、**`cornerScape`**、**`script/*`**、**`production/**`**） |
| 🔀 | **4** | 换设计、不逐路径复刻（**`login`**、**`migrate`**、**`openFolder`**、**`loginConfig`**） |
| 🟡 | **0** | REST 前缀级显式缺口已收口；旧 Socket.IO 域能力已由 **`/api/v1/ws` + Harness** 承接（见 §3.1） |
| §3.1 Socket | **2** 行（均为 ✅） | 旧 **Socket.IO** 由 **`/api/v1/ws` + Harness** 承接；**不追求**协议字节级复刻，以领域工具 + Flutter 工作区为完成标准 |

**计数说明**：**一行**对应 **旧 `src/router.ts` 上一类前缀**（§3 左列），**不是**「二十一个独立产品模块」。**🟡** 表示该前缀下仍有 **501**、**⏳** 等待里程碑；合并同源前缀（如 **`/api/setting/getTextModel`** 并入 **`modelSelect`**）会减少 🟡 行数。

**⏳**：多数字段内嵌在 **🟡** 行备注（未单独成行）。更新 §3 表后应同步校正上表。

### 2.2 Workspace 与多用户可见性（相对旧 Electron）

#### 2.2.1 旧栈（Electron/Node）可见性规则

旧 Electron 栈是 **单机 SQLite**：项目与任务在直觉上等同于 **当前登录用户**，没有跨用户共享工作区的概念。所有数据（项目、剧本、分镜、资产、任务）均按 **`owner_user_id`** 严格隔离，仅创建者可见可操作。

**技术实现细节**：

- **数据库架构**：使用本地 SQLite 数据库（通过 Knex.js ORM），所有表均包含 `user_id` 或 `owner_user_id` 列作为数据隔离的主键之一。
- **鉴权机制**：基于 JWT token（存储在 `o_setting.tokenKey`），每次请求通过中间件验证 token 并提取 `user_id`，所有数据库查询自动附加 `WHERE user_id = ?` 条件。
- **项目可见性**：`o_project` 表的所有记录按 `user_id` 过滤，路由如 `/api/project/getProject` 仅返回当前登录用户创建的项目，无法查询或访问其他用户的项目。
- **剧本/分镜/资产**：
  - `o_script`（剧本）、`o_storyboard`（分镜）、`o_assets`（资产）表均通过 `user_id` 关联到创建者
  - 所有 CRUD 操作（`/api/script/*`、`/api/assets/*`）在 SQL 查询中强制 `WHERE user_id = current_user_id`
  - 无跨用户读取或共享机制，即使知道其他用户的资源 ID 也无法访问
- **任务（Jobs）**：`o_task` 表按 `user_id` 隔离，`/api/task/getTaskApi` 仅返回当前用户提交的任务，任务状态更新和结果查询均限定在用户自己的任务范围内。
- **Agent 记忆**：`o_agentMemory` 表按 `user_id` + `project_id` 组合隔离，每个用户在每个项目中有独立的记忆上下文，无法访问其他用户的记忆数据。
- **本地文件存储**：生成的图片、视频等文件存储在用户本地文件系统（通过 Electron 的文件 API），路径通常包含 `user_id` 或项目标识，确保文件级别的隔离。

**隐式单用户假设**：

- 旧栈设计时假设 Electron 应用运行在单用户桌面环境，每个应用实例对应一个登录用户
- 无 workspace 或 organization 概念，所有资源的"所有权"等同于"创建者身份"
- 无成员邀请、角色管理、权限委派等多用户协作功能
- 数据迁移或备份时，整个 SQLite 数据库文件（包含单个用户的所有数据）作为原子单元处理

#### 2.2.2 新栈（Rust/Flutter）Workspace 成员可见性规则

Rust 托管栈以 **`app_workspace` + `app_workspace_member`** 为空间边界：

- **项目**：`GET/PATCH/DELETE …/projects/{id}` 与多数 **`project_id` 段** 路由通过 **「项目所属 `workspace_id` + 当前用户是否为成员」** 校验可读可写，而不再以 **`project.owner_user_id`** 作为唯一闸门（`owner_user_id` 仍表示创建者/责任人）。
- **剧本/分镜/资产**：所有 **`…/projects/{project_id}/scripts`**、**`…/projects/{project_id}/assets`**、**`…/storyboards`** 等路由均按 **项目所属 workspace 的成员权限** 校验，workspace 内 `owner`/`admin`/`member` 均可访问（具体写权限按角色矩阵，见 `workspace-project-permission-policy.md`）。
- **生成任务**：`app_generation_job` **不双写** `workspace_id`；带 **`project_uuid`**（首选）或 **`project_numeric_id`**（legacy fallback）的 payload 时，可见性与操作权限由 **项目成员关系** 派生；无项目字段的任务仍主要按 **`owner_user_id`** 个人视图。
- **Agent 记忆**：`app_agent_memory` 仍按 **`owner_user_id`** 行级隔离；同一 workspace 内协作者各有一份记忆行。相关 HTTP 响应（含 **`cost-overview`**、**`query`** 列表项、**`append` / `clear` / `optimize`**）在需要处标明 **`scope: "user"`**，表示聚合与变更口径为 **当前用户行**，而非 workspace 级合并。
- **本地路径与通知**：部分落盘目录与 WS/job 通知仍按 **实际写入者/任务 owner** 对齐，避免成员代操作时把文件或事件发到错误用户（见 [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W4.5 备注）。

#### 2.2.3 主要差异点

| 维度 | 旧栈（Electron/Node） | 新栈（Rust/Flutter） |
|------|----------------------|---------------------|
| **工作空间类型** | 无显式概念，隐式单用户 | **`personal`**（个人）+ **`enterprise`**（企业） |
| **项目可见性** | 仅 `owner_user_id` 可见 | `personal`: 仅 owner；`enterprise`: 所有成员可见 |
| **剧本/分镜/资产** | 仅 owner 可见可操作 | workspace 成员按角色权限访问（owner/admin/member） |
| **Jobs 任务** | 仅 owner 可见 | 关联项目时：workspace 成员可见；无项目时：仅 owner |
| **Agent 记忆** | 仅 owner | 仍按用户隔离（`scope: "user"`），非 workspace 级合并 |
| **成员管理** | 不支持 | 支持邀请、角色分配（owner/admin/member）、移除 |

#### 2.2.4 迁移路径与向后兼容

- **自动创建 Personal Workspace**：用户首次登录新栈时，系统自动调用 `ensure_personal_workspace` 为其创建唯一的 `personal` workspace，并将现有项目的 `workspace_id` 指向该 personal workspace。
- **Personal Workspace 行为与旧栈一致**：`personal` workspace 中的项目仅所有者可见，禁止删除或归档 personal workspace，禁止用户离开自己的 personal workspace，确保单用户路径体验不受影响。
- **Enterprise Workspace 为新增能力**：用户可选择创建或加入 `enterprise` workspace 以启用团队协作，但不影响其 personal workspace 的独立性。
- **数据迁移**：旧 SQLite 数据通过 `toonflow-sqlite-import` + `promote_import_snapshots()` 导入时，自动归属到用户的 personal workspace，保持原有隔离性。

#### 2.2.5 Jobs（生成任务）可见性差异详解

**背景**：Jobs（生成任务，存储在 `app_generation_job` 表）是平台的核心异步工作负载，包括资产图片生成、prompt 优化、视频生成等。旧栈与新栈在 jobs 可见性上有显著差异。

##### 2.2.5.1 旧栈（Electron/Node）Jobs 可见性

- **严格按用户隔离**：`o_task` 表通过 `user_id` 列隔离，所有 jobs 查询（`/api/task/getTaskApi`）自动附加 `WHERE user_id = current_user_id` 条件
- **仅创建者可见**：用户只能查看、取消、重试自己提交的任务，无法访问其他用户的任务，即使任务关联到共享资源
- **无项目关联概念**：任务虽然可能在 payload 中包含项目信息，但可见性判定完全基于 `user_id`，不考虑项目归属或协作关系
- **本地通知**：任务完成通知仅发送给 `owner_user_id`，本地 artifact 下载目录也按任务所有者组织

##### 2.2.5.2 新栈（Rust/Flutter）Jobs 可见性

新栈引入 **workspace 成员可见性**，但 `app_generation_job` 表 **不直接存储 `workspace_id`**，而是通过 **payload 中的项目信息派生** workspace 关联：

**技术实现**：

- **`derive_workspace_from_job_payload` 函数**：优先从 job payload 中提取 `project_uuid`，缺失时回退 `project_numeric_id`，查询 `app_project` 表获取项目所属的 `workspace_id`
- **可见性规则**：
  - **关联项目的任务**：如果 payload 包含有效的项目标识，任务对项目所属 workspace 的所有成员可见（owner/admin/member）
  - **无项目关联的任务**：如果 payload 不包含项目信息或项目已删除，任务仅对 `owner_user_id`（任务创建者）可见
  - **权限校验**：查看任务详情、取消任务、重试任务均需满足"用户是任务 owner 或项目 workspace 成员"条件

**受影响的端点**：

- `GET /api/v1/jobs/page`：按 workspace 成员可见性过滤任务列表
- `GET /api/v1/jobs`：按 workspace 成员可见性过滤任务列表
- `GET /api/v1/jobs/kinds/summary` 与 `GET /api/v1/jobs/status/summary`：按 workspace 可见性聚合任务统计
- `GET /api/v1/jobs/{id}`：校验用户是否有权查看该任务
- `POST /api/v1/jobs/{id}/cancel`：校验用户是否有权取消该任务
- `POST /api/v1/jobs/{id}/retry`：校验用户是否有权重试该任务

**创建时校验**：

- `POST /api/v1/jobs` 在接收 payload 时，如果包含项目 scope（`project_uuid` 优先，`project_numeric_id` 为 legacy fallback），会校验当前用户是否为该项目所属 workspace 的成员
- 校验通过后，规范化 payload 中的项目字段（确保 `project_uuid` 和 `project_numeric_id` 一致）

**Worker 侧行为**：

- Worker 在执行任务并写回结果时（如 `video/voiceover/asset-image` 任务更新项目资源），也会按 workspace 成员权限校验写入权限
- 本地 artifact 下载目录与更新通知仍按 `job.owner_user_id` 对齐，避免成员代操作时把文件或事件发到错误用户

**向后兼容**：

- Personal workspace 中的任务行为与旧栈一致：项目仅所有者可见，关联项目的任务也仅所有者可见
- 无项目关联的任务（如全局配置测试任务）保持用户级隔离，不受 workspace 影响

##### 2.2.5.3 Jobs 可见性对比表

| 维度 | 旧栈（Electron/Node） | 新栈（Rust/Flutter） |
|------|----------------------|---------------------|
| **数据库隔离** | `o_task.user_id` 严格隔离 | `app_generation_job.owner_user_id` + 项目派生 workspace |
| **关联项目的任务** | 仅 owner 可见 | Workspace 成员可见（owner/admin/member） |
| **无项目关联的任务** | 仅 owner 可见 | 仅 owner 可见（与旧栈一致） |
| **任务列表查询** | `WHERE user_id = ?` | `WHERE owner_user_id = ? OR project.workspace_id IN (user_workspaces)` |
| **任务详情查看** | 仅 owner | Owner 或项目 workspace 成员 |
| **任务取消/重试** | 仅 owner | Owner 或项目 workspace 成员 |
| **任务创建校验** | 无项目成员校验 | 校验用户是否为项目 workspace 成员 |
| **通知与本地文件** | 发送给 owner | 仍发送给 owner（避免成员代操作混淆） |
| **Personal Workspace** | N/A（隐式单用户） | 行为与旧栈一致（仅 owner 可见） |
| **Enterprise Workspace** | N/A | 成员可见关联项目的任务 |

##### 2.2.5.4 实现细节参考

- **代码位置**：`backend/src/jobs/http.rs` 中的 `derive_workspace_from_job_payload` 函数和相关权限校验逻辑
- **设计文档**：`docs/plans/workspace-team-full-plan.md` Phase W4.5
- **测试覆盖**：`backend/src/jobs/http.rs` 中的集成测试验证 workspace 成员查看/操作 jobs 的权限矩阵

#### 2.2.6 资产/剧本/分镜可见性差异详解

**背景**：资产（Assets）、剧本（Scripts）、分镜（Storyboards）是项目的核心创作资源，旧栈与新栈在这些资源的可见性和权限控制上有显著差异。

##### 2.2.6.1 旧栈（Electron/Node）资产/剧本/分镜可见性

- **严格按用户隔离**：`o_assets`、`o_script`、`o_storyboard` 表均通过 `user_id` 列隔离，所有查询自动附加 `WHERE user_id = current_user_id` 条件
- **仅创建者可见可操作**：用户只能查看、编辑、删除自己创建的资产/剧本/分镜，无法访问其他用户的资源，即使这些资源关联到同一项目
- **无协作共享机制**：资源的"所有权"等同于"创建者身份"，不支持跨用户共享或委派权限
- **剧本-资产关联**：`o_scriptAssets` 表记录剧本与资产的关联关系，但关联关系也按 `user_id` 隔离，仅创建者可见
- **分镜图片**：分镜关联的图片（`o_image` 表）也按 `user_id` 隔离，仅创建者可查看和下载

**技术实现细节**：

- **数据库架构**：所有资源表均包含 `user_id` 或 `owner_user_id` 列作为主键之一，确保数据库层面的严格隔离
- **路由权限校验**：所有 CRUD 路由（`/api/assets/*`、`/api/script/*`、`/api/storyboard/*`）在 SQL 查询中强制 `WHERE user_id = current_user_id`
- **关联查询**：查询剧本关联的资产时（`/api/script/getScriptApi`），返回的 `relatedAssets` 仅包含当前用户创建的资产
- **导出功能**：剧本导出（`/api/script/exportScript`）、分镜导出（`/api/production/export-image`）仅导出当前用户创建的资源

##### 2.2.6.2 新栈（Rust/Flutter）资产/剧本/分镜可见性

新栈引入 **workspace 成员可见性**，资产/剧本/分镜的可见性和操作权限基于 **项目所属 workspace 的成员关系**：

**技术实现**：

- **项目归属校验**：所有资产/剧本/分镜路由首先通过 `project_id` 查询项目所属的 `workspace_id`，然后校验当前用户是否为该 workspace 的成员
- **统一权限 Helper**：`backend/src/workspaces/helpers.rs` 中的 `require_project_workspace_member_scope` 函数统一处理项目路径的成员权限校验
- **可见性规则**：
  - **Personal Workspace**：资产/剧本/分镜仅项目所有者可见，行为与旧栈一致
  - **Enterprise Workspace**：workspace 内所有成员（owner/admin/member）可查看项目下的资产/剧本/分镜
  - **操作权限**：按角色矩阵细化（见 `workspace-project-permission-policy.md`），例如 `member` 可查看但可能不可删除他人创建的资源

**受影响的端点**：

**资产（Assets）**：
- `GET /api/v1/projects/{project_id}/assets`：按 workspace 成员可见性过滤资产列表
- `POST /api/v1/projects/{project_id}/assets`：校验用户是否为项目 workspace 成员
- `GET /api/v1/projects/{project_id}/assets/{asset_id}`：校验成员权限
- `PATCH /api/v1/projects/{project_id}/assets/{asset_id}`：校验成员权限
- `DELETE /api/v1/projects/{project_id}/assets/{asset_id}`：校验成员权限
- `POST /api/v1/projects/{project_id}/assets/workbench/*`：所有 workbench 端点（nested、image-bundle、material-data、batch-generation-data、upload-clip、polling-image-assets、polling-prompt-assets、add-assets、save-assets、update-assets、del-assets、batch-delete、del-image）均按 workspace 成员权限校验

**剧本（Scripts）**：
- `POST /api/v1/projects/{project_id}/scripts/get-script-api`：按 workspace 成员可见性过滤剧本列表
- `POST /api/v1/projects/{project_id}/scripts/batch-add`：校验用户是否为项目 workspace 成员
- `GET /api/v1/projects/{project_id}/scripts/{script_legacy_id}`：校验成员权限
- `PATCH /api/v1/projects/{project_id}/scripts/{script_legacy_id}`：校验成员权限
- `DELETE /api/v1/projects/{project_id}/scripts/{script_legacy_id}`：校验成员权限
- `POST /api/v1/projects/{project_id}/scripts/export`：workspace 成员可导出项目剧本
- `POST /api/v1/projects/{project_id}/scripts/{script_legacy_id}/extract-assets`：workspace 成员可触发资产抽取
- `PUT /api/v1/projects/{project_id}/scripts/{s}/assets/{a}`：维护剧本-资产关联，校验成员权限
- `DELETE /api/v1/projects/{project_id}/scripts/{s}/assets/{a}`：删除剧本-资产关联，校验成员权限

**分镜（Storyboards）**：
- `POST /api/v1/production/get-production-data`：按 workspace 成员可见性返回分镜数据
- `POST /api/v1/production/storyboard/*`：所有分镜操作（读取、新增、批量补齐、预览、移除、更新 URL、polling-image）均按 workspace 成员权限校验
- `POST /api/v1/production/get-flow-data`：workspace 成员可查看项目的 flow 数据（包含分镜快照）
- `POST /api/v1/production/save-flow-data`：workspace 成员可保存 flow 数据并同步分镜索引
- `POST /api/v1/production/export-image`：workspace 成员可导出分镜图片

**小说（Novels）**：
- `GET /api/v1/projects/{project_id}/novels`：按 workspace 成员可见性过滤小说列表
- `POST /api/v1/projects/{project_id}/novels`：校验用户是否为项目 workspace 成员
- `GET /api/v1/novels/{novel_legacy_id}`：校验成员权限
- `PATCH /api/v1/novels/{novel_legacy_id}`：校验成员权限
- `DELETE /api/v1/novels/{novel_legacy_id}`：校验成员权限
- `GET /api/v1/projects/{project_id}/novel-events`：按 workspace 成员可见性过滤小说事件
- `POST /api/v1/projects/{project_id}/novel-events/generate-events`：workspace 成员可触发事件生成

**Workbench（工作台）**：
- `POST /api/v1/projects/{project_id}/assets/workbench/*`：资产工作台所有操作按 workspace 成员权限校验
- `POST /api/v1/production/workbench/*`：分镜工作台所有操作按 workspace 成员权限校验

**权限校验实现**：

- **代码位置**：`backend/src/workspaces/helpers.rs` 中的 `require_project_workspace_member_scope` 函数
- **校验逻辑**：
  1. 从 `project_id` 查询项目所属的 `workspace_id`
  2. 查询 `app_workspace_member` 表验证当前用户是否为该 workspace 的成员
  3. 如果用户不是成员，返回 `403 Forbidden` 错误
  4. 如果项目不存在或已删除，返回 `404 Not Found` 错误
- **统一应用**：所有项目路径的 handler（剧本、分镜、小说、资产、workbench）均通过该 helper 统一校验

**向后兼容**：

- **Personal Workspace**：资产/剧本/分镜仅项目所有者可见，行为与旧栈一致
- **数据迁移**：旧 SQLite 数据通过 `toonflow-sqlite-import` + `promote_import_snapshots()` 导入时，资产/剧本/分镜自动归属到用户的 personal workspace，保持原有隔离性
- **`owner_user_id` 保留**：资产/剧本/分镜表仍保留 `owner_user_id` 列记录创建者，用于审计和归属追踪，但可见性判定基于 workspace 成员关系

##### 2.2.6.3 资产/剧本/分镜可见性对比表

| 维度 | 旧栈（Electron/Node） | 新栈（Rust/Flutter） |
|------|----------------------|---------------------|
| **数据库隔离** | `user_id` 严格隔离 | `owner_user_id` + 项目所属 workspace 成员关系 |
| **资产可见性** | 仅创建者可见 | Personal: 仅 owner；Enterprise: workspace 成员可见 |
| **剧本可见性** | 仅创建者可见 | Personal: 仅 owner；Enterprise: workspace 成员可见 |
| **分镜可见性** | 仅创建者可见 | Personal: 仅 owner；Enterprise: workspace 成员可见 |
| **小说可见性** | 仅创建者可见 | Personal: 仅 owner；Enterprise: workspace 成员可见 |
| **剧本-资产关联** | 仅创建者可见 | Workspace 成员可查看和管理关联关系 |
| **资产图片** | 仅创建者可见 | Workspace 成员可查看和下载（按成员权限） |
| **导出功能** | 仅创建者可导出 | Workspace 成员可导出项目资源 |
| **批量操作** | 仅创建者可批量操作 | Workspace 成员可批量操作（按角色权限） |
| **Workbench 操作** | 仅创建者可操作 | Workspace 成员可操作（按角色权限） |
| **权限校验** | `WHERE user_id = ?` | `require_project_workspace_member_scope` helper |
| **Personal Workspace** | N/A（隐式单用户） | 行为与旧栈一致（仅 owner 可见） |
| **Enterprise Workspace** | N/A | 成员可见项目下的所有资产/剧本/分镜 |

##### 2.2.6.4 实现细节参考

- **代码位置**：
  - `backend/src/workspaces/helpers.rs`：`require_project_workspace_member_scope` 统一权限校验
  - `backend/src/assets/http.rs`：资产路由权限校验
  - `backend/src/scripts/http.rs`：剧本路由权限校验
  - `backend/src/production/`：分镜路由权限校验
  - `backend/src/novels/http.rs`：小说路由权限校验
  - `backend/src/workbench/http.rs`：工作台路由权限校验
- **设计文档**：`docs/plans/workspace-team-full-plan.md` Phase W4.4
- **权限策略**：`docs/plans/workspace-project-permission-policy.md`
- **测试覆盖**：各模块的集成测试验证 owner/admin/member/outsider 访问项目资源的权限矩阵

#### 2.2.7 示例场景对比

**场景 1：单用户创作（Personal Workspace）**

| 操作 | 旧栈行为 | 新栈行为 |
|------|---------|---------|
| 创建项目 | 项目归属当前用户，仅自己可见 | 项目归属 personal workspace，仅自己可见 |
| 查看剧本 | 仅自己创建的剧本可见 | 仅 personal workspace 内的剧本可见（等同于自己创建） |
| 查看资产 | 仅自己创建的资产可见 | 仅 personal workspace 内的资产可见（等同于自己创建） |
| 查看分镜 | 仅自己创建的分镜可见 | 仅 personal workspace 内的分镜可见（等同于自己创建） |
| 查看任务 | 仅自己提交的任务可见 | 仅自己提交的任务可见（personal workspace 内） |
| 邀请协作者 | 不支持 | Personal workspace 不支持邀请（需创建 enterprise workspace） |

**场景 2：团队协作（Enterprise Workspace，新栈独有）**

| 操作 | 旧栈行为 | 新栈行为 |
|------|---------|---------|
| 创建项目 | N/A（不支持团队） | 项目归属 enterprise workspace，所有成员可见 |
| 查看剧本 | N/A | workspace 内所有成员可查看项目下的剧本 |
| 编辑剧本 | N/A | workspace 成员可编辑剧本（按角色权限） |
| 查看资产 | N/A | workspace 内所有成员可查看项目下的资产 |
| 编辑资产 | N/A | `owner`/`admin` 可编辑；`member` 按角色矩阵权限 |
| 查看分镜 | N/A | workspace 内所有成员可查看项目下的分镜 |
| 编辑分镜 | N/A | workspace 成员可编辑分镜（按角色权限） |
| 导出资源 | N/A | workspace 成员可导出剧本/分镜（按角色权限） |
| 批量操作 | N/A | workspace 成员可批量操作资产/剧本（按角色权限） |
| 查看任务 | N/A | 关联项目的任务对 workspace 成员可见 |
| 成员管理 | N/A | `owner` 可邀请/移除成员、分配角色；`admin` 可邀请/管理成员但不可删除空间 |

**场景 3：跨 Workspace 切换（新栈独有）**

| 操作 | 旧栈行为 | 新栈行为 |
|------|---------|---------|
| 切换工作空间 | N/A | 用户可在 personal 和多个 enterprise workspace 间切换 |
| 离开 Enterprise | N/A | 离开后自动回退到 personal workspace，原 enterprise 项目及其资产/剧本/分镜不再可见 |
| Personal 始终可用 | N/A | Personal workspace 始终存在且可访问，作为用户的"私有空间" |

详细任务勾选以 **`workspace-team-full-plan.md`** Phase W4–W5 为准。

## 3. 按旧路由前缀总览（对应 `src/router.ts`）

| 旧前缀 | 功能域 | Rust / 契约 | 备注 |
|--------|--------|-------------|------|
| `/api/agents/clearMemory`、`getMemory` | Agent 记忆 | ✅ `POST /api/v1/agents/memory/clear`、`query`、`append`、`optimize`、`cost-overview`；变更类响应含 **`scope: "user"`**（按 `owner_user_id` 行级口径，见 §2.2）；Flutter **`queryAgentMemory`**、**`clearAgentMemory`**、**`appendAgentMemory`**；Projects 主区“记忆工作台” | 旧「按 type 清」语义已对齐方向 |
| `/api/artStyle/*` | 画风库 CRUD / 抽 prompt | ✅ | **`app_art_style` + REST**；**`promote_import_snapshots()`** 含 **`o_artStyle`→`app_art_style`**（**`owner_user_id`** 见迁移说明）；**`GET`/`POST /api/v1/art-styles`**、**`GET`/`PATCH`/`DELETE …/art-styles/numeric/{id}`**（RLS）；**`POST /api/v1/art-styles/extract-prompt`**（OpenAI 形 **`image_url`**，对齐 **`extractStylePrompt`** 系统提示词；空 **`images`** / 全空白项 → **400**；合法体、**无 LLM** → **503** **`llm_not_configured`**）；**`file_url`** 现支持 **`data:image/...;base64,...`** 或原始 **base64**：配置 **`TOONFLOW_LOCAL_ART_STYLE_COVER_DIR`** 后落盘到 **`{dir}/{user}/{numeric_id}.{ext}`**，并通过 **`GET /api/v1/art-styles/numeric/{id}/cover`**（JWT）读取，替代旧 **base64→OSS** 流；Flutter **`fetchArtStyles`** / **`createArtStyle`** / **`fetchArtStyleByNumericId`** / **`patchArtStyleByNumericId`** / **`deleteArtStyleByNumericId`** / **`extractArtStylePrompt`** 已接入 Projects 页“画风工作台”，支持列表刷新、封面预览、CRUD 与多图 prompt 抽取；首页旧 **GET** 后 **create→get→patch→del** 探针保留为回归入口（自删 **`[flutter probe art-style]*`** 行）；新增 widget test **`frontend/test/projects_section_test.dart`**；**无 DB 烟雾**（CRUD + cover）→ **503**；**`contract_smoke`**：**`POST …/extract-prompt`** → **`llm_not_configured`**；**`pg_contract`** **`art_styles_crud_roundtrip`** / **`art_styles_base64_cover_roundtrip`** / **`promote_staging_*`**；自有 OSS/CDN 仍由产品与运维后续决定 |
| `/api/assets/*` | 素材 CRUD、轮询出图等 | ✅ | **CRUD（无出图）**：**`POST/GET/PATCH/DELETE …/projects/{project_id}/assets`**（**`project_id`** = **`app_project.id`**, UUID）；**`GET` 列表**：**`{ items, total }`**，可选 **`script_legacy_id`**、**`asset_type`**、**`name`**、**`page`/`limit`**；资产 **workbench**（**`POST …/projects/{project_id}/assets/workbench/{nested,image-bundle,material-data,batch-generation-data,upload-clip,polling-image-assets,polling-prompt-assets,add-assets,save-assets,update-assets,del-assets,batch-delete,del-image}`**；path **`project_id`** = **`app_project.id`** UUID；**已删除**顶层 **`POST /api/v1/assets/*`**）：**`nested`**（body **`type`/`name`/`page`/`limit`**）返回父级 + **`sonAssets`**（**`metadata.assetsId`**）；**`stats.role_count`**；**`image-bundle`**（body **`assetsId`**）返回 **`{ id, imageId, tempAssets[] }`**（**`selected`** 由 **`metadata.imageId`**；**`tempAssets[].id`** = **`numeric_image_id`** 或 **`null`**）；**`polling-image-assets`** / **`polling-prompt-assets`**（body **`ids[]`**）语义同旧；**`material-data`**（body **`{}`**）→ **`{ data, video }`**；**`batch-generation-data`**（**`type`/`name`/`page`/`limit`**）→ **`{ data, total }`**；**`upload-clip`**（**`base64Data`/`name`/`type`**=clip）；**`add-assets`** / **`save-assets`** / **`update-assets`** / **`del-assets`** / **`batch-delete`** / **`del-image`** 对齐旧 Electron 写语义；**`GET …/assets/{aid}/images`****`GET …/assets/{aid}/images`** 返回 **`cover_numeric_image_id`**（**`metadata.imageId`**）与每项 **`selected`**，**`PATCH …/assets/{aid}`** 可写 **`cover_numeric_image_id`**（校验对应 **`app_asset_image.numeric_image_id`**），部分对齐封面写入（无 OSS 署名 **`filePath`**）；Flutter **`rust_api`**：**`fetchProjectAssetsByProjectId`**（含 **`page`/`limit`**）、**`fetchProjectAssetByProjectIds`**、**`createProjectAssetUnderProject`**、**`patchProjectAssetByProjectIds`**、**`deleteProjectAssetByProjectIds`**、**`postLegacyAssetsGetImage`**、**`postLegacyAssetsUploadClip`**、**`postLegacyAssetsGetMaterialData`**、**`postLegacyAssetsBatchGenerationData`**、**`postLegacyAssetsPollingImageAssets`**、**`postLegacyAssetsPollingPromptAssets`**、**`linkScriptToAssetByProjectIds`** / **`unlinkScriptFromAssetByProjectIds`**；项目详情资产主区现已先收口为“资产主工作台”统一入口，把资产 CRUD、剧本关联、高级筛选、编辑图上传与 Clip 上传合并进同一正式对话框，并保留“资产图片工作台”“资产出图工作台”“资产历史图工作台”处理各自专门流程；兼容性折叠区继续保留旧 probe 回归入口。**无 DB 烟雾**：**`GET …/assets?page=1&limit=2`**、**`GET …/assets?script_legacy_id&asset_type&name&page&limit`**、**`POST …/projects/{project_id}/assets/workbench/nested`**、**`…/image-bundle`**、**`…/material-data`**、**`…/batch-generation-data`**、**`…/upload-clip`**、**`…/polling-image-assets`**、**`…/polling-prompt-assets`**、**`…/add-assets`**、**`…/save-assets`**、**`…/update-assets`**、**`…/del-assets`**、**`…/batch-delete`**、**`…/del-image`** → **503** **`database_error`**（参数非法场景按 **400**）；**`pg_contract`** 新增 **`assets_upload_clip_roundtrip`**、**`assets_legacy_mutation_endpoints_roundtrip`**、**`assets_get_assets_api_parent_child_roundtrip`**、**`assets_polling_image_and_prompt_filters_roundtrip`**、**`assets_batch_generation_data_filters_roundtrip`**（upload-clip 选中语义 + workbench 资产写操作 + nested 父子分页聚合 + polling 状态过滤 + batch-generation-data 过滤分页语义）；**出图任务**走 **`POST …/assets-generate/*`** + **`app_generation_job`** |
| `/api/assetsGenerate/*` | 素材批量生成 / polish | ✅ | 五路 **`POST …/assets-generate/{generate,polish-prompt,batch-generate,batch-polish,cancel-generate}`**：前四路校验体 + 项目归属 + 配额 → 入队对应 **`kind`**（单条 **`asset.generate.image`**/**`asset.polish.prompt`**；批量 **`asset.generate.batch`**/**`asset.polish.batch`**）；**`cancel-generate`** 兼容旧 `cancelGenerate`，按 **`numeric_image_id`**（SQLite `o_image.id`）将 caller-owned **`app_asset_image.state`** 置为 **`生成失败`**，并协同取消该资产关联的 caller-owned queued/running 任务（避免 worker 反写覆盖）。**`asset.polish.*`**：chat completion；**`asset.generate.*`**：在有 `image_base64` 时走 provider **`images/edits`**（multipart reference image），无参考图时走 **`images/generations`**，并插入 **`app_asset_image`**（无 **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** 时 **`file_path`** = 供应商临时 **`url`**；配置目录则落盘 PNG 且 **`file_path`** = **`GET …/images/{id}/file`** 路径，**`metadata.storage`** = **`local`**，**`metadata.provider_url`** 保留原链接）；历史 **`base64`** 已在入队时标准化并保存在 payload **`image_base64`**（raw 自动转 data URI），worker 结果会回传 **`has_reference_image`**。**`GET …/images/{id}/file`**：**`https?`** → **307**，**`local`** → **200 **`image/png`**（**`Cache-Control: private, max-age=300`**）；均在 **`OPENAI_API_KEY`/`LLM_API_KEY`** 已配置且 worker 可达模型时 **`succeeded`**，否则 **`failed`**。Flutter 同上；项目资产“资产出图工作台”现已把 production 摘要、图片状态、prompt 状态联动成单次摘要同步，并在批量发起、清理衍生图、更新封面 URL 后自动回刷当前选择状态；切换类型过滤或资产列表回刷时也会尽量保留仍可见的选择与焦点资产，避免连续出图时反复重选。首页 models 探针五路均 **200**/**404**/**429**/**503**（`cancel-generate` 接受 **200/503**）；**`pg_contract`** **`assets_generate_enqueue_four_kinds`**、**`assets_generate_cancel_generate_roundtrip`**（覆盖图状态 + 单条/batch 关联 job 取消，且无关 job 不受影响）、**`asset_image_file_local_storage_roundtrip`**（**`AppState.local_asset_image_dir`** + 磁盘 **`{user}/{image_id}.png`** + **`GET …/file`** → **200 **`image/png`**） |
| `/api/cornerScape/getAllAssets` | 角落素材 | ✅ | **`POST /api/v1/projects/{project_id}/assets/corner-scape`**（JWT；**`project_id`** = **`app_project.id`**, UUID）：父级资产（**`metadata.assetsId`** 缺失或 JSON **`null`**）、**`types`** 可选过滤、**role → scene → tool** 排序；**`history_images`** 来自 **`app_asset_image`**（**`state = '已完成'`**；含可选 **`numeric_image_id`** 对齐 SQLite `o_image.id`）；**`metadata`** 为父 **`app_asset`** 快照；**`GET`/`POST …/projects/{project_id}/assets/{aid}/images`** 列表（含任意 **`state`**，按 **`sort_index`/`created_at`**）/写入、**`GET …/images/{image_id}`** 单条、**`GET …/images/{image_id}/file`**（**`https?`** **`file_path`** → **307**；**`metadata.storage=local`** → **200** **`image/png`**；未配 **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** 而行为 **`local`** → **503**）、**`PATCH`/`DELETE …/images/{image_id}`** 更新/删除 **`app_asset_image`**（**`PATCH`** 至少一改；**`state`** 清空则不再计入 corner **`history_images`**）；Flutter **`fetchCornerScapeAssetsByProjectId`**（**`CornerScapeAssetItem`** / **`CornerScapeHistoryImage`**）、**`fetchProjectAssetImagesByProjectIds`** / **`fetchProjectAssetImageByProjectIds`** / **`fetchProjectAssetImageFileByProjectIds`**（**`projectAssetImageFileV1UriByProjectId`**）/ **`createProjectAssetImageForProject`** / **`patchProjectAssetImageByProjectIds`** / **`deleteProjectAssetImageByProjectIds`**；项目对话框 **POST 首条资产图片** + **GET 列表后 GET …/images/{id} 单条** + **POST→PATCH（`state`/`sort_index`）→DELETE 自删探针图**；资产图片工作台现已补共享诊断卡与 follow-up，会根据“未同步列表 / 尚无图片 / 尚未预览 / 已可编辑”自动推荐下一步，并把列表同步、预览、增删改动作统一写回下一步建议；**POST corner-scape** 探针在 **`history_images`** 非空时尝试 **`fetchCornerScapeHistoryImagePreviewBytes`**（**`https?`** 直拉 / 否则 **`…/file`**）并 **SnackBar 缩略图**；**`pg_contract`** 已覆盖 corner 列表/单条/PATCH 过滤链路，并补充 `types` 空白/重复归一化回归 |
| `/api/quality/*` | 质量评估 / bad case 统计 | ✅ | **`POST`/`GET /api/v1/quality/reviews`**、**`GET /api/v1/quality/reviews/{id}`**、**`GET /api/v1/quality/stats`**、**`GET /api/v1/quality/stage-pass-rate`** 已在 Rust 落地并写入 **`app_quality_review`**；OpenAPI 已补齐；**`contract_smoke`** 覆盖无 Bearer → **401**、合法 Bearer + 无 DB → **503**，且 **`POST /quality/reviews`** 对 **`targetType`** / **`source`** / **`badCaseCategory`** 做前置 **400** 校验；**`pg_contract`** **`quality_reviews_roundtrip`** 覆盖 **POST 两条 review → 按 `targetType+targetId` / `isBadCase` 过滤列表 → `GET /{id}` → `stats` / `stage-pass-rate` 聚合回读**；Flutter **`rust_api`** 已补类型化 client，首页“质量评审”主区现已升级为正式工作台入口，可在一个对话框中完成评审筛选、坏例查看、统计/阶段通过率读取、单条详情查询与手动创建；旧 **POST probe review** 已下沉到兼容性折叠区，仅保留回归职责 |
| `/api/general/generalStatistics` | 多项目统计 | ✅ `GET /api/v1/projects/summary`（含 **`novel_count`**、**`role_count`**、**`art_style_count`**、**`video_count`**（占位 **0**）） | 单项目见 **`…/stats`**（**`novel_count`** + **`role_count`** 等） |
| `/api/general/getSingleProject`、`updateProject` | 项目读写 | ✅ | **HTTP**：**`GET`/`PATCH …/projects/{project_id}`**（**`project_id`** = **`app_project.id`**, UUID）。**已删除** **`POST /api/v1/general/get-single-project`** 与 **`POST …/general/update-project`**。Flutter **`postGeneralGetSingleProject`**（分页 **`GET /api/v1/projects`** + 按 **`legacy_id`** 过滤）、**`postGeneralUpdateProject`**（解析 UUID 后 **`PATCH …/projects/{project_id}`**，字段 **`type`→`mode`** 等）、**`updateProjectByProjectId`**；项目详情探针仍用上述 compat 名 + **`PATCH …/projects/{project_id}`**（**`name`** noop）；**`pg_contract`** **`projects_patch_partial_fields_roundtrip`** 锁定 **`PATCH`** 的 **`null` 清空与未改字段保持** |
| `/api/login/login` | 本地账号登录 | 🔀 | **Supabase Auth**（Flutter `supabase_flutter`） |
| `/api/migrate/migrateData` | 数据迁移 | 🔀 | **`toonflow-sqlite-import`** + **`promote_import_snapshots()`**（含 **`o_novel`→`app_novel`**、**`o_assets`→`app_asset`**、**`o_scriptAssets`→`app_script_asset`**、**`o_artStyle`→`app_art_style`**、**`o_prompt`→`app_user_prompt`**、**`o_image`→`app_asset_image`**（**`numeric_image_id`** 幂等，对齐 SQLite `o_image.id`）；返回 **`asset_images_upserted`** 等九列；非 HTTP 热路径） |
| `/api/modelSelect/getModelList`、`getModelDetail`；**`/api/setting/getTextModel`**（并入） | 模型目录 + 文本模型默认 | ✅ `GET /api/v1/models`、`/api/v1/models/detail`、**`GET`/`PATCH /api/v1/models/text-default`**（旧 **`getTextModel`** 占位 **`"123"`** 与旧 **`/api/setting/getTextModel`** 均由 **`stub_placeholder`** + **`default_model_id`** 替代；可选 **`TOONFLOW_DEFAULT_TEXT_MODEL_ID`**）；Flutter **`fetchTextModelDefaultV1`** / **`patchTextModelDefaultV1`**（首页 **`GET+PATCH+reset text-default`** 探针） | 静态 JSON 嵌入；更完整的偏好设置页仍可与 **`vendorConfig`** 合并 ⏳ |
| `/api/novel/*` | 小说与事件管线 | ✅ | **`app_novel` + UUID 项目段 REST**：**`GET`/`POST …/projects/{project_id}/novels`**、**`GET`/`PATCH`/`DELETE …/novels/{novel_legacy_id}`**（**`novel_legacy_id`** = **`app_novel.legacy_id`**）。**已删除** HTTP **`/api/v1/novels/*`**（原 Electron 形 **`get-novel-data`** / **`get-novel-index`** / **`get-novel`** / **`add-novel`** / **`update-novel`** / **`delete-novel`** / **`batch-delete`** / **`get-novel-event-state`** 等）。**事件**：**`GET`/`POST …/projects/{project_id}/novel-events`**、**`PATCH`/`DELETE …/novel-events/{event_legacy_id}`**、**`POST …/novel-events/batch-delete`**、**`POST …/novel-events/generate-events`**（body **`novelIds`** + **`concurrentCount`**；异步重置所选章节 **`event_state=0`** 后 LLM 抽取；无 LLM 时落 **`event_state=-1,error_reason=llm_not_configured`**）。Flutter **`rust_api`**：**`fetchProjectNovelsByProjectId`** / **`createProjectNovelUnderProject`** / **`patchProjectNovelByProjectIds`** / **`deleteProjectNovelByProjectIds`**；**`fetchProjectNovelEventsByProjectId`**、**`createProjectNovelEventUnderProject`**、**`patchProjectNovelEventByProjectIds`**、**`deleteProjectNovelEventByProjectIds`**、**`postProjectNovelEventsBatchDeleteByProjectId`**。兼容名 **`postLegacyNovels*`** / **`postLegacyNovelEvents*`** 仍为 **Dart 侧封装**（内部 **`GET`/`POST`/`PATCH`/`DELETE`** 上述 REST；**`postLegacyNovelsGetNovelEventState`** 需传入项目 **`projectUuid`**；**`postLegacyNovelEventsGenerateEvents`** 使用 **`projectLegacyId:`** 解析 UUID 后调 **`generate-events`**）。项目详情「小说与事件」主区仍以章节/事件工作台为主；兼容性折叠区保留 **`postLegacy*`** 探针。**无 DB 烟雾**：列表/写入等 → **503**；**`contract_smoke`** 已改为测 **`…/projects/{uuid}/novels*`** 与 **`…/novel-events*`**。**`pg_contract`**：**`projects_create_stats_delete_roundtrip`** 已串联 **REST 小说**（列表/分页/创建/**`PATCH`**/搜索/**`DELETE`**）与 **novel-events CRUD**；**`novel_events_generate_events_async_fallback_roundtrip`** 覆盖 **`generate-events`**；独立 **`o_outline`** / **`o_outlineNovel`** 仅作迁移源，旧路由侧本就无独立 SaaS API |
| `/api/other/getVersion` | 版本号 | ✅ `GET /api/v1/version` | |
| `/api/other/deleteAllData` | 清空数据 | ✅ | **HTTP**：**`POST /api/v1/settings/danger/delete-all-data`** 继续 **501**（Hosted API 不暴露批量清库）；**运维替代**：**`cargo run --bin toonflow-server -- ops clear-user-data --user-id <uuid> --dry-run`**，确认后再 **`--execute --confirm clear-user-data:<uuid>`** |
| `/api/production/**` | 分镜图/视频工作台、流、导出 | ✅ | **`backend/src/production/`**（**`mod.rs` + `workbench/`**）已覆盖 **`POST /api/v1/production/*`**：分镜图读取/新增/批量补齐/预览/移除/更新 URL、资产批量出图与派生删除、edit-image flow（含 **`POST /api/v1/production/edit-image/upload-image`**）、视频轨增删、视频列表/选择/删除、视频 prompt / model detail / generate-data，以及 **`get-production-data`**、**`get-flow-data`**、**`save-flow-data`**、**`workbench/generate-video`**、**`storyboard/polling-image`**、**`export-image`**。其中 **`get/save-flow-data`** 已恢复 历史 **`o_agentWorkData`** 语义：PG 持久化整份 flow JSON，并在读取时回填实时 **script/assets/storyboard** 快照，保存时会按 storyboard 数组顺序同步 **`app_storyboard.sb_index`**。这些路由在缺少所属资源时返回 **200/404**，无 DB 时返回 **503**；Flutter 调试区按真实请求体逐条探测。**`pg_contract`** 覆盖 **`production_workbench_video_roundtrip`**、**`production_assets_derivative_roundtrip`**，并补充 **`upload-image`** 回归。旧 production Socket.IO Agent 域工具/执行语义缺口转移到 §3.1（Harness 迁移项）。 |
| `/api/project/*` | 项目、导演/视觉手册 | ✅ | **项目 CRUD（Electron `getProject`/`addProject`/…）已收敛为 **`GET`/`POST`/`PATCH`/`DELETE /api/v1/projects*`**；Flutter **`postProjectGetProject`** 等 compat 名保留，内部走 UUID REST。**`POST …/query-director-manual`** 等手册路由仍见 OpenAPI；**`postProjectQueryDirectorManual`**、**`postProjectAddDirectorManual`**、**`postProjectEditDirectorManual`**、**`postProjectDeleteDirectorManual`**、**`postProjectAddVisualManual`**、**`postProjectEditVisualManual`**、**`postProjectDeleteVisualManual`**（**`LegacyDirectorManualDataSlot`** / **`LegacyDirectorManualListResponse`**）；首页 Projects 主区“创作手册工作台”与 **`GET/POST /api/v1/visual-manual`** 交叉校验；**`contract_smoke_tests`** 含导演/视觉手册路径；**`pg_contract`** **`legacy_project_crud_roundtrip`** 覆盖 **`/api/v1/projects`** 创建/列表/补丁/删除语义 |
| `/api/script/*` | 剧本 CRUD、导出、抽素材 | ✅ | CRUD ✅（**`GET`/`PATCH`/`DELETE …/projects/{project_id}/scripts/{script_legacy_id}`**，**`project_id`** UUID）；**export** / **poll** / **`extract-assets`** ✅；**`PUT/DELETE …/projects/{project_id}/scripts/{s}/assets/{a}`**（**`project_id`** UUID）维护 **`app_script_asset`** ✅；**`POST …/projects/{project_id}/scripts/get-script-api`**（可选 **`name`**）→ 剧本列表 + **`relatedAssets`**（**`legacy_id`**）；**`POST …/projects/{project_id}/scripts/batch-add`** 对齐旧 **`batchAddScript`**（归属校验 + 事务批量写入）；Flutter **`postScriptsGetScriptApiByProjectId`**、**`postScriptsBatchAddByProjectId`**、**`fetchScriptByProjectAndLegacyId`**、**`updateScriptByProjectAndLegacyId`**（**`name`** 同值 noop）、**`exportScriptsZip`**、**`pollScriptExtractState`**、**`startScriptAssetExtract`** 已被项目详情“剧本批量工作台”与单剧本工作台共同消费：前者支持按名称读取上下文、显式编辑目标 id 集合并批量导出/轮询/抽取/创建，且现已新增批量诊断卡，把“未选择 / 提取中 / 提取失败 / 已有素材 / 仍待抽取 / 缺少上下文快照”直接映射到推荐批量动作，并在轮询/提交抽取后立即同步预览提取状态、把“动作结果 + 下一步建议”直接写回工作台；项目详情剧本摘要区也会复用同一诊断逻辑，在缺少素材上下文时优先引导打开工作台读取快照，而不是盲目建议抽取；后者聚焦单剧本上下文与导出/抽取，并新增基于上下文/提取状态/关联素材的诊断卡与推荐动作，直接把“先同步、轮询、重试抽取、进编辑图片”收口为明确按钮，且在导出/轮询/抽取/返回编辑图片后继续给出下一步建议。 |
| `/api/scriptAgent/*` | 剧本 Agent 计划数据 | ✅ | **`POST /api/v1/script-agent/get-plan-data`**、**`set-plan-data`**、**`update-data`**：Postgres **`app_script_agent_plan`** + **`app_script`**（JWT + **`app_project.legacy_id`**）；历史 **`{ code, data, message }`** 包壳；Flutter 同上；首页 models 探针接受 **200** / **404** / **503**；实时流仍以 **Harness WS** 承接，不再要求 Socket.IO 一对一 |
| `/api/setting/about/*` | 更新检查、安装包 | ✅ | **`POST /api/v1/settings/about/check-update`**：**`source`** 同旧枚举，**不拉 OSS**，改读环境变量清单 **`TOONFLOW_UPDATE_LATEST_VERSION`** / **`TOONFLOW_UPDATE_TIME`** / **`TOONFLOW_UPDATE_{SOURCE}_URL`** 并与服务端 **`CARGO_PKG_VERSION`** 比较；未配置时安全回退到 **`needUpdate: false`**。**`POST …/download-app`** 仍仅校验 **`url`** 后返回 **200** 策略消息，明确 Flutter 版应走平台商店、分发页或浏览器下载，而不是 Electron 本地安装器；OpenAPI **`postAboutCheckUpdateV1`** / **`postAboutDownloadAppV1`**；Flutter 探针 |
| `/api/setting/agentDeploy/*` | 本地 Agent 部署配置 | ✅ | **`POST /api/v1/settings/agent-deploy/list`**：**`{}`** 体返回 **`initDB`** 四条默认行，并在有 PG 时叠加 **`app_user_profile.agent_deploy_config`** 的当前用户模型选择；**`POST …/deploy-model`** 按内建 **`id`** 持久化 **`model`** / **`modelName`** / **`vendorId`**（无 DB → **503**，未知 id → **400**）；**`POST …/set-key`** 为显式 **200** no-op，提示密钥仍只能走服务端环境变量/密钥管理；OpenAPI、无 DB 烟雾、**`settings_agent_deploy_roundtrip`** PG 回归、Flutter **`postAgentDeployListV1`** / **`postSettingsAgentDeployModelV1`** / **`postSettingsAgentDeploySetKeyV1`** 与首页 models 探针已对齐完成态 |
| `/api/setting/dbConfig/clearData` | 清库 | ✅ | **`POST /api/v1/settings/danger/clear-database`**（旧为 **GET**；SaaS 用 **POST** 体 **`{}`**）保持 **501**；正式替代路径同上，走受控 **`ops clear-user-data`** CLI；Flutter **`postSettingsDangerClearDatabaseV1`** 仍以 **501** 视为预期 |
| `/api/setting/dev/*` | Dev 开关 | ✅ | **`GET /api/v1/settings/dev/switch-ai-tool`**（**`value`** **`"0"`**/**`"1"`**）返回当前进程内生效值；**`PUT`** 校验后更新同一进程内 override，并可立即 **GET** 回读，对齐 **`getSwitchAiDevTool`** / **`updateSwitchAiDevTool`** 的开关语义。服务启动时以 **`TOONFLOW_SWITCH_AI_DEV_TOOL`** 为初值，重启后回到 env/default；OpenAPI **`getSwitchAiDevToolV1`** / **`putSwitchAiDevToolV1`**；Flutter **`fetchSwitchAiDevToolV1`** / **`putSwitchAiDevToolV1`** + 首页探针 |
| `/api/setting/fileManagement/openFolder` | 打开本地目录 | 🔀 | 桌面端本地能力，非 HTTP |
| `/api/setting/loginConfig/*` | 用户密码 | 🔀 | Supabase 账户体系 |
| `/api/setting/memoryConfig/*` | 记忆配置 UI | ✅ | **RAG / 摘要数值与 ONNX 路径**：**`GET`/`POST /api/v1/settings/memory-config`**（**camelCase**，默认同 **`initDB`** **`o_setting`**；按用户持久化到 **`app_user_profile.memory_config`**，服务端默认值兜底；无 DB 时 **503**）；**`delAllMemory`** → **`POST /api/v1/settings/memory-config/clear-agent-memories`**（需 **`projectId`+`agentType`**，等同 **`agents/memory/clear`** **`clearType: all`**，非 SQLite 全表删）；OpenAPI、无 DB 烟雾、**`settings_memory_config_and_clear_agent_memories_roundtrip`** PG 回归，以及 Flutter **GET→POST→恢复** / **`clear-agent-memories`** 探针均已对齐完成态 |
| `/api/setting/promptManage/*` | Prompt 模板 | ✅ | **`app_user_prompt` + REST**：**`GET /api/v1/prompts`**（恒为 **3** 条，**`id`** **1–3** 对齐旧 **`o_prompt.id`**；无行时 **`data`** 来自服务端默认文件 **`backend/data/prompt_defaults/*.txt`**，与 **`initDB`** 种子一致）；**`GET /api/v1/prompts/{numeric_id}`** 单条（合并规则同列表）；**`PATCH /api/v1/prompts/{numeric_id}`** 仅更新 **`data`**（**upsert**）；OpenAPI、无 DB 烟雾、**`prompts_list_patch_roundtrip`** PG 回归，以及 Flutter **`fetchPromptsV1`** / **`fetchPromptByNumericIdV1`** / **`patchPromptByNumericIdV1`** 与首页探针已对齐完成态 |
| `/api/setting/skillManagement/*` | Skills 列表/读写 | ✅ | Rust：**`GET /api/v1/skills*`** + **`PUT /api/v1/skills/content`**（覆盖已存在文件，对齐 **`saveSkillContent`**）+ **`POST /api/v1/skills/content`**（**新建**文件，父目录自动建；已存在 → **409**）+ **`DELETE /api/v1/skills/content`**（删单个文件 → **204**；不存在 → **404**；目录/非文件 → **400**）+ **`GET /api/v1/skills/binary?path=`**（**`data/skills` 下图片**原始字节 + **`Content-Type`**，供 **`visual-manual`** 的 **`image`** 相对路径替代旧 OSS URL；**png/jpeg/gif/webp/svg**，上限 **25MB**）；OpenAPI 与无 Bearer / 路径校验 / 创建覆盖 / 删除 / binary 烟雾已齐，Flutter **skills API**、**`fetchSkillsBinaryV1`** 与首页 probe 也已接上完成态 |
| `/api/setting/vendorConfig/*` | 供应商与密钥 | ✅ | 密钥不混入 **`vendor_config`**；**`GET …/settings/vendors/summary`** 返回 **`static_catalog_with_user_config`**（静态目录 + **`app_user_profile.vendor_config`**）；**`POST …/settings/vendors/model-test`** 校验 + 配额 → 入队 **`settings.vendor.model_test`**，worker 现执行真实探测：**text/image** 优先用 **`app_vendor_credential`** 解密后的用户凭证，缺失时回退服务端 **LLM** 环境；**video** 解析 **Runway/Pika/Kling** 并发起最小生成请求（优先用户凭证，回退 provider env）；结果写入 **`JobRow.result`**。**`pg_contract`** **`settings_vendor_model_test_enqueue`**、**`vendor_config_enable_update_roundtrip`**、**`vendor_credential_store_get_delete_roundtrip`** 已覆盖任务入队、元数据流和密钥元数据流；首页 models/settings probe 也已覆盖 add/update/enable/update-code/code-from-link/store/get/delete/get404，故该行按后端 parity 收口为完成 |
| `/api/task/getProject`、`getTaskApi`、`getTaskCategories`、`taskDetails` | 任务中心 | ✅ | **已删除** **`POST /api/v1/tasks/*`**。**HTTP**：**`GET /api/v1/projects`**（客户端筛非空名，返回中的 compat **`id`** 对应项目 numeric id，同时保留 `project_uuid` 供 UUID-first 恢复）；**`GET /api/v1/jobs/kinds`**（排除空 **`kind`**）；**`GET /api/v1/jobs/page`**（**`page`/`limit`/`task_class`/`state`/`project_id`**，其中 **`project_id`** 仍是 legacy numeric project filter，对齐 jobs payload 中保留双写的 **`project_numeric_id`**）；**`GET /api/v1/jobs/task-detail/{task_id}`**（UUID 或 legacy numeric task id 正整数路径）；另保留 **`GET /api/v1/jobs`**（**`limit`/`offset`**）与 **`kinds`/`status` summary**。Flutter **`postTasks*`** 为 compat 封装；**`pg_contract`** **`task_center_jobs_rest_roundtrip`** |
| `/api/test/test` | 测试路由 | ✅ | **`GET /api/v1/ping`** — JSON **`{"ok":true}`**（旧栈为纯文本 **`ok`**） |

补充产品化进展：

- Flutter 剧本分镜列表现在会把“新增/批量新增分镜”后的结果写回共享 follow-up 区，并自动补同步一次制作视图摘要；用户创建分镜后可直接看到“刷新制作视图 / 进入分镜出图工作台 / 补充分镜提示词”的下一步建议，不再只停留在一次性 SnackBar。
- Flutter 分镜出图工作台现已继续收口为共享诊断卡 + follow-up 形态：同步制作视图、全选可出图分镜、批量出图、读取预览/下载链接、导出 ZIP 都会回写统一的下一步建议，并根据所选分镜的提示词、production 覆盖率与现有画面状态自动推荐“同步制作视图 / 全选可出图分镜 / 批量发起出图 / 读取当前预览 / 导出所选 ZIP”，不再让工作台内部动作各自停留在原始状态文案。
- Flutter 单分镜图片/视频工作台现也改为共享诊断卡 + follow-up：production 同步、当前预览、轨道准备、默认视频提示词、视频数据刷新与视频生成提交都由同一诊断模型驱动，图片/轨道/视频动作完成后统一回写下一步建议，不再让单分镜编辑路径落回零散的状态字符串。
- Flutter 剧本分镜列表现在会在打开对话框时自动首刷一次制作视图摘要，减少进入后还要先手动点“刷新制作视图”的重复步骤。

### 3.1 Socket.IO（非 REST）

| 旧模块 | Rust / 说明 |
|--------|-------------|
| `src/socket/routes/scriptAgent.ts` | ✅ 已有 **`harness.*` WS**、`agent.script.attach`、`agent.run.cancel`、`agent.context.update` 协议替代；script 侧核心只读域工具（`get_novel_events`、`get_planData`（**`planId`** 与 REST `get-plan-data` 对齐，便于衔接 **`update-data`**）、`get_novel_text`、`get_script_content`）与编排工具（`run_sub_agent_storySkeleton`、`run_sub_agent_adaptationStrategy`、`run_sub_agent_script`、`run_supervision_agent`）已迁入 Harness；Flutter script workspace 已补上下文快照、阶段看板、`set-plan-data` 与 **`POST /api/v1/script-agent/update-data`** 双写回路径，主链路不再依赖旧 Socket.IO。 |
| `src/socket/routes/productionAgent.ts` | ✅ 已有 `agent.production.attach` / `agent.context.update` / `agent.run.cancel`；production 域工具 `get_flowData`、`add_deriveAsset`、`del_deriveAsset`、`generate_deriveAsset`、`generate_storyboard` 与编排工具（`run_sub_agent_derive_assets`、`run_sub_agent_generate_assets`、`run_sub_agent_director_plan`、`run_sub_agent_storyboard_gen`、`run_sub_agent_storyboard_panel`、`run_sub_agent_storyboard_table`）已迁入 Harness；Flutter production workspace 已补 flow / 子代理快照、阶段看板与安全回写闭环，主链路不再依赖旧 Socket.IO。 |

## 4. Rust 已暴露 HTTP 面（权威列表）

以 **合并后的 OpenAPI**（`GET /api/v1/openapi.yaml` 或 `cargo run --bin export-openapi`）为准（节选标签）：`system`、`session`、`settings`、`projects`、`general`、`art_styles`、`novels`、`assets`、`scripts`、`storyboards`、`production`、`skills`、`harness`、`jobs`、`tasks`、`usage`、`prompts`、`models`、`agents`、`webhooks`。
**WebSocket**：规范正文在合并 OpenAPI 的 **`paths` → `/api/v1/ws` → `get` → `description`**（源文为 `backend/src/openapi_spec/ws_protocol_description.md`，由 `harness::ws::upgrade::ws_upgrade` 的 `#[utoipa::path]` `include_str!` 注入）；`docs/websocket-events.md` 保留为仓库内稳定链接入口。
**可选 PG 回归**：**`backend/src/app/mod.rs`** 中 **`app::pg_contract_tests::projects_create_stats_delete_roundtrip`** 继续承接项目/资产/小说主链路，**`me_profile_subscription_and_jobs_today_roundtrip`** 锁定 **`GET /api/v1/me`** 的 `plan_tier` / 订阅字段 / `jobs_today` / `daily_job_quota`，**`promote_staging_populates_assets_and_links`** 承接 staging → PG 提升，**`production_workbench_video_roundtrip`** 与 **`production_assets_derivative_roundtrip`** 承接 production/workbench 真实行为回归。  
**无 DB 烟雾**：**`contract_smoke_tests`** 继续对系统/项目/素材/小说（**`GET`/`POST …/projects/{uuid}/novels*`**、**`novel-events*`**、**`generate-events`**；**已无** **`POST /api/v1/novels/*`**）/任务/技能/设置入口做 **401/400/503** 防线校验；其中 **`PUT /api/v1/settings/dev/switch-ai-tool`** 已验证 **`value`** 只能为 **`"0"`** / **`"1"`**，且合法请求会立即更新同进程内开关并返回 **200**。Production 路由不再按 **501 stub** 对待：**`POST …/production/get-production-data`**、**`get-flow-data`**、**`save-flow-data`**、**`workbench/generate-video`**、**`storyboard/polling-image`**、**`export-image`**、**`edit-image/upload-image`** 与 **`workbench/{add-track,delete-track,delete-video,generate-video-prompt,get-generate-data,get-video-list,get-video-model-detail,select-video}`** 在无 DB 时返回 **503**，请求体非法时返回 **400**，命中缺失资源时返回 **404**，其余返回 **200**。

## 5. 分波实施建议（把「完整后端」拆成可合并的 PR）

下列顺序可按团队并行度调整；每一波应带 **OpenAPI 增量 + 迁移（若需）+ `contract_smoke` 或 PG 测试**。

| 波次 | 目标 | 依赖 |
|------|------|------|
| **A（当前基线）** | 项目/剧本/分镜、jobs、usage、memory、models、skills **GET** + **PUT/POST/DELETE …/skills/content**、harness、billing webhook、me | 已有 |
| **B** | **Script**：export + poll + **extract-assets** ✅（**`20260406120000_app_asset.sql`**） | 任务化/可观测加固、prompt 与旧库逐字对齐可选 |
| **C** | **Novel + event** 全表与 REST ✅ | **`app_novel`**、**`app_novel_event`**、**`app_novel_event_chapter`** 与 **`…/projects/{project_id}/novels*`**、**`…/novel-events*`**（含 **`generate-events`**）已落地；**`/api/v1/novels/*` HTTP 已删除**。Flutter 探针主路径为 UUID REST，**`postLegacy*`** 仅为 Dart 兼容封装。独立 **`o_outline`** / **`o_outlineNovel`** 仍仅作迁移源，后续仅在产品需要时再决定是否单列 |
| **D** | **Assets + assetsGenerate**（**`app_asset_image`**、**`POST …/assets-generate/*`**、**`GET …/images/{id}/file`**、可选 **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`**）✅ | 队列 **`app_generation_job`**；**旧 Electron 页内轮询 UX** 仍产品侧 |
| **E** | **Production 完整实现** ✅：视频轨、批量出图、export 等 | jobs、对象存储、可能 CDN |
| **F** | **Setting 云端化** ✅：prompt、vendor（非密钥明文）、skill 写 | `saas-product-spec`、合规 |
| **G** | **静态资源策略** ✅：**skills** 与 **素材图** 外链 | **skills binary** / **素材 `…/file`** 已部分落地（§1）；**bulk OSS/CDN** 仍运维与产品 |
| **H** | **deleteAllData / clearData** ✅：受控运维 API 或仅 CLI（保持 501 符合 SaaS 设计） | 审计与权限 |

完成 **A–H** 中与产品 PRD **blocking** 的条目 + **`quality-bar`** 验收 + 灰度后，才可把 **`decommission-electron`** 标为完成。

## 6. 重构完成后的旧代码清理

与 **`harness-rust-flutter.md`** YAML **`decommission-electron`**、**§11.1.1** 一致：**parity 与灰度完成后**，应 **下线并删除或归档** 旧 Electron + Node 服务端实现，避免双栈长期共存、文档与 CI 分叉。

| 类别 | 建议动作 |
|------|----------|
| 旧 HTTP/WS | 移除 **`src/routes/**`**、**`src/socket/**`**、**`src/app.ts`**、**`src/router.ts`**、**`src/core.ts`** 等（以仓库为准） |
| 根 Node 元数据 | 收缩 **`package.json`** 中仅服务旧栈的 **dependencies / scripts** |
| CI | 去掉仅旧栈的 workflow；保留 **`refactor-monorepo`** / **`refactor-check`** 与新发布链路 |
| 迁移工具 | **`sqlite_import`**（`cargo run --bin toonflow-sqlite-import`）等可暂留；迁移期结束后再归档或迁出 |
| 安全网 | 大删前打 **git tag** 保留可检出旧栈的提交 |

**新栈唯一主路径**：**`backend/`**（Rust + Harness）+ **`frontend/`**（Flutter）。

## 7. 与本仓库其它文档的关系

- **`docs/plans/harness-rust-flutter.md`**：总路线图；**`rust-backend-mvp`** 是后端 **首条验收条**，不是完整 parity。
- **`product-shipping-bar`**：本文件为其 **parity 主表**；回归矩阵与灰度方案可另起 `docs/plans/` 短文或在 CI 中编码。
- **旧代码清理**：见上文 **§6** 与主计划 **§11.1.1**、**`decommission-electron`**。
