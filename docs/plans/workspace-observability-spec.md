# Workspace Observability Spec（W10.1 / W10.2）

**定位**：为团队 Workspace 补齐可执行的观测规格，覆盖：

- **W10.1**：`workspace_id` 在 HTTP / jobs / Harness 的 trace 与结构化日志贯通
- **W10.2**：workspace 级管理指标（成员数、项目数、活跃 jobs）口径

总表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W10。  
路线图：[`roadmap-workspace.md`](./roadmap-workspace.md)。  
现有相关真源：

- [`backend/README.md`](../../backend/README.md) — OTel / `X-Request-Id` / queue metrics
- [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md) — jobs 侧现有观测
- [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F — Harness / OTel 主路线
- [`workspace-security-boundary.md`](./workspace-security-boundary.md) — 为什么 workspace 作用域必须可观测

## 1) 当前现状

### 1.1 已有能力

- 所有 HTTP 响应带 `X-Request-Id`
- JSON 形 4xx/5xx 体会补 `request_id`
- jobs worker 已输出 `event = generation_job_phase`
  - 当前已有：`job_id`、`user_id`、`kind`、`phase`、`worker_id`、可选 `client_request_id`
- PG 队列深度日志已输出 `event = job_queue_metrics`
- Harness 已有部分结构化字段：
  - `harness.tool.invoke`
  - `harness.ws`
  - user wasm audit / signal 中的 `workspace_id`、`request_id`
- OTel / OTLP gRPC traces 已能导出，但 workspace 维度还没有统一字段约定

### 1.2 当前缺口

- `workspace_id` 没有在 **所有关键日志事件** 中统一出现
- jobs 侧更多是 `user_id + job_id` 视角，还缺按 workspace 聚合的标准字段
- Harness 普通工具调用与 session 关联没有统一的 workspace trace 规范
- 没有正式定义 workspace 级管理指标口径，导致“成员数/项目数/活跃 jobs”容易每个面板各算各的

## 2) W10.1：`workspace_id` 贯通规范

### 2.1 目标

只要一条请求、job 或 Harness 会话已经解析出 workspace 作用域，就应在日志 / span / 审计事件里带上 **统一字段名**：

- `workspace_id`

如无法确定 workspace，则字段可缺省或为空，但**不能**临时发明别名（例如 `workspaceUuid`、`workspaceId`、`ws_id`）混用在观测层。

### 2.2 字段命名约定

统一使用下列结构化字段名：

- `request_id`
- `trace_id`
- `workspace_id`
- `user_id`
- `project_id`
- `job_id`
- `worker_id`
- `tool_name`
- `channel`
- `phase`
- `outcome`

说明：

- HTTP / WS / jobs / Harness 日志层一律使用 snake_case
- API payload 中可以继续保留 `workspaceUuid` 等客户端字段名，但**观测层不跟随 payload 命名**

### 2.3 必须覆盖的事件

#### HTTP

以下类别的日志或 span 至少要带 `workspace_id`（若已解析到）：

- `GET /api/v1/me` 触发 current workspace fallback
- `PATCH /api/v1/me/current-workspace`
- workspace CRUD / membership / invites
- project 详情、overview、stats、workbench 等通过 `require_project_workspace_member_scope` 解析作用域的 handler
- 任何基于 `project_uuid` / `project_numeric_id` 进一步派生 workspace 的 jobs enqueue 路径

#### Jobs

以下事件需要补齐 `workspace_id`：

- `generation_job_phase`
  - `claimed`
  - `succeeded`
  - `failed`
  - `cancelled`
- 任何“根据 payload 解析项目 → 派生 workspace”成功的 worker 路径
- 与 job 关联的 artifact / notify / callback 失败日志，只要已知项目归属，也应带 `workspace_id`

#### Harness / WS

以下事件需要带 `workspace_id`：

- session attach 成功 / 失败
- `harness.tool.invoke`
- agent run 的一轮或阶段性事件
- script / production channel deny 或 scope mismatch
- user wasm 审计与失败信号以外的普通工具路径

### 2.4 推荐实现方式

优先复用已有作用域解析结果，不做重复查询：

1. **HTTP handler**
   - 在 membership / project scope helper 返回后，把 `workspace_id` 写入当前 span 或结构化日志
2. **jobs**
   - 在“由 payload 解析 project → workspace”那一步缓存 `workspace_id`
   - 后续 `observe::generation_job` 扩展为可选带 `workspace_id`
3. **Harness**
   - 以 `HarnessContext.workspace_id` 为主
   - attach 成功后会话内事件默认继承这个字段

### 2.5 明确不做

本阶段不要求：

- 为所有历史日志补回 workspace_id
- 把 workspace_id 硬塞进所有无 workspace 概念的事件
- 在日志里记录可识别 PII（email、prompt 正文、token 等）

## 3) W10.2：workspace 管理指标口径

### 3.1 指标目标

先定义 **管理视角** 指标，不直接承诺用户可见产品面：

1. `workspace_member_count`
2. `workspace_project_count`
3. `workspace_active_job_count`

后续若要做运营屏或告警，再在此口径上扩展。

### 3.2 指标定义

#### `workspace_member_count`

定义：

- `app_workspace_member` 中属于该 `workspace_id` 的当前成员行数

不区分：

- owner / admin / member

可选附加维度：

- `owner_count`
- `admin_count`
- `member_count`

#### `workspace_project_count`

定义：

- `app_project.workspace_id = <workspace_id>` 的项目总数

默认包含：

- 当前 active 项目

本阶段不额外区分：

- archived project（当前也无独立 project archive 语义）
- owner 个人 vs 团队创建者

#### `workspace_active_job_count`

定义：

- 与某 workspace 可见性相关、且当前处于活跃状态的 jobs 数量

口径：

- 仅统计能从 payload 解析出 `project_uuid` / `project_numeric_id`，并进一步派生出 `workspace_id` 的 jobs
- 状态至少包括：
  - `queued`
  - `running`

默认**不计入**：

- 没有关联 project 的 owner-only jobs
- `succeeded` / `failed` / `cancelled`

### 3.3 指标刷新方式

建议顺序：

1. 先做 **按需查询 / SQL 模板 / 只读内部接口**
2. 再决定是否做周期性聚合或 materialized snapshot

理由：

- 当前规模下，先把口径定死比先做缓存更重要
- workspace 计费 / quota（W8）还未定稿，过早物化容易重复返工

## 4) 观测字段与指标的对应关系

建议最少形成以下 join 路径：

- `request_id` -> HTTP 错误 / enqueue / WS attach
- `job_id` -> `generation_job_phase`
- `workspace_id` -> 同一 workspace 下的请求、jobs、Harness 工具链
- `trace_id` -> OTel collector 内的跨模块 span 关联

这样值班排障至少能回答三类问题：

1. 某个 workspace 最近是不是集中报 `403` / attach deny？
2. 某个 workspace 的 job 是否持续堆积？
3. 某个 workspace 的 Harness 工具调用是否比 HTTP 主链更容易失败？

## 5) 验收建议

### W10.1

- 抽查一条 workspace project 请求，确认日志 / span 可看到：
  - `request_id`
  - `workspace_id`
  - `user_id`
- 抽查一条带 project 上下文的 job，确认 `generation_job_phase` 可看到 `workspace_id`
- 抽查一条 Harness attach + tool invoke，确认事件链可按 `workspace_id` 过滤

### W10.2

- SQL / 内部接口对同一个 workspace 输出稳定一致的：
  - 成员数
  - 项目数
  - 活跃 jobs 数
- 对一个 personal workspace 和一个 enterprise workspace 各做一次抽样核对

## 6) 推荐实施顺序

1. **先做 W10.1**
   - 因为没有稳定 `workspace_id` 字段，后续指标和告警都不容易对齐
2. **再做 W10.2**
   - 口径依赖前一步的作用域统一
3. **最后再决定是否要用户可见运营屏**
   - 避免在没有稳定观测口径时过早做 UI

## 7) 当前不在本 spec 内的内容

- W8：workspace 级 plan / quota / billing 口径
- W9.2：Supabase 直连客户端与 Rust 授权一致性测试
- 具体告警阈值与通知通道
- 面向终端用户的管理控制台 UI

本 spec 的目标只是把 **workspace observability 的字段和口径先钉死**，让后续实现不再含糊。
