# WebSocket events (`/api/v1/ws`)

Single WebSocket entry (same version prefix as REST). Clients derive the URL from HTTP `baseUrl`, e.g. `ws://127.0.0.1:8666/api/v1/ws` or `wss://…/api/v1/ws` behind TLS.

## Wire envelope (target v1)

All frames are **UTF-8 JSON** with:

| Field | Type | Required | Notes |
|--------|------|----------|--------|
| `type` | string | yes | `domain.action` (lowercase), e.g. `agent.chat.send` |
| `schema_version` | integer | yes | Start at `1`; bump when payload is incompatible |
| `payload` | object | yes | Event-specific body |
| `request_id` | string (uuid) | no | Correlate with logs / tracing |

Unknown `type` or unsupported `schema_version` → close with policy-defined code or return `error.occurred` (see below).

## Authentication

- **v1 (no BFF)**: Same JWT as REST — Supabase access token.
- Browsers cannot set arbitrary headers on `WebSocket`; use **query** `access_token=<jwt>` or **first message** `session.auth` (see below) — pick one per client and document in Flutter config.

### `session.auth` (client → server)

| Field | Type | Required |
|-------|------|----------|
| `type` | const `session.auth` | yes |
| `schema_version` | `1` | yes |
| `payload.access_token` | string | yes |

Server responds with `session.ready` or `error.occurred` before other traffic.

### `session.ready` (server → client)

| Field | Notes |
|-------|--------|
| `payload.sub` | Authenticated user id (UUID string, matches JWT `sub`) |

### `harness.tool.invoke` (client → server)

Requires an authenticated session (`?access_token=` or successful `session.auth`). Does **not** require `agent.*.attach`.

| Field | Type | Required |
|-------|------|----------|
| `type` | const `harness.tool.invoke` | yes |
| `schema_version` | `1` | yes |
| `payload.name` | string | yes (tool id from `GET /api/v1/harness/tools`) |
| `payload.arguments` | object | no (defaults to `{}`) |
| `payload.arguments.path` | string | required for **`skills.read`** — relative path under `data/skills` (same as REST `GET /api/v1/skills/content?path=`) |

#### Production `add_deriveAsset`

- **`arguments.assetsId`**: parent asset **`app_asset.numeric_id`**. That parent row must be linked to the active script (**`app_script_asset`**) for **`arguments.scriptId`** or the script from **`agent.production.attach`** / **`agent.context.update`**.
- **`arguments.id`** (optional): when updating an existing derived asset, that row must already be linked to the same script (**`UPDATE … FROM app_script_asset`** on the server).

### `harness.tool.result` (server → client)

Emitted when invocation succeeds.

| Field | Notes |
|-------|--------|
| `payload.name` | Tool that ran |
| `payload.result` | JSON value returned by the tool (`echo`: mirrors `arguments`; `isolated.echo`: same as `echo` but runs in a child process; `skills.read`: `{ path, content }`; script tools: `get_planData` (includes optional numeric `planId` when an `app_script_agent_plan` row exists, aligned with REST `get-plan-data`), `get_script_content` (supports `scriptId` plus optional `relativeOffset` for previous/next episode windows), `get_novel_text`, `get_novel_events` (both default to compact reads when args are omitted: `get_novel_text` returns one chapter window with trimmed fields; `get_novel_events` returns up to eight trimmed event rows), `run_sub_agent_storySkeleton`, `run_sub_agent_adaptationStrategy`, `run_sub_agent_script`, `run_supervision_agent` (sub-agent tools return `{ tool, agent_role, result, review? }`; supervision tools may include parsed `reviewSummary` attrs under `review`); production tools: `get_flowData` (compact by default when filters are omitted: `script`/`scriptPlan` return trimmed text windows, `storyboardTable` returns the first 8 key rows, `assets`/`storyboard` return trimmed field subsets plus bounded row counts), `add_deriveAsset` (parent `arguments.assetsId` must be linked to the active script in `app_script_asset`; see **Production `add_deriveAsset`** below), `del_deriveAsset`, `generate_deriveAsset`, `generate_storyboard`, `run_sub_agent_derive_assets`, `run_sub_agent_generate_assets`, `run_sub_agent_director_plan`, `run_sub_agent_storyboard_gen`, `run_sub_agent_storyboard_panel`, `run_sub_agent_storyboard_table`, `run_sub_agent_production_supervision`; `wasm.probe`: `{ ok, value }`) |

### `harness.agent.run` (client → server)

