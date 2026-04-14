# Master 详细对比与补漏计划

**目的**：把当前重构分支与 `master` 做一次更严格的逐项比对，不只看旧 REST 路由，也同时核对旧前端调用面、Socket.IO Agent、Agent tools、Flutter 当前 UI 形态，避免“接口存在但产品功能仍未真正迁完”的漏项。

## 1. 核对范围与方法

本次对比同时检查以下来源：

- `master:src/routes/**/*.ts`
- `master:src/socket/routes/*.ts`
- `master:src/agents/**/*`
- 当前分支 `backend/src/**/*`
- 当前分支 `frontend/lib/**/*`
- 合并 OpenAPI：`GET /api/v1/openapi.yaml` 或 `backend/` 下 `cargo run --bin export-openapi`（源：`shell.rs` + 已提交 utoipa stubs / 域 `OpenApi`，**不含**后端 `openapi_paths_index.yaml`）
- [`docs/websocket-events.md`](/Users/clive/Documents/source/cousor/Toonflow-app/docs/websocket-events.md)
- [`docs/plans/electron-node-parity.md`](/Users/clive/Documents/source/cousor/Toonflow-app/docs/plans/electron-node-parity.md)

结论原则：

- **已迁移**：Rust/Flutter/Harness 已有等价或明确替代，且文档与调用面一致。
- **设计性替代**：不再逐路径复刻，但有明确替代方案，例如 Supabase Auth、CLI 迁移工具、桌面本地能力。
- **真实遗漏**：旧功能在当前 Rust/Flutter/Harness 中没有等价入口，或只有近似能力但没有稳定契约。
- **前端未收口**：后端和 API 已有，但 Flutter 仍停留在 probe/debug shell，没有形成旧产品级用户工作流。

## 2. 审计结果

### 2.1 已确认的设计性替代，不算遗漏

- 旧 `login/login` 已由 Supabase Auth 替代。
- 旧 `setting/loginConfig/*` 已并入 Supabase 账户体系。
- 旧 `migrate/migrateData` 已由 `toonflow-sqlite-import` 与 staging 提升链路替代。
- 旧 `setting/fileManagement/openFolder` 属于桌面本地能力，不应再按服务端 HTTP 复刻。

### 2.2 后端 HTTP 漏项收口（已完成）

以下两项旧 REST 漏点已在当前分支补齐，并同步到 OpenAPI / smoke / PG contract / Flutter `rust_api`：

1. `POST /api/v1/production/edit-image/upload-image`（旧 `POST /api/production/editImage/uploadImage`）
2. `POST /api/v1/scripts/batch-add`（旧 `POST /api/script/batchAddScript`）

收口说明：

- `upload-image`：增加 project/script ownership 校验，限制 JPEG/JPG/PNG base64 data URI，返回标准化 `url`。
- `batch-add`：增加 `projectId + data[{scriptName,scriptData}]` 批量写入契约，事务内顺序分配 `legacy_id`，并返回插入结果。

### 2.3 Harness / Socket.IO Agent 的真实遗漏

旧 Socket.IO 已有协议骨架替代，且 script / production 的核心域能力已迁入 Harness；当前剩余缺口集中在前端工作流收口。当前 Harness 工具目录只有：

- `echo`
- `isolated.echo`
- `skills.read`
- `wasm.probe`

对比 `master:src/agents/**/*`，以下旧域工具仍未进入 Harness 正式工具面：

1. script agent 旧读工具已迁入（本轮完成）

- `get_novel_events`
- `get_planData`
- `get_novel_text`
- `get_script_content`

2. production agent 旧工具已迁入（本轮完成）

- `get_flowData`
- `add_deriveAsset`
- `del_deriveAsset`
- `generate_deriveAsset`
- `generate_storyboard`

3. 旧子 Agent 编排已迁入（后端基线完成）

