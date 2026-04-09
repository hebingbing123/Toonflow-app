# Master 详细对比与补漏计划

**目的**：把当前重构分支与 `master` 做一次更严格的逐项比对，不只看旧 REST 路由，也同时核对旧前端调用面、Socket.IO Agent、Agent tools、Flutter 当前 UI 形态，避免“接口存在但产品功能仍未真正迁完”的漏项。

## 1. 核对范围与方法

本次对比同时检查以下来源：

- `master:src/routes/**/*.ts`
- `master:src/socket/routes/*.ts`
- `master:src/agents/**/*`
- 当前分支 `backend/src/**/*`
- 当前分支 `frontend/lib/**/*`
- [`docs/openapi.yaml`](/Users/clive/Documents/source/cousor/Toonflow-app/docs/openapi.yaml)
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
- 旧 `migrate/migrateData` 已由 `toonflow-legacy-import` 与 staging 提升链路替代。
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

- 已把 Agent workspace 从单块探针控件升级为任务化双工作区卡片，明确 script / production 两条执行路径，降低对手工拼 WS payload 的依赖。
- 已补 script 领域工具一键探测入口（`get_planData`、`get_script_content`、`get_novel_text`、`get_novel_events`），可在工作区直接拉取上下文而不必依赖提示词触发。
- script 领域工具探测已支持 JSON 参数输入（如 `novelId`），并对 `get_script_content` 自动兜底附带当前 `script_id`，减少手工拼 payload 的错误率。
- 已加入常用提示词模板与子 Agent 工具快捷选择，能够更稳定复用旧 `run_sub_agent_*` / `run_supervision_agent` 编排入口。
- 已增加最近 WS 事件摘要，便于在同一工作区内追踪执行返回。
- 已增加 production 领域工具直调入口（`get_flowData`、`add_deriveAsset`、`del_deriveAsset`、`generate_deriveAsset`、`generate_storyboard`）并支持 JSON 参数探测，减少必须靠提示词间接触发工具的调试成本。
- 已增加 script 结果回写优先策略：workspace 优先使用 `get_script_content` 工具返回的结构化 `content` 作为写回源，并支持 `run_sub_agent_script` 结果文本直接作为写回候选；缺省回退到 `chat.content.updated` 聚合文本，并一键调用 `PATCH /api/v1/scripts/legacy/{id}` 写回，降低 Agent 产出到业务数据落库的错写风险与手工搬运成本。
- 已增加 production 侧 flow 回写：workspace 可基于最新 `get_flowData` 结果，先拉取完整 flow JSON，再按当前 key 合并并调用 `POST /api/v1/production/save-flow-data` 保存，避免只写单 key 时覆盖其他 flow 字段。
- 已扩展 production 工具结果回写面：除 `get_flowData` 外，其他工具结果也可写入自定义扩展 key（如 `workspaceResult`）；同时增加核心 key 保护，阻止非 `get_flowData` 结果覆盖 `assets/script/scriptPlan/storyboardTable/storyboard`。
- 已增强 production 核心 key 回写闭环：当 `add_deriveAsset`/`del_deriveAsset`/`generate_deriveAsset`/`generate_storyboard` 触发后，若用户选择对应核心 key 回写，workspace 会先刷新最新 flow key 数据再写回，避免把工具执行回执误写成核心 flow 结构；同时新增建议写回 key 提示与一键应用。
- 已扩展 production 子 Agent 回写闭环：当 `run_sub_agent_derive_assets`/`run_sub_agent_generate_assets`/`run_sub_agent_storyboard_gen`/`run_sub_agent_storyboard_panel`/`run_sub_agent_storyboard_table`/`run_sub_agent_director_plan` 触发后，若写回核心 key，workspace 同样先刷新最新 flow key 再保存，避免把子 Agent 文本结果误写成业务 flow 数据。
- 已增强 script 计划数据回写闭环：当 workspace 收到 `get_planData` 工具结果后，可直接一键调用 `POST /api/v1/script-agent/set-plan-data` 写回计划数据（`storySkeleton`/`adaptationStrategy`/`script`），不再仅限于脚本正文写回。

- script agent 页面：计划数据、章节材料、Agent 对话、执行结果回写
- production agent 页面：flowData、衍生资产、分镜、视频工作台、Agent 对话
- edit-image 上传流接入正式 UI（项目详情资产区新增“上传编辑图片”表单，选择剧本 + data URI 直传 `POST /api/v1/production/edit-image/upload-image`）
- 批量新增剧本接入正式 UI（项目详情剧本区新增“批量新增剧本”表单，直接调用 `POST /api/v1/scripts/batch-add` 并刷新列表/统计）
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

当前重构分支已经完成了**绝大多数旧 REST 能力迁移**，但如果目标是“不能遗漏任何功能点和模块”，那还不能宣布彻底完成。

当前剩余重点项是：

- Flutter 现在仍更像 probe/debug shell 的增强版，还不是旧 Electron 产品工作流的完整替代

因此，后续收尾应聚焦 **Harness 领域能力 + Flutter 产品工作流** 两条主线。