Multi-round **OpenAI tool calling** loop: the model may invoke Harness catalog tools; the server runs them (same rules as `harness.tool.invoke`) and feeds results back until the model returns a final assistant message.

Requires **`OPENAI_API_KEY` / `LLM_API_KEY`** (same as `agent.chat.send`). Requires an authenticated session and **an attached channel** (`agent.script.attach` or `agent.production.attach`) before use.

| Field | Type | Required |
|-------|------|----------|
| `type` | const `harness.agent.run` | yes |
| `schema_version` | `1` | yes |
| `payload.content` | string | yes (user goal / instruction) |
| `payload.max_tool_rounds` | integer | no (default **8**, clamped **1–32**; each “round” is one chat completion that may issue tool calls) |

Shares **`agent.run.cancel`** with streaming chat: cancel aborts an in-flight `harness.agent.run`.

### `harness.agent.started` (server → client)

| Field | Notes |
|-------|-------|
| `payload.max_tool_rounds` | Configured cap |

### `harness.agent.tool_call` (server → client)

Emitted before each tool execution during the loop.

| Field | Notes |
|-------|-------|
| `payload.call_id` | OpenAI `tool_call` id |
| `payload.name` | Tool name |
| `payload.arguments` | Parsed JSON arguments (or a fallback object if JSON parse fails) |

### `harness.agent.finished` (server → client)

After the model returns a final text response (no tool calls in that completion).

| Field | Notes |
|-------|-------|
| `payload.tool_rounds_executed` | Completions that executed at least one tool call |
| `payload.finish_reason` | e.g. `stop` |

### `harness.agent.cancelled` (server → client)

Emitted when the run stops due to **`agent.run.cancel`** (cancel token).

The final assistant text uses the same **`chat.message.*` / `chat.content.*`** sequence as a non-streaming single block (one `chat.content.updated` with full text).

### `generation.job.updated` (server → client)

Pushed when a row in `app_generation_job` owned by the caller transitions (for example `queued` → `running` → `succeeded` / `failed`, `queued` → `cancelled`, or `failed` → `queued` via retry). **`payload`** is the full job object (snake_case: `id`, `owner_user_id`, `kind`, `status`, `payload`, `result`, `error_message`, `idempotency_key`, `created_at`, `updated_at`).

The server registers the connection for push after auth (`?access_token=` or `session.auth`).

Cancelling a **`running`** job via REST sets `cancelled` immediately; the in-process worker will not apply `succeeded` / `failed` if the row is no longer `running`.

### `session.ack` (server → client)

Generic success for attach / context update / cancel; carries `request_id` when the client sent one.

### `agent.chat.send` → LLM stream (server → client)

When `OPENAI_API_KEY` or `LLM_API_KEY` is configured, the server streams an OpenAI-compatible **`/v1/chat/completions`** response and emits (in order):

1. **`chat.message.created`** — assistant shell (`status`: `streaming`, `name`: `统筹` or `视频策划` by channel).
2. **`chat.content.added`** — first `text` block (`messageId`, `content.id`).
3. **`chat.content.updated`** — repeated; `payload.append` carries each token/chunk (client concatenates for full text).
4. **`chat.message.updated`** — `status`: `complete` or `stop` (cancel / disconnect).

If the API key is missing, respond with **`error.occurred`** (`code`: `llm_not_configured`). Upstream failures use `code`: `llm_error`.

## Channels vs previous Socket.IO namespaces

Previous Node stack used Socket.IO namespaces:

| Previous namespace | Purpose |
|------------------|---------|
| `/api/socket/scriptAgent` | 剧本 / 统筹 Agent |
| `/api/socket/productionAgent` | 视频策划 Agent |

**Target mapping**: `payload.channel` on the first post-auth message, or dedicated connect types:

| `type` | Meaning |
|--------|---------|
| `agent.script.attach` | Former `scriptAgent` namespace |
| `agent.production.attach` | Former `productionAgent` namespace |

`payload` should carry `isolation_key` plus **project scope** and (for production / `agent.context.update`) **script scope**:

| Wire field | Meaning |
|------------|---------|
| **`projectUuid`** (preferred) | `app_project.id` (UUID string) |
| **`project_id`** (legacy) | `app_project.numeric_id` (positive integer) |
| **`scriptUuid`** (preferred) | `app_script.id` |
| **`script_id`** (legacy) | `app_script.numeric_id` |