- script agent：`run_sub_agent_storySkeleton`、`run_sub_agent_adaptationStrategy`、`run_sub_agent_script`、`run_supervision_agent`
- production agent：`run_sub_agent_derive_assets`、`run_sub_agent_generate_assets`、`run_sub_agent_director_plan`、`run_sub_agent_storyboard_gen`、`run_sub_agent_storyboard_panel`、`run_sub_agent_storyboard_table`

4. 结论

- 当前 WS 文档已覆盖 `agent.script.attach`、`agent.production.attach`、`agent.context.update`、`agent.run.cancel`、`harness.agent.run`、`agent.chat.send` 这些协议动作。
- 当前 script + production 侧核心领域工具与子 Agent 编排工具已经在 Harness 落地，但**协议存在 + 工具存在 != 产品功能 parity 完成**。旧 Agent 仍依赖完整前端工作流。

### 2.4 Flutter 侧的真实遗漏（持续收口中）

当前 Flutter 已接入很多 Rust API，也做了不少 probe，但**整体仍偏向调试壳**，还不能视为旧 Electron 产品 UI 的完整替代。

证据：

- 主入口 [`frontend/lib/home_page.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/home_page.dart) 仍是单页 `HomePage` + 多个 `*_probe.dart` / `system_probes_*` / `skills_harness_*` 组合。
- 已新增 [`frontend/lib/home_page/agent_workspaces_section.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/home_page/agent_workspaces_section.dart) 与对应 controller，并在本轮升级为双工作区任务化卡片（script / production 分栏、任务提示词模板、`get_flowData` 快捷键、`run_sub_agent_*` 下拉触发、最近 WS 事件摘要）；但整体仍属“最小工作台”而非完整产品 IA。
- Agent workspaces 已补 `run_sub_agent_*` / `run_supervision_agent` 的工具直调入口（WS attach + `harness.tool.invoke`），可在 Flutter 侧直接触发 script/production 子 Agent 编排；但仍未形成完整业务信息架构与结果回写 UX。
- `script-agent` 在 Flutter 侧只有 API probe 与状态码探针，见 [`frontend/lib/rust_api/script_agent.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/rust_api/script_agent.dart) 与 [`frontend/lib/home_page/system_probes_models_catalog_settings_probe.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/home_page/system_probes_models_catalog_settings_probe.dart)。
- 目前没有发现与旧 `scriptAgent` / `productionAgent` 对应的完整终端用户聊天工作区、上下文工作区、执行过程 UI。

这意味着：

- **后端 API 已迁移** 不等于 **前端产品工作流已迁移**。
- 旧 Electron 的“剧本 Agent 工作流”和“视频策划 Agent 工作流”在 Flutter 侧仍应单列为待完成项。

## 3. 重构补漏计划

### Wave 1: 补齐明确漏掉的 HTTP 契约（已完成）

目标：先把“确实没实现”的旧 HTTP 能力补齐，避免 parity 表继续失真。

- 已增加 `POST /api/v1/production/edit-image/upload-image`
- 已补齐 OpenAPI、无 DB smoke、PG 回归、Flutter `rust_api`
- 已增加 `POST /api/v1/scripts/batch-add`
- 已明确与旧 `batchAddScript` 的字段映射、响应语义和 project ownership 校验

完成标准：

- OpenAPI 有路由
- `contract_smoke_tests` 有覆盖
- Flutter 有调用封装
- parity 文档可将这两项从“遗漏”改为“已完成”

### Wave 2: 补齐 Harness 的领域工具面（已完成）

目标：让 Harness 真正接住旧 script/production Agent 的业务职责，而不是只停留在通用 probe。

- 为 script channel 增加领域工具：
  - 读小说事件
  - 读计划数据
  - 读章节正文
  - 读剧本内容
- 为 production channel 增加领域工具：
  - 读 flowData
  - 新增/删除衍生资产
  - 触发衍生资产生成
  - 触发分镜生成
- 让工具目录、权限、WS、观测、测试一起落地

