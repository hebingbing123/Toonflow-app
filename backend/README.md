# Toonflow `backend` (Rust)

Axum HTTP 服务，默认端口 **8666**（环境变量 `PORT` 可覆盖）。

## 本地数据库（Supabase CLI）

在仓库根目录：

```bash
supabase start
supabase status   # 复制 DB URL、JWT secret
```

迁移位于 `supabase/migrations/`，由 **`supabase db reset`** / `db push` 应用；Rust 进程**不**重复跑迁移，避免与 CLI 迁移表冲突。

## 开发与运行

```bash
cd backend
cp .env.example .env   # 填入 DATABASE_URL、SUPABASE_JWT_SECRET、（可选）OPENAI_API_KEY
cargo run
```

### LLM（WebSocket `agent.chat.send`）

设置 **`OPENAI_API_KEY`**（或 **`LLM_API_KEY`**）后，对话走 OpenAI 兼容 **`chat/completions` 流式**（可用 **`OPENAI_BASE_URL`**、**`LLM_MODEL`** 覆盖默认）。未配置时 `agent.chat.send` 返回 `error.occurred`（`llm_not_configured`）。

健康检查：

- `GET http://127.0.0.1:8666/health`
- `GET http://127.0.0.1:8666/api/v1/health`

就绪（可选连库）与鉴权探针：

- `GET http://127.0.0.1:8666/api/v1/ready`
- `GET http://127.0.0.1:8666/api/v1/me` — 请求头 `Authorization: Bearer <Supabase access_token>`

WebSocket（JSON 信封见 `docs/websocket-events.md`）：

- `GET ws://127.0.0.1:8666/api/v1/ws` — 可选查询参数 `access_token=<jwt>`；否则首帧发 `session.auth`

## 技能资产

Harness 用 Markdown 技能位于 **`data/skills/`**（由仓库根目录 `data/skills` 复制而来；过渡期 Node 栈仍可使用根目录副本）。

## 路线图

见仓库 [`docs/plans/harness-rust-flutter.md`](../docs/plans/harness-rust-flutter.md)。
