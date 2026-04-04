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

### `generation.job.updated` (server → client)

Pushed when a row in `app_generation_job` owned by the caller transitions (for example `queued` → `running` → `succeeded` / `failed`). **`payload`** is the full job object (snake_case: `id`, `owner_user_id`, `kind`, `status`, `payload`, `result`, `error_message`, `created_at`, `updated_at`).

The server registers the connection for push after auth (`?access_token=` or `session.auth`).

### `session.ack` (server → client)

Generic success for attach / context update / cancel; carries `request_id` when the client sent one.

### `agent.chat.send` → LLM stream (server → client)

When `OPENAI_API_KEY` or `LLM_API_KEY` is configured, the server streams an OpenAI-compatible **`/v1/chat/completions`** response and emits (in order):

1. **`chat.message.created`** — assistant shell (`status`: `streaming`, `name`: `统筹` or `视频策划` by channel).
2. **`chat.content.added`** — first `text` block (`messageId`, `content.id`).
3. **`chat.content.updated`** — repeated; `payload.append` carries each token/chunk (client concatenates for full text).
4. **`chat.message.updated`** — `status`: `complete` or `stop` (cancel / disconnect).

If the API key is missing, respond with **`error.occurred`** (`code`: `llm_not_configured`). Upstream failures use `code`: `llm_error`.

## Channels vs legacy Socket.IO namespaces

Legacy Node stack used Socket.IO namespaces:

| Legacy namespace | Purpose |
|------------------|---------|
| `/api/socket/scriptAgent` | 剧本 / 统筹 Agent |
| `/api/socket/productionAgent` | 视频策划 Agent |

**Target mapping**: `payload.channel` on the first post-auth message, or dedicated connect types:

| `type` | Meaning |
|--------|---------|
| `agent.script.attach` | Former `scriptAgent` namespace |
| `agent.production.attach` | Former `productionAgent` namespace |

`payload` should carry `isolation_key`, `project_id`, and for production `script_id` where applicable (mirrors handshake `auth` fields today).

## Client → server (legacy names → target `type`)

| Legacy Socket.IO event | Target `type` | Notes |
|------------------------|---------------|--------|
| `chat` | `agent.chat.send` | `payload.content` (string) |
| `stop` | `agent.run.cancel` | Abort current generation |
| `updateContext` | `agent.context.update` | Production only; `isolation_key`, `project_id`, `script_id`; legacy used ack callback — use `request_id` + optional `session.ack` server message |

## Server → client (legacy names → target `type`)

Legacy emits arbitrary Socket.IO event names. Map to `domain.action`:

| Legacy event | Target `type` | Payload notes |
|--------------|---------------|---------------|
| `message` | `chat.message.created` | New message shell: `id`, `role`, `name`, `status`, `datetime`, `content` array |
| `message:update` | `chat.message.updated` | `id`, `status`, optional `ext` (e.g. `error`) |
| `content:add` | `chat.content.added` | `messageId`, `content` (discriminated by `content.type`) |
| `content:update` | `chat.content.updated` | Streaming: e.g. `append` per chunk (see § `agent.chat.send` above) |

Content block shapes follow `src/socket/chatMessagesData.d.ts` (`text`, `markdown`, `image`, `thinking`, `search`, `suggestion`, `toolcall`, `activity`, `reasoning`, etc.) until OpenAPI/JSON Schema is generated for them.

## Errors over WebSocket

| `type` | `payload` |
|--------|-----------|
| `error.occurred` | `code` (string), `message` (string), optional `request_id`, optional `details` |

Align `code` / `message` semantics with `docs/openapi.yaml` `ErrorBody` where possible.

## Reverse proxy

Configure **one** `location` (or equivalent) for `/api/v1/` so HTTP and `Upgrade: websocket` both reach the Rust service.

## Reference implementation (legacy)

- Namespaces: `src/socket/index.ts`
- Handlers: `src/socket/routes/scriptAgent.ts`, `src/socket/routes/productionAgent.ts`
- Outbound payloads: `src/socket/resTool.ts`
