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

每 **客户端 IP** 限流（`tower_governor`）；默认按 **连接 peer IP**。仅在**受信**反向代理后可将 **`RATE_LIMIT_TRUST_FORWARDED_HEADERS=1`** 设为使用 `Forwarded` / `X-Forwarded-For` 等（未受信时勿开，易被伪造）。可用 **`RATE_LIMIT_REFILL_MS`**（默认 `20`）、**`RATE_LIMIT_BURST`**（默认 `100`）调节。**不限流**：`/health`、`/api/v1/health`、**`/api/v1/version`**、`/api/v1/ready`、**`POST /api/v1/webhooks/billing`**（计费 webhook，供收单方服务器回调；需 **`BILLING_WEBHOOK_SECRET`** + **`DATABASE_URL`**）。Webhook 首次成功入库时，若 JSON 含 **`user_id`**（UUID）与 **`plan_tier`**，会 upsert **`app_user_profile`**（可选 **`billing_currency`** / **`billing_provider`**）。

异步任务 worker 多实例时设置不同 **`WORKER_ID`**，便于在任务行的 **`claimed_by`** 上区分认领实例（仍依赖 Postgres `SKIP LOCKED` 协调）。

**请求关联：** 所有响应带 **`X-Request-Id`**（可客户端传入同名请求头，否则服务端生成 UUID）。`Content-Type: application/json` 的 **4xx/5xx** 若体为 OpenAPI 式 `code` + `message`，中间件会补上 **`request_id`**（与响应头一致），便于与日志对照。

### 旧库导入（SQLite → `legacy_staging`）

1. 确保 Supabase 迁移已应用（含 `legacy_staging.snapshot`）。
2. 设置 `SQLITE_PATH`（旧 `db2.sqlite`）与 `DATABASE_URL`（直连 Postgres）。
3. `cargo run --bin toonflow-legacy-import --release`；可选 `LEGACY_IMPORT_TRUNCATE=1`。

填充 `legacy_user_map` 后，在 Supabase SQL（**service_role**）执行 `SELECT * FROM public.promote_legacy_from_staging();` 写入 `app_project` / `app_script`。详见 [`docs/migration/legacy-sqlite-to-supabase.md`](../docs/migration/legacy-sqlite-to-supabase.md)。

新建项目：**`POST /api/v1/projects`**（Bearer，JSON 体字段均可选）— 写入 **`app_project`**；**`legacy_id`** 在事务内用 **`pg_advisory_xact_lock`** + 全表 **`MAX(legacy_id)+1`** 分配，避免并发撞号。

项目删除：**`DELETE /api/v1/projects/legacy/{legacy_id}`**（Bearer）— 删除当前用户名下该 legacy 项目；子表 **`app_script`** / **`app_storyboard`** 随 FK 级联删除；并清理 **`app_agent_memory`** 中同 legacy 项目范围。

全局汇总：**`GET /api/v1/projects/summary`**（Bearer）— 当前用户跨所有项目的 **`app_project`** / **`app_script`** / **`app_storyboard`** 总行数（单次查询）。

项目统计：**`GET /api/v1/projects/legacy/{legacy_id}/stats`**（Bearer）— 返回当前用户该项目下 **`app_script`** / **`app_storyboard`** 条数；**`role_count`** / **`video_count`** 暂为 **`0`**（对齐旧 **`generalStatistics`** 字段名语义，尚无 PG 版 **`o_assets`** / **`o_video`**）。

新建剧本：**`POST /api/v1/projects/legacy/{project_legacy_id}/scripts`**（Bearer，JSON 体可选 `name` / `content` / `extract_state`）— 写入 **`app_script`**；**`legacy_id`** 在事务内用独立 **`pg_advisory_xact_lock`** + 全表 **`MAX(legacy_id)+1`**（与项目锁不同键）。父项目须为当前用户所有。

剧本删除：**`DELETE /api/v1/scripts/legacy/{legacy_id}`**（Bearer）— 删除归属当前用户项目的 **`app_script`**；其下 **`app_storyboard`** 随 FK 级联删除。

新建分镜：**`POST /api/v1/scripts/legacy/{script_legacy_id}/storyboards`**（Bearer，JSON 体字段均可选）— 写入 **`app_storyboard`**；**`legacy_id`** 为事务内 **`pg_advisory_xact_lock(884_422_003)`** + 全表 **`MAX(legacy_id)+1`**；默认填充 **`legacy_script_id`**、**`legacy_project_id`**。旧 **`o_videoTrack`** 前置插入未实现。

