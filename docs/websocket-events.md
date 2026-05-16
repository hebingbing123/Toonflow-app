# WebSocket events (`/api/v1/ws`)

**Normative copy:** the full wire protocol (envelopes, `session.auth`, Harness events, naming mappings, errors) is the **`description`** of **`GET /api/v1/ws`** in the merged OpenAPI document. The prose is maintained as **`backend/src/openapi_spec/ws_protocol_description.md`** and included from **`#[utoipa::path]`** on `crate::harness::ws::upgrade::ws_upgrade`; served at **`GET /api/v1/openapi.yaml`** or **`cargo run --bin export-openapi`** from `backend/`.

**For humans:** use **Swagger UI** at `GET /api/v1/docs` and expand **GET /api/v1/ws**, or edit **`ws_protocol_description.md`** next to the handler’s OpenAPI macro.

This file stays in the repo so links from `AGENTS.md`, parity docs, and PR templates keep a stable path; when the protocol changes, update **`ws_protocol_description.md`** and refresh this pointer if needed.

**Attach / context（`agent.*.attach`、`agent.context.update`）**：除 **`openapi_spec/ws_protocol_description.md`** 中外，人类可读的 UUID-first 矩阵与可选 **`workspaceUuid`** 见 [`docs/plans/harness-ws-context-matrix.md`](plans/harness-ws-context-matrix.md)。当前主路径优先使用 **`projectUuid`** / **`scriptUuid`**；legacy numeric **`project_id`** / **`script_id`** 仅作兼容回退。成功 attach 后 **`session.ack`** 可含 **`payload.workspaceUuid`**（与 **`app_project.workspace_id`** 一致）。这些上下文字段服务于 attach / restore / tool scope，不单独决定 billing 口径。

**生成任务状态（`generation.job.updated`）**：任务状态变更通过 `GET/POST /api/v1/jobs*` 与 worker / cancel / retry 流转驱动，实时推送仍是 raw WebSocket envelope（`type` / `schema_version` / `payload`）；`payload` 为完整 job 对象。当前同一路径也覆盖素材生成相关任务，因为 asset generate / polish / batch / cancel 最终都通过 `app_generation_job` 广播这一事件。事件说明见 **`backend/src/openapi_spec/ws_protocol_description.md`**。

**应用内通知中心（`settings.notification.created` / `settings.notification.updated`）**：通知列表与已读状态通过 **`GET/POST /api/v1/settings/notifications*`** 管理，实时推送仍以 `GET /api/v1/ws` 的协议正文为准；当前 producer 已覆盖 **skills 变更**、**jobs 终态**、**workspace invite 生命周期**、以及 **content compliance alert / content compliance alert cleared** 两类合规通知。事件说明见 **`backend/src/openapi_spec/ws_protocol_description.md`**。

当前已落地的 notification producers / `notification_type` 包括：

| Producer | Trigger | `notification_type` |
|--------|---------|---------------------|
| `backend/src/prompting/skills/change_notify.rs` | 受影响项目命中的技能文件 / 技能包变更 | `skill_change` |
| `backend/src/jobs/notifications.rs` | generation job 进入终态 | `job_succeeded` / `job_failed` / `job_cancelled` |
| `backend/src/workspaces/http.rs` | 团队邀请创建 / 重发 / 撤销 / 接受 | `workspace_invite_created` / `workspace_invite_resent` / `workspace_invite_revoked` / `workspace_invite_accepted` |
| `backend/src/settings/notifications/content_compliance_sync_storage.rs` | 合规告警同步创建或更新开放告警 | `content_compliance_alert` |
| `backend/src/settings/notifications/content_compliance_sync_storage.rs` | 先前开放的告警阶段退出活跃队列且满足节流窗口 | `content_compliance_alert_cleared` |

**Harness 错误与聊天流（`error.occurred`、`chat.message.*`、`chat.content.*`）**：Harness / LLM 出站事件也统一走 raw WebSocket envelope（`type` / `schema_version` / `payload`）。其中 `error.occurred` 的 `payload` 至少包含 `code` / `message`，客户端若发送了 `request_id`，同一个值可能同时出现在 envelope root 与 `payload.request_id`；聊天流则按 `chat.message.created` → `chat.content.added` → `chat.content.updated`* → `chat.message.updated` 顺序发出。事件说明见 **`backend/src/openapi_spec/ws_protocol_description.md`**。

**Harness 会话与工具回执（`session.ready`、`session.ack`、`harness.tool.result`）**：这些控制面成功回执也统一走 raw WebSocket envelope。`session.ready` 是 `session.auth` 成功后的认证确认，`payload.sub` 为认证用户 UUID；`session.ack` 用于 attach / context update / cancel 等通用成功回执，当前 `payload` 可能包含 `ok`、`channel`、`workspaceUuid` 或 `stopped`；`harness.tool.result` 则返回 `payload.name` 与 JSON 形式的 `payload.result`。若客户端发送了 `request_id`，服务端会沿同一事件链回传它。事件说明见 **`backend/src/openapi_spec/ws_protocol_description.md`**。

**Harness agent loop（`harness.agent.started`、`harness.agent.tool_call`、`harness.agent.finished`、`harness.agent.cancelled`）**：`harness.agent.run` 触发的多轮工具循环会先推 `harness.agent.started`（当前 `payload.max_tool_rounds`），每次实际执行工具前推 `harness.agent.tool_call`（`call_id` / `name` / `arguments`），结束时推 `harness.agent.finished` 或 `harness.agent.cancelled`（两者都带 `tool_rounds_executed`，前者还带 `finish_reason`）。最终 assistant 文本本身不塞进这些 `harness.agent.*` 事件里，而是继续复用 `chat.message.*` / `chat.content.*` 序列。若客户端发送了 `request_id`，这些 envelope 也会沿线回传它。事件说明见 **`backend/src/openapi_spec/ws_protocol_description.md`**。

通知对象的 `linkPath`（`/product/*` 深链）见 [`docs/product-deep-links.md`](product-deep-links.md)。