完成标准：

- `GET /api/v1/harness/tools` 中能看见这些领域工具
- `harness.tool.invoke` 可实际调用
- channel 权限和 project/script ownership 明确
- 文档与测试能说明旧 Agent 依赖的领域工具已迁入

### Wave 3: 补齐 Agent 编排与多角色执行（已完成后端基线）

目标：把旧 Agent 的“分角色执行”语义迁到 Harness，而不是只保留单轮 chat。

- script agent 的 `run_sub_agent_*` 系列已迁到 Harness orchestration
- production agent 的 `run_sub_agent_*` 系列已迁到 Harness orchestration
- 已明确 role label 与结果回传；memory namespace 与结果回写规则仍在 Flutter 工作流阶段继续收口
- 当前采用“提示词编排层优先”的最小可运行实现，后续可迭代为更强工具链

完成标准：

- 旧两个 Agent 的核心执行链路都能在新 WS 协议里跑通
- 不再依赖旧 Socket.IO 专属逻辑
- 领域工具和子 Agent 编排的边界清晰

### Wave 4: Flutter 从 probe shell 收口到产品工作流

目标：把当前 Flutter 从“接口探针台”推进到“用户可用的主界面”。

当前进度（本轮）：

- 首页已新增 `Workspace mode` 双模式切换（`Product workspace` / `Ops and debug`），把项目、任务、质量、Agent 工作区归入产品主链路，把 Harness/WS/system probes 收敛到运维调试模式，避免默认信息架构继续以 probe 为中心。
- `Product workspace` 已新增二级业务导航（Projects / Agent Workspace / Task Center / Jobs / Quality Reviews），改为单面板切换，不再把全部业务区块一次性堆叠在首页长滚动里。
- 已把 Agent workspace 从单块探针控件升级为任务化双工作区卡片，明确 script / production 两条执行路径，降低对手工拼 WS payload 的依赖。
- 已补 script 领域工具一键探测入口（`get_planData`、`get_script_content`、`get_novel_text`、`get_novel_events`），可在工作区直接拉取上下文而不必依赖提示词触发。
- script 领域工具探测已支持 JSON 参数输入（如 `novelId`），并对 `get_script_content` 自动兜底附带当前 `script_id`，减少手工拼 payload 的错误率。
- 已加入常用提示词模板与子 Agent 工具快捷选择，能够更稳定复用旧 `run_sub_agent_*` / `run_supervision_agent` 编排入口。
- 已增加最近 WS 事件摘要，便于在同一工作区内追踪执行返回。
- 已增加 production 领域工具直调入口（`get_flowData`、`add_deriveAsset`、`del_deriveAsset`、`generate_deriveAsset`、`generate_storyboard`）并支持 JSON 参数探测，减少必须靠提示词间接触发工具的调试成本。
- 已增加 script 结果回写优先策略：workspace 优先使用 `get_script_content` 工具返回的结构化 `content` 作为写回源，并支持 `run_sub_agent_script` 结果文本直接作为写回候选；缺省回退到 `chat.content.updated` 聚合文本，并一键调用 `PATCH /api/v1/projects/{project_id}/scripts/{script_legacy_id}` 写回，降低 Agent 产出到业务数据落库的错写风险与手工搬运成本。
- 已增加 production 侧 flow 回写：workspace 可基于最新 `get_flowData` 结果，先拉取完整 flow JSON，再按当前 key 合并并调用 `POST /api/v1/production/save-flow-data` 保存，避免只写单 key 时覆盖其他 flow 字段。
- 已扩展 production 工具结果回写面：除 `get_flowData` 外，其他工具结果也可写入自定义扩展 key（如 `workspaceResult`）；同时增加核心 key 保护，阻止非 `get_flowData` 结果覆盖 `assets/script/scriptPlan/storyboardTable/storyboard`。
- 已增强 production 核心 key 回写闭环：当 `add_deriveAsset`/`del_deriveAsset`/`generate_deriveAsset`/`generate_storyboard` 触发后，若用户选择对应核心 key 回写，workspace 会先刷新最新 flow key 数据再写回，避免把工具执行回执误写成核心 flow 结构；同时新增建议写回 key 提示与一键应用。
- 已扩展 production 子 Agent 回写闭环：当 `run_sub_agent_derive_assets`/`run_sub_agent_generate_assets`/`run_sub_agent_storyboard_gen`/`run_sub_agent_storyboard_panel`/`run_sub_agent_storyboard_table`/`run_sub_agent_director_plan` 触发后，若写回核心 key，workspace 同样先刷新最新 flow key 再保存，避免把子 Agent 文本结果误写成业务 flow 数据。
- 已把 production 领域工具结果继续收口为工作区内“上下文快照”：`get_flowData` 返回的 `assets` / `script` / `scriptPlan` / `storyboardTable` / `storyboard` 与子代理文本结果会在同一面板内预览，减少写回前只能盯日志摘要判断数据形态的误操作。
- 已把 production 工作区继续收口为“任务诊断 + 一键建议”形态：当前工具结果会生成 flow 摘要与下一步建议卡，按 `assets` / `scriptPlan` / `storyboardTable` / `storyboard` 的数据状态自动推荐读取 flow、切换子代理与填充提示词，并可直接在建议卡上一键读取 flow 或运行子代理，减少仍需人工判断“下一步该跑哪个工具/子代理”的控制台式负担。
- 已把 production 工作区的资产/分镜参数输入再向产品执行面推进：当用户先读取 `assets` / `storyboard` flow 后，工作区会直接从当前快照提取可执行候选，并为 `generate_deriveAsset` / `generate_storyboard` 提供 `ids` 一键填参，同时为 `add_deriveAsset` / `del_deriveAsset` 生成基于当前资产树的新增/删除参数模板，减少继续手写 JSON 的控制台式操作。
- 已把 production 工作区进一步收口为“阶段看板”执行流：当前结果会固定映射为 `scriptPlan → assets → storyboardTable → storyboard` 四个阶段卡片，按空白/待补图/建议刷新/已完成等状态展示当前所处环节，并可在卡片上一键读取对应 flow 或推进下一阶段子代理，减少只看单次工具结果时丢失整体制作节奏的负担。
- 已增强 script 计划数据回写闭环：当 workspace 收到 `get_planData` 工具结果后，可直接一键调用 `POST /api/v1/script-agent/set-plan-data` 写回计划数据（`storySkeleton`/`adaptationStrategy`/`script`），不再仅限于脚本正文写回。
- 已把 script 领域工具结果继续收口为工作区内“上下文快照”：`get_planData` 的故事骨架 / 改编策略 / script rows，以及 `get_script_content`、`get_novel_text`、`get_novel_events` 的核心内容都会在同一面板内可读预览，减少写回前必须来回查 probe 日志的审阅成本。
- 已把 script 工作区再推进到“任务诊断 + 章节填参”形态：`get_planData`、`get_novel_text`、`get_novel_events`、`get_script_content` 的结果现在会生成下一步建议卡，可一键切换到对应域工具或子代理；同时 `get_novel_text` / `get_novel_events` 返回的原始 `items` 结构已直接渲染为章节/事件快照，并为 `novelId` 参数提供章节复用芯片，减少继续手写 JSON 与猜测下一步动作。
- 已把 script 工作区进一步收口为“阶段看板”执行流：当前结果会固定映射为 `storySkeleton → adaptationStrategy → novel context → script content` 四个阶段卡片，按待生成/待读取/已就绪/已完成状态展示当前剧本链路，并可在卡片上一键读取对应上下文或推进下一阶段子代理，减少只看单次建议卡时缺少整体改编节奏的问题。
- 已把 Agent workspace 进一步收口为二级子导航（Script / Production / Activity），并把原超长 `agent_workspaces_section.dart` 拆分为职责化组件文件，减少单文件复杂度并把 WS 执行日志沉淀到独立活动面板，降低“同屏探针堆叠”负担。
- 已把 Product workspace 一级导航继续拆分为 `Script Workspace`、`Production Workspace`、`Workspace Activity` 三个独立工作区面板：首页保留统一入口，但每个工作区在产品导航中固定单页承载，不再依赖“进入 Agent Workspace 卡片后再二次切页”。
- 已在 Script/Production 工作区增加 Guided tasks 快捷动作（按步骤触发上下文拉取、子代理执行、结果写回），减少手动切换下拉与拼 JSON 参数，让主流程可以按产品任务序列推进。
- 已修正 Agent workspace 的 WS 忙闲状态：script/production 运行、领域工具探测、sub-agent 执行现在会持续 busy 到收到完成/失败事件为止，不再在发出消息后立刻解除，避免重复点击造成并发 attach/run 与日志串扰。
- 项目详情剧本区已提供“批量新增剧本”正式表单，直接调用 `POST /api/v1/scripts/batch-add` 并刷新列表/统计。
- 项目详情剧本区现已补齐项目级批量任务入口：可直接导出全部剧本 ZIP、轮询全部剧本提取状态，并对当前项目下全部剧本发起素材抽取，不再需要进入兼容性 probe 或逐条打开剧本编辑器。
- 项目详情剧本区已新增“剧本批量工作台”：可按名称读取 `get-script-api` 上下文、显式编辑目标剧本 id 集合，并在同一对话框内完成批量导出、提取状态轮询、素材抽取与批量创建，把原先分散的全量按钮和 `get-script-api` probe 收口为正式项目级工作流。
- 剧本批量工作台现也已补“批量状态诊断 + 推荐动作”卡片：会根据当前选中的剧本 id、已读取的上下文与提取状态，自动区分“未选择 / 提取中 / 提取失败 / 已有素材 / 仍待抽取”，并直接给出读取上下文、轮询状态、重试抽取或导出 ZIP 的推荐批量动作，减少多剧本场景下手工解释状态串的成本。
- 项目详情剧本摘要区现已复用同一套批量诊断逻辑与 follow-up 文案：全量导出 / 轮询 / 抽取快捷动作会先同步本地提取状态，再写回“动作结果 + 下一步建议”；当摘要区还缺少 `get-script-api` 上下文时，会优先引导打开正式工作台读取快照，而不是在未知素材关联状态下直接建议批量抽取。
- 项目详情章节工作台已新增 legacy 快照与批量动作区：可直接读取 `get-novel-data` / `get-novel-index` / `get-novel-event-state`，并在同一入口执行 legacy `batch-delete`，把高频 novels 包装接口从兼容性折叠区收口进正式章节工作流。
- 项目详情“小说与事件”区已进一步去 probe 化：主视图现在只保留章节/事件正式工作台摘要卡与刷新入口，旧 REST 首条/末条探针已退出主链路，仅在兼容性折叠区保留 legacy 回归检查。
- 首页“质量评审”区已完成 probe 收口：主区现在以“质量工作台”承载评审筛选、坏例查看、统计/阶段通过率读取、详情查询与手动创建，旧 probe 创建入口仅保留在兼容性折叠区。
- 首页“任务中心”区已完成首轮 probe 收口：主区现在以“任务工作台”承载任务项目/分类读取、按项目/分类/状态筛选列表，以及按 legacy id 或 UUID 查看详情，旧加载按钮与首条/UUID probe 下沉到兼容性折叠区。
- Projects 页已新增“记忆工作台”：可按项目 legacy id、agent type 与可选 episodes id 查询、追加、清理 Agent 记忆，不再只保留“首项目 scriptAgent query+append”探针。
- Projects 页已新增“创作手册工作台”：导演手册与视觉手册现在可在同一对话框内完成刷新、查看、创建、更新、删除，并交叉校验 `GET/POST /api/v1/visual-manual` 结果一致性，不再只靠首页 probe。
- 项目详情资产区已提供“上传编辑图片”正式表单，直接调用 `POST /api/v1/production/edit-image/upload-image`。
- 项目详情资产区已补齐显式资产工作流表单：可直接选择目标资产执行新建/编辑/删除，并可选择剧本与资产执行关联/取消关联；原先“首条/末条”隐式 probe 动作已收敛到兼容性折叠区。
- 项目详情资产区已补齐高级筛选表单：可按剧本、资产类型、名称关键字与分页参数筛选并直接刷新资产结果，不再依赖兼容性查询按钮触发。
- 项目详情资产区现已进一步收口为“资产主工作台”入口：主视图只保留摘要与统一入口，资产 CRUD、剧本关联、筛选、编辑图上传与 Clip 上传被合并进单一工作台，减少项目详情主链路里的控制台式散按钮。
- 资产主工作台现已继续吸收“资产图片工作台”“资产出图工作台”“资产历史图工作台”的跳转入口，项目资产主区不再保留这些二级工作台的平铺按钮，进一步收紧为单入口信息架构。
- 资产主工作台跳转到图片/出图/历史图子工作台时，现会沿用当前焦点资产作为默认上下文，减少进入子流程后再次手动定位目标资产的重复操作。
- 资产图片工作台现会在打开时自动加载当前焦点资产的图片列表，切换目标资产时也会立即刷新列表，进一步减少“选完资产还要再点一次加载”的探针式操作。
- 资产图片工作台现会在自动加载列表后继续自动拉取当前图片预览，切换图片时也会立即刷新预览，不再要求额外手动点击一次“预览当前图片”。
- 资产图片工作台回刷列表后现会优先保留当前图片焦点，其次识别已选/封面图片，并把状态文案升级为封面与当前图片摘要，减少连续编辑时每次都被跳回首图。
- 资产图片工作台现已在编辑或删除当前图片后同步回刷父级资产摘要，与新增图片时保持一致，避免同一轮会话里资产主工作台继续显示过期的图片/封面状态。
- 资产历史图工作台现也会在打开时自动查询当前类型过滤下的历史图资产，并优先定位当前焦点资产，减少进入后仍需手动点一次“查询历史图资产”的重复操作。
- 资产历史图工作台现会在提交或清空类型过滤时直接自动重查，并提供常用类型快捷筛选；切换资产或历史图时，摘要与预览也会继续自动联动，进一步去掉 corner-scape 子流程里的控制台式重复点击。
- 资产出图工作台现会在打开时自动同步一次 production 资产摘要，默认先给出当前可见资产的 production 上下文，而不需要先手动点击“同步 production 摘要”。
- 资产出图工作台在切换资产类型过滤时，现也会立即重算当前可见资产选择并自动同步 production 摘要，减少筛选后还要再次手动点击“同步 production 摘要”的重复动作。
- 资产出图工作台现已进一步把 production 摘要、图片轮询与 prompt 轮询联动为单次“同步当前工作台摘要”动作；批量发起出图、清理衍生图、更新封面 URL 后也会自动回刷这组三联状态，减少操作后还要连续手动点摘要/图片/prompt 查询的控制台式步骤。
- 资产出图工作台在切换类型过滤、同步摘要和资产列表回刷后，现会优先保留仍然可见的已选资产；如果原选择已失效，则回退到当前焦点资产或新的首条可见资产，并把状态摘要升级为带资产名的选择说明，减少连续出图时反复重新定位目标资产。
- 资产出图工作台现已把“批量候选”“图片轮询状态”“prompt 轮询状态”“素材上下文”进一步转成可点击的重建选择动作，读取结果后可以直接按候选/状态重组选中资产，而不必再回到长列表逐条手动勾选。
- 项目详情资产区已新增“资产历史图工作台”：可按类型过滤查询 `corner-scape` 资产、浏览历史图列表并直接预览首图，把原先兼容性 `POST corner-scape` 查询从 probe 按钮收口为正式产品交互。
- 项目详情资产区已新增“上传 Clip 资产”正式表单：可直接调用 `POST /api/v1/projects/{project_id}/assets/workbench/upload-clip`（**`project_id`** 为项目 UUID）并回刷资产列表，把原先兼容性 `POST upload-clip` 从 probe 按钮收口到主工作流。
- 项目详情资产区已新增“资产图片工作台”：可按目标资产加载图片列表，并在同一对话框内完成 `GET/POST/PATCH/DELETE …/assets/{aid}/images*` 与文件预览，替代原先分散的兼容性单按钮操作。
- 资产图片工作台现也继续收口为共享诊断卡 + follow-up：会根据当前资产是否已同步图片列表、是否已有图片、是否已读取当前预览来自动推荐“读取图片列表 / 新增当前图片 / 读取当前预览 / 保存当前图片”，并把列表同步、预览、增删改结果统一写回下一步建议，减少资产图片流里仍需人工判断下一步的控制台式负担。
- 项目详情资产区已新增“资产出图工作台”：可在项目资产主视图内按当前可见资产选择目标、同步 `production/assets/get-assets-data` 摘要、读取 legacy `get-material-data` / `batch-generation-data` / `polling-prompt-assets` 上下文、批量触发 `batch-generate-assets-image`、轮询图片状态、清理衍生图并更新单资产封面 URL，把 production + legacy 资产生成链路从 system probe/兼容性按钮收口回正式产品流。
- Projects 页已新增“画风工作台”：可在同一对话框内刷新画风列表、查看 JWT 保护的本地封面、执行 `GET/POST/PATCH/DELETE …/art-styles*`，并直接调用 `POST /api/v1/art-styles/extract-prompt` 把多图输入转成可保存 prompt，替代首页原先仅有的列表加载与 CRUD 探针摘要。
- 剧本编辑器已升级为脚本工作台入口：除基础字段编辑外，现可直接读取 `get-script-api` 当前脚本上下文、查看关联素材摘要、导出当前剧本 ZIP、轮询提取状态并发起当前剧本素材抽取，开始把“脚本导出与抽取流程”从 probe 操作收口到正式产品交互。
- 剧本工作台现已把脚本上下文与提取状态收口为统一“同步工作台”动作：打开时自动同步、发起素材抽取后自动回刷，且从编辑图片子工作台返回后也会立即刷新当前脚本上下文与提取状态，避免脚本编辑器保留过期状态。
- 剧本工作台现已补“状态诊断 + 推荐动作”卡片：会根据 `get-script-api` 上下文、轮询到的 `extract_state` 和关联素材数量，自动区分“未同步 / 提取中 / 提取失败 / 待抽取 / 已有素材”并给出直接下一步按钮，减少用户看到纯状态码后仍要手动判断是先轮询、重试抽取还是进入编辑图片工作台。
- 剧本工作台已新增“编辑图片工作台”入口：可直接加载 edit-image flow 模板与默认模型、上传源图、保存或更新 flow 步骤状态，并发起 `generate-flow-image`，开始把编辑图片链路从 production probe 收口进脚本主流程。
- 剧本编辑图片工作台现会在打开时自动同步 Flow 模板与默认模型，后续手动同步时也会尽量保留当前步骤焦点，减少进入后还要先点一次“加载 flow 模板”以及重载后重新定位步骤的重复操作。
- 剧本分镜编辑器已升级为制作工作台入口：除基础字段编辑外，现可直接读取/保存 storyboard 预览图、清空当前画面、管理 video track、生成默认视频提示词、提交 `workbench/generate-video`、查看当前 storyboard 关联视频候选并一键选中/删除，开始把“分镜与视频流程”从 probe 操作收口到正式产品交互。
- 剧本分镜列表已新增“分镜出图工作台”：可在剧本上下文内批量勾选分镜、沿用现有提示词发起 `batch-generate-image`、读取当前预览图与下载链接，并直接导出所选分镜 ZIP，继续把 production storyboard 图片链路从 probe 收口为正式工作流。
- 剧本分镜列表现已把“新增/批量新增分镜”后的状态升级为共享 follow-up 区，并在创建后自动回刷一次制作视图摘要；这样用户不必在成功提示条消失后自行判断下一步，而是可直接根据诊断继续刷新制作视图、补提示词或进入分镜出图工作台。
- 剧本分镜列表现在也会在打开时自动首刷制作视图摘要，进一步去掉进入分镜区后必须手动触发一次 production 同步的控制台式步骤。
- 分镜出图工作台现也会根据所选分镜的提示词、production 快照覆盖率与现有画面状态生成共享诊断卡，并把同步制作视图、批量出图、读取预览/下载链接、导出 ZIP 的结果统一写成 follow-up 建议，进一步把工作台内部动作从原始状态回执收口为连续执行流。
- 单分镜图片/视频工作台现也补了共享诊断卡与 follow-up：会根据当前分镜的 production 快照、可用画面、轨道准备情况、视频参数、已有候选视频与进行中任务，自动推荐“同步当前分镜数据 / 读取当前预览 / 准备视频轨道 / 生成默认视频提示词 / 刷新视频数据 / 提交视频生成”，并把图片保存、清空画面、轨道变更、默认提示词生成、视频提交与视频切换/删除的结果统一写回下一步建议，继续减少单分镜流程里的原始状态字符串。
- 分镜工作台相关 UI 已继续拆为独立职责文件，避免 `storyboard_editor.dart` 再次膨胀成超长单文件，后续补产品流程时可以在不压坏主编辑器的前提下继续迭代。