分镜删除：**`DELETE /api/v1/storyboards/legacy/{legacy_id}`**（Bearer）— 删除归属当前用户剧本树下的 **`app_storyboard`** 单行（`script → project` 所有权校验）。

### LLM（WebSocket `agent.chat.send`）

设置 **`OPENAI_API_KEY`**（或 **`LLM_API_KEY`**）后，对话走 OpenAI 兼容 **`chat/completions` 流式**（可用 **`OPENAI_BASE_URL`**、**`LLM_MODEL`** 覆盖默认）。未配置时 `agent.chat.send` 返回 `error.occurred`（`llm_not_configured`）。

健康检查：

- `GET http://127.0.0.1:8666/health`
- `GET http://127.0.0.1:8666/api/v1/health`

就绪（可选连库）与鉴权探针：

- `GET http://127.0.0.1:8666/api/v1/ready`
- `GET http://127.0.0.1:8666/api/v1/me` — 请求头 `Authorization: Bearer <Supabase access_token>`
- `GET http://127.0.0.1:8666/api/v1/usage/summary` — 当前用户在 **`app_usage_event`** 中的条数（近 24h / 近 7 天）及近 7 天按 **`event_type`** 分组的 **`event_counts_last_7d`**；成功完成的生成任务由 worker 写入 **`generation_job.succeeded`**
- 生成任务（**`app_generation_job`**；Bearer）：**`GET /api/v1/jobs`**（列表，可选 query **`kind`** / **`status`** 精确筛选）、**`GET /api/v1/jobs/kinds`**（**`kind`** 去重）、**`GET /api/v1/jobs/kinds/summary`**（按 **`kind`** 计数）、**`GET /api/v1/jobs/status/summary`**（按 **`status`** 计数）、**`POST /api/v1/jobs`** 等 — 详见 OpenAPI
- 静态模型目录（编译时嵌入 **`data/models_catalog.json`**；Bearer；对齐旧 **`modelSelect`** 的 **`type`** 过滤语义，无 Postgres **`o_vendorConfig`**）：
  - `GET /api/v1/models?type=text|image|video|all` — `all` 不含 `video`
  - `GET /api/v1/models/detail?model_id={vendor_id}:{model_name}` — 如 `1:gpt-4o-mini`
- Agent 记忆（Postgres **`app_agent_memory`**；需已迁移；Bearer JWT；需用户拥有对应 **`app_project.legacy_id`**）：
  - `POST /api/v1/agents/memory/query` — 列出 message 行（camelCase body，对齐旧 **`/api/agents/getMemory`**）
  - `POST /api/v1/agents/memory/clear` — 清除语义对齐旧 **`/api/agents/clearMemory`**（`type` 或 `clearType`：`all` / `message` / `summary`）
  - `POST /api/v1/agents/memory/append` — 追加一条 message（不做 Node 侧自动摘要压缩）

WebSocket（JSON 信封见 `docs/websocket-events.md`）：

- `GET ws://127.0.0.1:8666/api/v1/ws` — 可选查询参数 `access_token=<jwt>`；否则首帧发 `session.auth`
- 鉴权后可发 **`harness.tool.invoke`**（`schema_version` 1，`payload.name` / 可选 `arguments`）；**`echo`** 回显参数；**`isolated.echo`** 与 `echo` 语义相同但在**子进程**中执行（进程隔离）；**`skills.read`** 需 `arguments.path`（相对 `data/skills`，规则同 `GET /api/v1/skills/content`）；目录见 `GET /api/v1/harness/tools`

技能 Markdown（只读，Bearer JWT）：

- `GET /api/v1/skills` — 列出 `data/skills/**/*.md`
- `GET /api/v1/skills/content?path=…` — 读取单个文件（防 `..` 穿越）
- `GET /api/v1/harness/tools` — 当前注册的 Harness 工具（`name` + `description`；调度仍占位）

## 技能资产

Harness 用 Markdown 技能位于 **`data/skills/`**（由仓库根目录 `data/skills` 复制而来；过渡期 Node 栈仍可使用根目录副本）。

## 路线图

见仓库 [`docs/plans/harness-rust-flutter.md`](../docs/plans/harness-rust-flutter.md)。
