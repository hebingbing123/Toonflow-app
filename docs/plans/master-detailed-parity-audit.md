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

旧 Socket.IO 已有协议骨架替代，但**域能力没有迁完**。当前 Harness 工具目录只有：

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

3. 旧子 Agent 编排未迁入（script + production）

- script agent：`run_sub_agent_storySkeleton`、`run_sub_agent_adaptationStrategy`、`run_sub_agent_script`、`run_supervision_agent`
- production agent：`run_sub_agent_derive_assets`、`run_sub_agent_generate_assets`、`run_sub_agent_director_plan`、`run_sub_agent_storyboard_gen`、`run_sub_agent_storyboard_panel`、`run_sub_agent_storyboard_table`

4. 结论

- 当前 WS 文档已覆盖 `agent.script.attach`、`agent.production.attach`、`agent.context.update`、`agent.run.cancel`、`harness.agent.run`、`agent.chat.send` 这些协议动作。
- 当前 script + production 侧核心领域工具已经在 Harness 落地，但**协议存在 + 工具存在 != 产品功能 parity 完成**。旧 Agent 仍依赖“子 Agent 分工执行 + 前端工作流”。

### 2.4 Flutter 侧的真实遗漏

当前 Flutter 已接入很多 Rust API，也做了不少 probe，但**整体仍偏向调试壳**，还不能视为旧 Electron 产品 UI 的完整替代。

证据：

- 主入口 [`frontend/lib/home_page.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/home_page.dart) 仍是单页 `HomePage` + 多个 `*_probe.dart` / `system_probes_*` / `skills_harness_*` 组合。
- 已新增 [`frontend/lib/home_page/agent_workspaces_section.dart`](/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib/home_page/agent_workspaces_section.dart) 与对应 controller，把 script/production attach + `harness.agent.run` + `get_flowData` probe 收口到独立工作区入口，但仍属“最小工作台”而非完整产品 IA。
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

### Wave 3: 补齐 Agent 编排与多角色执行

目标：把旧 Agent 的“分角色执行”语义迁到 Harness，而不是只保留单轮 chat。

- script agent 的 `run_sub_agent_*` 系列迁到 Harness orchestration
- production agent 的 `run_sub_agent_*` 系列迁到 Harness orchestration
- 明确 memory namespace、role label、cancel 行为、结果回写规则
- 决定哪些子 Agent 用工具链实现，哪些保留成提示词编排层

完成标准：

- 旧两个 Agent 的核心执行链路都能在新 WS 协议里跑通
- 不再依赖旧 Socket.IO 专属逻辑
- 领域工具和子 Agent 编排的边界清晰

### Wave 4: Flutter 从 probe shell 收口到产品工作流

目标：把当前 Flutter 从“接口探针台”推进到“用户可用的主界面”。

- script agent 页面：计划数据、章节材料、Agent 对话、执行结果回写
- production agent 页面：flowData、衍生资产、分镜、视频工作台、Agent 对话
- edit-image 上传流接入正式 UI
- 批量新增剧本接入正式 UI
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

- Harness 还没有承接旧 script/production Agent 的领域工具和子 Agent 编排
- Flutter 现在更像 probe/debug shell，还不是旧 Electron 产品工作流的完整替代

因此，后续收尾应聚焦 **Harness 领域能力 + Flutter 产品工作流** 两条主线。