- script agent 页面：计划数据、章节材料、Agent 对话、执行结果回写
- production agent 页面：flowData、衍生资产、分镜、视频工作台、Agent 对话
- 把 `home_page` 下大量 probe 逐步转为回归入口或开发工具，而不是主产品入口

完成标准：

- 用户不需要进 probe 页也能完成旧核心工作流
- Flutter 信息架构可以替代旧 Electron 主要导航
- probe 保留为 debug/QA 工具，不再承担主产品职责

### Wave 5: 文档与门禁最终收口

目标：让“已完成”描述重新可信，避免以后再漏。

- 更新 [`docs/plans/electron-node-parity.md`](/Users/clive/Documents/source/cousor/Toonflow-app/docs/plans/electron-node-parity.md)
- 更新 [`docs/plans/harness-rust-flutter.md`](/Users/clive/Documents/source/cousor/Toonflow-app/docs/plans/harness-rust-flutter.md)
- 为新增契约补 smoke / pg / frontend 验证
- 对 script agent / production agent 做端到端验收清单

完成标准：

- parity 表里不再存在“文档写完成，但代码其实还缺”的状态
- `product-shipping-bar` 可以以这份审计为准收口

## 4. 本次审计后的结论

当前重构分支已经完成了**旧 REST 能力迁移**与 **Socket.IO 域能力的 Harness 承接**（见 [`electron-node-parity.md`](./electron-node-parity.md) §3.1、§3 `scriptAgent` 行）：后端契约 + WS 工具面 + Flutter「产品工作区」主链路已可替代旧 Electron 核心工作流；**运维探针**保留在 **Ops and debug** 模式用于回归与排障。

后续迭代主要是**产品体验与 IA 深化**（而非“缺接口”）：更细的导航/空态/引导、观测与性能、以及按需扩展的新功能规格。

因此，**功能重构主线的验收**应以 **parity 表 + OpenAPI/WS 文档 + `yarn refactor:check` 门禁**为准；持续交付仍可同时推进体验与运营需求。
