# Harness WebSocket attach：上下文矩阵（H4）

与 REST **UUID-first** 语义对齐：**`projectUuid`** / **`scriptUuid`** 为主路径，legacy numeric 仅作兼容回退；会话仍以内 **`app_project.numeric_id`**、**`app_script.numeric_id`** 驱动 `HarnessContext` 与既有 SQL。

## `agent.script.attach`

| 字段（camelCase JSON） | REST / 产品含义 | 服务端写入会话 | DB 列 |
|------------------------|-----------------|----------------|-------|
| **`projectUuid`** | `GET /api/v1/projects` 行的 **`id`** | 解析为 **`project_numeric_id`**（并校验工作区成员） | `app_project.id` → `app_project.numeric_id` |
| **`workspaceUuid`**（可选） | 与 **`app_project.workspace_id`** 一致时需与解析结果匹配；用于客户端与 REST 工作区边界对齐 | 写入会话 **`workspace_id`**；**`session.ack`** 回显 | `app_project.workspace_id` |
| **`project_id`** | legacy numeric project id（Electron 兼容） | 直接作会话 project scope；**有 PG 时校验成员资格** | `app_project.numeric_id` |

至少提供其一；二者同发须指向同一项目（400 / WS `bad_request`）。

## `agent.production.attach` / `agent.context.update`

| 字段 | REST / 产品含义 | 服务端写入会话 | DB 列 |
|------|-----------------|----------------|-------|
| **`projectUuid`** | 同上 | 同上 | 同上 |
| **`workspaceUuid`** | 可选；须与解析得到的 **`app_project.workspace_id`** 一致 | 写入会话；**`session.ack`** 回显 | `app_project.workspace_id` |
| **`project_id`** | legacy numeric project id（同上） | 同上 | 同上 |
| **`scriptUuid`** | 剧本主键 **`app_script.id`** | 解析为 **`script_numeric_id`** | `app_script.id` → `app_script.numeric_id` |
| **`script_id`** | legacy numeric script id（**`app_script.numeric_id`**） | 校验位于当前 project 后写入会话 | `app_script.numeric_id` |

**`scriptUuid`** 需要已成功解析的 **`projectUuid`**（或等价 UUID 键）；仅有 legacy **`project_id`** 且无 PG 时无法仅凭 UUID 解析剧本（返回 `bad_request`）。

## 工具参数与 attach

制作域工具（如 **`get_flowData`**）使用 **`script_numeric_id_from_args_or_ctx`**：`arguments.scriptId` 与 WS attach 会话中的 script scope **二选一即可**。

## 参考实现

- 解析：`backend/src/harness/ws/attach_resolve.rs`、`backend/src/scope/mod.rs`（`resolve_owned_script_numeric_from_uuid_or_legacy_id`）、`backend/src/assets/crud/resolve/project_access.rs`
- Flutter 主路径：`frontend/lib/agent_workspaces/run_controller.dart`（双写 UUID + numeric）