Send **`projectUuid`** and/or **`project_id`** (same pairing rules as REST agent-memory: if both are sent they must refer to the same row). When Postgres is configured, legacy **`project_id` only** is verified against ownership; **`projectUuid`** resolution requires a database pool (attach fails with `bad_request` if the pool is absent). **`scriptUuid`** similarly requires DB + a resolved project UUID key server-side.

## Client → server (previous names → target `type`)

| Previous Socket.IO event | Target `type` | Notes |
|------------------------|---------------|--------|
| (Harness) | `harness.tool.invoke` | `payload.name`, optional `payload.arguments` — `echo` returns arguments; `isolated.echo` same JSON semantics as `echo` via process isolation; `skills.read` requires `arguments.path` (relative to `data/skills`) and returns `{ path, content }`; script tools: `get_planData`, `get_script_content` (`arguments.scriptId` plus optional `arguments.relativeOffset`), `get_novel_text`, `get_novel_events` (compact by default: chapter window / event subset unless the caller widens `fields`, `limit`, or line range), `run_sub_agent_storySkeleton`, `run_sub_agent_adaptationStrategy`, `run_sub_agent_script`, `run_supervision_agent`; production tools: `get_flowData` (`arguments.key` + optional `scriptId`; compact by default unless the caller widens `fields`, `limit`, `rowCount`, or text windows), `add_deriveAsset` (parent `assetsId` must be `app_script_asset`-linked for active `scriptId`; see **Production `add_deriveAsset`** below), `del_deriveAsset`, `generate_deriveAsset`, `generate_storyboard`, `run_sub_agent_derive_assets`, `run_sub_agent_generate_assets`, `run_sub_agent_director_plan`, `run_sub_agent_storyboard_gen`, `run_sub_agent_storyboard_panel`, `run_sub_agent_storyboard_table`, `run_sub_agent_production_supervision`; `wasm.probe` runs embedded WASM (wasmi) |
| (Harness agent) | `harness.agent.run` | `payload.content` plus optional `max_tool_rounds` — LLM-driven multi-step tool loop; requires attach + API key (see § above) |
| `chat` | `agent.chat.send` | `payload.content` (string) |
| `stop` | `agent.run.cancel` | Abort current generation |
| `updateContext` | `agent.context.update` | Same payload shape as `agent.production.attach` (`isolation_key`, **`projectUuid`** / **`project_id`**, **`scriptUuid`** / **`script_id`**); previous implementation used ack callback — use `request_id` + optional `session.ack` server message |

## Server → client (previous names → target `type`)

Previous implementation emits arbitrary Socket.IO event names. Map to `domain.action`:

| Previous event | Target `type` | Payload notes |
|--------------|---------------|---------------|
| `message` | `chat.message.created` | New message shell: `id`, `role`, `name`, `status`, `datetime`, `content` array |
| `message:update` | `chat.message.updated` | `id`, `status`, optional `ext` (e.g. `error`) |
| `content:add` | `chat.content.added` | `messageId`, `content` (discriminated by `content.type`) |
| `content:update` | `chat.content.updated` | Streaming: e.g. `append` per chunk (see § `agent.chat.send` above) |

Content block shapes follow `src/socket/chatMessagesData.d.ts` (`text`, `markdown`, `image`, `thinking`, `search`, `suggestion`, `toolcall`, `activity`, `reasoning`, etc.) until OpenAPI/JSON Schema is generated for them.

## Errors over WebSocket

| `type` | `payload` |
|--------|-----------|
| `error.occurred` | `code` (string), `message` (string), optional `request_id` inside **`payload`** (and the same id may appear on the **envelope** root when the client sent one), optional `details` |

Harness-related `code` values include **`unknown_tool`** (name not in catalog), **`tool_not_implemented`** (catalogued but no runtime path yet), **`invalid_payload`** (bad/missing args, path rules, oversize file), **`not_found`** (skill path missing), **`skill_unavailable`** (skills dir missing on server), **`isolation_failed`** (child process tool error), **`wasm_failed`** (WASM interpreter error for `wasm.probe`), **`unsupported_schema`**.

Align `code` / `message` semantics with `the exported OpenAPI document` `ErrorBody` where possible.

## Reverse proxy

Configure **one** `location` (or equivalent) for `/api/v1/` so HTTP and `Upgrade: websocket` both reach the Rust service.

## Reference implementation (previous)

- Namespaces: `src/socket/index.ts`
- Handlers: `src/socket/routes/scriptAgent.ts`, `src/socket/routes/productionAgent.ts`
- Outbound payloads: `src/socket/resTool.ts`
