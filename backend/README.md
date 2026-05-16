# OpenFlow `backend` (Rust)

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
# 可选：在 **编译** 前导出 TOONFLOW_GIT_SHA，则 GET /api/v1/version 的 JSON 会带 git_sha（运行时 .env 不会注入该项）
# export TOONFLOW_GIT_SHA=$(git rev-parse HEAD)
cargo run --bin toonflow-server
```

每 **客户端 IP** 限流（`tower_governor`）；默认按 **连接 peer IP**。仅在**受信**反向代理后可将 **`RATE_LIMIT_TRUST_FORWARDED_HEADERS=1`** 设为使用 `Forwarded` / `X-Forwarded-For` 等（未受信时勿开，易被伪造）。可用 **`RATE_LIMIT_REFILL_MS`**（默认 `20`）、**`RATE_LIMIT_BURST`**（默认 `100`）调节。**不限流**：`/health`、`/api/v1/health`、**`/api/v1/version`**、`/api/v1/ready`、**`POST /api/v1/webhooks/billing`**（计费 webhook，供收单方服务器回调；需 **`BILLING_WEBHOOK_SECRET`** + **`DATABASE_URL`**）。OpenFlow 原生签名建议带 **`X-Toonflow-Timestamp`** 并对 **`"<unix>." + body`** 做 HMAC（抗重放；容差 **`BILLING_TOONFLOW_TOLERANCE_SECS`**）；设 **`BILLING_TOONFLOW_REQUIRE_TIMESTAMP=1`** 则禁止仅对 body 签名的旧方式。**`GET /api/v1/webhooks/billing/events`**（全局审计表）仅在 **`BILLING_WEBHOOK_EVENTS_LIST_ENABLED=1`** 时可用，否则 **403**；**`backend/.env.example`** 对本地开发默认写入 **1**，生产多租户请关闭。Webhook 首次成功入库时，若 JSON 含 **`user_id`**（UUID）与 **`plan_tier`**，会 upsert **`app_user_profile`**（可选 **`billing_currency`** / **`billing_provider`**）。

异步任务 worker 多实例时设置不同 **`WORKER_ID`**，便于在任务行的 **`claimed_by`** 上区分认领实例（仍依赖 Postgres `SKIP LOCKED` 协调）。**`JOB_QUEUE_METRICS_INTERVAL_SECS`**（默认 **60**，设为 **0** 关闭）控制 worker 周期性输出结构化日志 **`event=job_queue_metrics`**（含 **`pending`**、**`pending_claimable`**、**`running`**、**`dead`**、**`failed_last_24h`**、**`oldest_claimable_queued_age_secs`**、**`pending_by_kind`** JSON、`worker_id`），便于日志聚合与旁路队列 Gate；与 500ms 抢单轮询解耦。字段语义与运维 Runbook 见 [`docs/plans/jobs-pg-queue-runbook.md`](../docs/plans/jobs-pg-queue-runbook.md)。

**`GET /api/v1/jobs/queue/stats`（Q2 方案 B）**：与上表同源 **`QueueStats`**（HTTP JSON）。须设置 **`TOONFLOW_INTERNAL_OPS_TOKEN`**（非空）；请求带 **`X-Toonflow-Internal-Token`** 与该值一致；未配置 token 时返回 **403**。用于运维脚本 / 内部前端（Flutter **`INTERNAL_OPS_TOKEN`** dart-define）拉队列深度，不等价于用户 JWT 权限模型。

**OTel / OTLP traces（WP‑F）**：设置 **`TOONFLOW_OTEL_EXPORT_ENABLED=1`**（或 **`true`** / **`yes`** / **`on`**）时，进程通过 **gRPC OTLP** 向 collector 导出 **`tracing` spans**（`opentelemetry-otlp` + `tracing-opentelemetry`）。可选环境变量：

- **`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`** 或 **`OTEL_EXPORTER_OTLP_ENDPOINT`**：collector 地址（默认 **`http://127.0.0.1:4317`**，与 OpenTelemetry Collector gRPC 端口一致）。
- **`OTEL_SERVICE_NAME`**：`service.name` resource（默认 **`toonflow-server`**）。
- **`TOONFLOW_OTEL_SAMPLE_RATE`**：OTel 导出启用时的 trace 采样率，范围 **`(0.0, 1.0]`**；缺失或不可解析默认 **`1.0`**，小于等于 **`0`** 时使用 **`0.01`** 防止生产静默关闭。

仍使用 **`RUST_LOG`**（`tracing_subscriber::EnvFilter`）控制控制台日志级别；OTel 导出与控制台是相互叠加的两个 sink。

本地烟测（需本机起 collector）：`docker run --rm -p 4317:4317 otel/opentelemetry-collector:latest`，然后  
`cd backend && TOONFLOW_OTEL_EXPORT_ENABLED=1 cargo test -p toonflow-server --test telemetry_otlp_collector_smoke otlp_export_reaches_collector -- --ignored --nocapture`（见测试文件头注释）。

若 exporter 初始化失败，进程仍会启动并仅写控制台日志，同时打出 **`target=toonflow.telemetry`** 的 **warn**（并在启动前 **`eprintln!`**），避免静默失败。

**请求关联：** 所有响应带 **`X-Request-Id`**（可客户端传入同名请求头，否则服务端生成 UUID）。`Content-Type: application/json` 的 **4xx/5xx** 若体为 OpenAPI 式 `code` + `message`，中间件会补上 **`request_id`**（与响应头一致），便于与日志对照。

### 旧库导入（SQLite → `import_staging`）

1. 确保 Supabase 迁移已应用（含 `import_staging.snapshot`）。
2. 设置 `SQLITE_PATH`（旧 `db2.sqlite`）与 `DATABASE_URL`（直连 Postgres）。
3. `cargo run --bin toonflow-sqlite-import --release`；可选 `LEGACY_IMPORT_TRUNCATE=1`。

填充 `import_user_map` 后，在 Supabase SQL（**service_role**）执行 `SELECT * FROM public.promote_import_snapshots();` 写入 `app_project` / `app_script` / `app_storyboard` / **`app_novel`** / **`app_asset`** / **`app_script_asset`** / **`app_art_style`** / **`app_user_prompt`** / **`app_asset_image`**（**`o_image`**；**`owner_user_id`** 取映射表中 **`import_user_id` 最小** 的一行；返回值九列含 **`asset_images_upserted`** 等）。详见 [`docs/migration/sqlite-to-supabase.md`](../docs/migration/sqlite-to-supabase.md)。

新建项目：**`POST /api/v1/projects`**（Bearer，JSON 体字段均可选）— 写入 **`app_project`**；**`numeric_id`** 在事务内用 **`pg_advisory_xact_lock`** + 全表 **`MAX(numeric_id)+1`** 分配，避免并发撞号。

项目删除：**`DELETE /api/v1/projects/{project_id}`**（Bearer；**`project_id`** 为项目 UUID）— 删除当前用户名下该项目；子表 **`app_script`** / **`app_storyboard`** / **`app_novel`** 等随 FK 级联删除；并清理 **`app_agent_memory`** 中同历史项目范围。

全局汇总：**`GET /api/v1/projects/summary`**（Bearer）— 单次查询当前用户 **workspace 可见**的 **`app_project`**、**`app_script`**、**`app_storyboard`**、**`app_novel`**、**`role_count`**（**`app_asset`** 且 **`asset_type = 'role'`**，与 **`…/stats`** 一致）、**`app_art_style`**（**`owner_user_id`**）、**`asset_count`**（可见项目内全部 **`app_asset`**）、**`video_count`**（**`app_video`** 终态：**`state` ∈ `生成成功|已完成|succeeded|completed`**，与制作台 material-data 一致；跨可见项目汇总）。

项目统计：**`GET /api/v1/projects/{project_id}/stats`**（Bearer；**`project_id`** UUID）— 返回该项目下 **`app_script`** / **`app_storyboard`** 条数、**`app_asset`（`asset_type = role`）** 的 **`role_count`**、**`app_novel`** 的 **`novel_count`**；**`video_count`** 为该项目 **`app_video`** 终态条数（规则同 **`…/summary`**）。

项目素材（**`app_asset`**）：**`GET`/`POST /api/v1/projects/{project_id}/assets`**（列表分页与筛选、创建）；**`GET`/`PATCH`/`DELETE …/assets/{asset_numeric_id}`**（**`asset_numeric_id`** = **`app_asset.numeric_id`**，与 OpenAPI 一致）。角景与图片子资源见 **`…/assets/corner-scape`**、**`…/assets/{asset_numeric_id}/images*`**。**旧 Electron 形 workbench**（nested 父子列表、image-bundle、clip 上传、material/batch-generation、polling、写删等）在 **`POST …/projects/{project_id}/assets/workbench/…`**；**无**顶层 **`POST /api/v1/assets/*`**。详见合并 OpenAPI（`GET /api/v1/openapi.yaml` 或 `cargo run --bin export-openapi`）与 [`docs/plans/electron-node-parity.md`](../docs/plans/electron-node-parity.md)。

画风库（用户级）：**`GET`/`POST /api/v1/art-styles`**、**`GET`/`PATCH`/`DELETE /api/v1/art-styles/numeric/{numeric_id}`**（Bearer）— **`app_art_style`**（RLS）；**`numeric_id`** 用 **`pg_advisory_xact_lock(884_422_008)`** + 全表 **`MAX(numeric_id)+1`**。**`POST /api/v1/art-styles/extract-prompt`**：多模态 **`chat/completions`**（与旧 **`extractStylePrompt`** 同系统提示词），**`images[]`→`image_url.url`**；空数组或全空白项 **400**（先于 LLM 校验）；合法请求需 LLM 密钥、不访问 PG。不含旧栈 base64 封面写本地 OSS。

新建剧本：**`POST /api/v1/projects/{project_id}/scripts`**（Bearer；**`project_id`** 为项目 UUID；JSON 体可选 `name` / `content` / `extract_state`）— 写入 **`app_script`**；**`numeric_id`** 在事务内用独立 **`pg_advisory_xact_lock`** + 全表 **`MAX(numeric_id)+1`**（与项目锁不同键）。父项目须为当前用户所有。

剧本删除：**`DELETE /api/v1/projects/{project_id}/scripts/{script_numeric_id}`**（Bearer；**`project_id`** UUID）— 删除归属当前用户项目的 **`app_script`**；其下 **`app_storyboard`** 随 FK 级联删除。

新建分镜：**`POST /api/v1/projects/{project_id}/scripts/{script_numeric_id}/storyboards`**（Bearer；**`project_id`** UUID；JSON 体字段均可选）— 写入 **`app_storyboard`**；**`numeric_id`** 为事务内 **`pg_advisory_xact_lock(884_422_003)`** + 全表 **`MAX(numeric_id)+1`**；默认填充 **`numeric_script_id`**、**`numeric_project_id`**。旧 **`o_videoTrack`** 前置插入未实现。

分镜删除：**`DELETE /api/v1/projects/{project_id}/storyboards/{storyboard_numeric_id}`**（Bearer；**`project_id`** UUID）— 删除归属当前用户剧本树下的 **`app_storyboard`** 单行（`script → project` 所有权校验）。

小说事件：**`POST /api/v1/projects/{project_id}/novel-events`** 创建 **`app_novel_event`** 行时，事务内 **`pg_advisory_xact_lock(884_422_007)`** + 全表 **`MAX(numeric_id)+1`**（**`numeric_id`** 全局唯一）。

Workbench 轨道：**`POST /api/v1/production/workbench/add-track`** 在计算下一槽位（**`GREATEST`** 于该剧本下分镜 **`track_id`** 与同项目 **`app_video_track.numeric_id`**）前取 **`pg_advisory_xact_lock(884_422_009)`**，避免并发读到同一序号。

Electron 形 workbench 新建分镜（**`POST /api/v1/production/storyboard/add`**、**`…/batch-add-info`**）与上文 REST 新建分镜一致：**`pg_advisory_xact_lock(884_422_003)`** + 全表 **`MAX(numeric_id)+1`**。

### LLM（WebSocket `agent.chat.send`）

Harness **子代理 auto-memory 注入**（`app_agent_memory` 摘要 / style bible / stage summary 等）可在本地通过环境变量调节字符上限与行数，无需改代码；缺省与历史常量一致，详见 `backend/src/harness/sub_agent/memory_limits.rs` 顶部表格。修改后需**重启进程**。

相关变量（均有安全上下限，见源码）：**`TOONFLOW_AUTO_MEMORY_MAX_CHARS`**、**`TOONFLOW_AUTO_MEMORY_KEEP_ROWS`**、**`TOONFLOW_AUTO_MEMORY_FETCH_LIMIT`**、**`TOONFLOW_AUTO_MEMORY_REWORK_LIMIT`**、**`TOONFLOW_STYLE_BIBLE_NOTE_MAX_CHARS`**、**`TOONFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS`**；旧名 **`TOONFLOW_AUTO_MEMORY_STYLE_BIBLE_NOTE_MAX_CHARS`** / **`TOONFLOW_AUTO_MEMORY_STAGE_SUMMARY_NOTE_MAX_CHARS`** 仍兼容。

设置 **`OPENAI_API_KEY`**（或 **`LLM_API_KEY`**）后，对话走 OpenAI 兼容 **`chat/completions` 流式**（可用 **`OPENAI_BASE_URL`**、**`LLM_MODEL`** 覆盖默认）。未配置时 `agent.chat.send` 返回 `error.occurred`（`llm_not_configured`）。**`POST /api/v1/art-styles/extract-prompt`** 使用同一密钥走**非流式**多模态 **`chat/completions`**（需 vision 模型，如默认 **`gpt-4o-mini`**）。

**素材出图任务（`app_generation_job`）**：**`asset.generate.image`** / **`asset.generate.batch`** worker 使用同一密钥调用 **`POST {OPENAI_BASE_URL}/v1/images/generations`**（`response_format: url`）。未设置 **`TOONFLOW_LOCAL_ASSET_IMAGE_DIR`** 时，将供应商临时 **`url`** 写入 **`app_asset_image.file_path`**（**`state`** = **`已完成`**）。设置该目录后，worker 会下载 PNG（体大小上限约 **32 MB**）到 **`{dir}/{user_uuid}/{image_row_id}.png`**，**`file_path`** 设为 **`GET /api/v1/projects/{project_uuid}/assets/{al}/images/{id}/file`** 路径（**`project_uuid`** = **`app_project.id`**），**`metadata.storage`** = **`local`**，**`metadata.provider_url`** 保留原链接；**`GET …/images/{id}/file`** 在 **`https?`** **`file_path`** 时 **307** 跳转，在 **`local`** 时返回 **`image/png`**。请求体里的 **`model`** 若不含 **`dall-e-2`** / **`dall-e-3`** 子串，则回退到环境变量 **`TOONFLOW_IMAGE_MODEL`**（默认 **`dall-e-3`**）。**`asset.polish.*`** 仍走 **`chat/completions`**。Enqueue 时的 **`base64`** 提示尚未参与生图；对象存储/CDN 仍见 **`electron-node-parity.md`**。

**HTTP 接口文档（浏览器）**：`GET http://127.0.0.1:8666/api/v1/docs` — Swagger UI **Standalone**；默认折叠 tag、带 **Filter**；`info.description` 仅一行摘要，细节见各 operation 与仓库 **`docs/plans/electron-node-parity.md`**。契约由 **`shell.rs` + 路径索引 + utoipa** 合并生成，改 handler 注解或 shell/路径桩后需重新 `cargo run` 查看。

健康检查：

- `GET http://127.0.0.1:8666/health`
- `GET http://127.0.0.1:8666/api/v1/health`

就绪（可选连库）与鉴权探针：

- `GET http://127.0.0.1:8666/api/v1/ready` — **HTTP 200**；响应除 **`database`**（无 **`DATABASE_URL`** 时为 **`not_configured`**）外还带 **`harness_isolate`**（对齐进程内 **`harness::isolate::metrics_snapshot()`**，便于运维刮取）。
- **`HARNESS_ISOLATE_MAX_CONCURRENT`**（默认 **4**）：**`isolated.echo`** isolate 并发槽 Semaphore。**`HARNESS_ISOLATE_POOL`**：**默认开启**子进程常驻帧协议（可复用工件进程）；设为 **`0` / `false` / `no` / `off`** 或 **`""`** 退回「每条 invoke **`spawn`** 一次」。**`HARNESS_ISOLATE_PREFORK`**（可选）：池启用时，进程启动阶段预先 **`spawn`** 至多 **`min(该整数, HARNESS_ISOLATE_MAX_CONCURRENT)`** 个池 worker 填入 idle 队列，缩短首包 **`isolated.echo`** 冷路径；缺省或未设置等价 **`0`**（不预热）；池关闭时忽略。**`HARNESS_ISOLATE_POOL_IDLE_TTL_SECS`** / **`HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS`**（可选）：正整数秒；前者丢弃在 idle 队列中空闲超过该时间的 worker，后者丢弃自 **`spawn`** 起超过该年龄的 worker；未设或 **`0`** 表示不启用该项；剔除会计入 **`total_pool_evictions`**（**`GET /api/v1/ready`** → **`harness_isolate`**）。**`HARNESS_ISOLATE_RUNNER_EXE`**（可选）：子进程可执行文件路径，默认为 API 进程的 **`current_exe`**；集成测试常设为 **`CARGO_BIN_EXE_toonflow-server`**。
- `GET http://127.0.0.1:8666/api/v1/me` — 请求头 `Authorization: Bearer <Supabase access_token>`
- `GET http://127.0.0.1:8666/api/v1/usage/summary` — 当前用户在 **`app_usage_event`** 中的条数（近 24h / 近 7 天）及近 7 天按 **`event_type`** 分组的 **`event_counts_last_7d`**；成功完成的生成任务由 worker 写入 **`generation_job.succeeded`**
- 生成任务（**`app_generation_job`**；Bearer）：**`GET /api/v1/jobs`**（列表，可选 query **`kind`** / **`status`** 精确筛选）、**`GET /api/v1/jobs/kinds`**（**`kind`** 去重）、**`GET /api/v1/jobs/kinds/summary`**（按 **`kind`** 计数）、**`GET /api/v1/jobs/status/summary`**（按 **`status`** 计数）、**`POST /api/v1/jobs`** 等 — 详见 OpenAPI
- 静态模型目录（编译时嵌入 **`data/models_catalog.json`**；Bearer；对齐旧 **`modelSelect`** 的 **`type`** 过滤语义，无 Postgres **`o_vendorConfig`**）：
  - `GET /api/v1/models?type=text|image|video|all` — `all` 不含 `video`
  - `GET /api/v1/models/detail?model_id={vendor_id}:{model_name}` — 如 `1:gpt-4o-mini`
- Agent 记忆（Postgres **`app_agent_memory`**；需已迁移；Bearer JWT；请求体优先 **`projectUuid`**（**`app_project.id`**），兼容 legacy **`projectId`**（**`app_project.numeric_id`**）；若两者同发须指向同一项目）：
  - `POST /api/v1/agents/memory/query` — 默认列出 `message` 行；可用 `memoryType: message|summary|all` 读取自动摘要记忆或合并视图（camelCase body，对齐旧 **`/api/agents/getMemory`** 并扩展 summary 检查）
  - `POST /api/v1/agents/memory/clear` — 清除语义对齐旧 **`/api/agents/clearMemory`**（`type` 或 `clearType`：`all` / `message` / `summary`）
  - `POST /api/v1/agents/memory/append` — 追加一条 message（不做 Node 侧自动摘要压缩）
  - `GET /api/v1/agents/memory/cost-overview` — query 同样支持 **`projectUuid`** 或 **`projectId`**

WebSocket（JSON 信封见合并 OpenAPI 中 **`GET /api/v1/ws`**；仓库 **`docs/websocket-events.md`** 为稳定链接入口，正文以 OpenAPI 为准）：

- 可选 **`HARNESS_WS_CHANNELS`**：逗号分隔的频道白名单（**`script`**、**`production`**）。未设置时两种 attach 均允许；设置后仅列表中的频道可通过 `agent.script.attach` / `agent.production.attach`（用于运维或阶段性关频道）。
- `GET ws://127.0.0.1:8666/api/v1/ws` — 可选查询参数 `access_token=<jwt>`；否则首帧发 `session.auth`
- 鉴权后可发 **`harness.tool.invoke`**（`schema_version` 1，`payload.name` / 可选 `arguments`）；**`echo`** 回显参数；**`isolated.echo`** 与 `echo` 语义相同但在**子进程**中执行（进程隔离；并发与复用见上文 **`HARNESS_ISOLATE_*`**；集成测试通常将 **`HARNESS_ISOLATE_RUNNER_EXE`** 设为 **`CARGO_BIN_EXE_toonflow-server`**）。**可观测（WP‑D）**：每条 **`isolated.echo`** 结束前有 **`tracing`** 行（**`target = harness.isolate.metrics`**、**`event = harness_isolate_invoke`**：`queued_ahead`、`semaphore_wait_ms`、`child_execution_ms`、`available_slots_snapshot`/`max_slots`、`reuse_hit`、`process_reuse_hits_total`）；**`GET /api/v1/ready`** 与 **`metrics_snapshot()`** 均含累计字段（含 **`total_process_reuse_hits`**；池关闭时复用为 **0**）；**`skills.read`** 需 `arguments.path`（相对 `data/skills`，规则同 `GET /api/v1/skills/content`）；**`wasm.probe`** 在进程内用 **wasmi** 执行构建期生成的最小 WASM（`build.rs` → `OUT_DIR/probe.wasm`）；运维可设 **`HARNESS_WASM_PROBE_DISABLED=1`**（或 **`true`** / **`yes`** / **`on`**）拒绝 **`wasm.probe`** 调用；**WP‑C（用户上传 WASM，薄切片）**：投递前可复用 **`validate_user_wasm_upload`** + **`HARNESS_USER_WASM_MAX_BYTES`**（默认 524288，无效或 **`0`** 回退默认）做体量与解析校验（见 `harness/wasm_runtime.rs`）；目录见 `GET /api/v1/harness/tools`
- 已 attach **`agent.script.attach` / `agent.production.attach`** 且配置 LLM 密钥时，可发 **`harness.agent.run`**（`payload.content`，可选 **`max_tool_rounds`** 默认 8、限制 1–32；可选 **`payload.stream`**，WP‑E）：服务端多轮 OpenAI **tools** 调用与 Harness 工具闭环，最终仍发 **`chat.message.*`** 文本信封。若 **`payload.stream=true`**，须 **`HARNESS_AGENT_STREAMING_TOOLS=1`**（否则 WS 返回 **`not_implemented`**）；启用后当前仍走同一套非流式 completion + 工具循环（流式 token 事件后续里程碑）。

Harness 用户 WASM 告警评估默认每 **60 秒**运行一次（设 **`HARNESS_USER_WASM_ALERT_EVAL_INTERVAL_SECS=0`** 可关闭），读取 **`app_harness_user_wasm_audit`** 的滚动窗口并写入通知中心：

- **`HARNESS_USER_WASM_ALERT_VALIDATE_FAIL_RATE`**：validate / object-store 失败率阈值，默认 **`0.1`**。
- **`HARNESS_USER_WASM_ALERT_INVOKE_FAIL_RATE`**：`invoke_wasm_failed` 阈值，默认 **`0.1`**。
- **`HARNESS_USER_WASM_ALERT_FUEL_EXHAUSTION_RATE`**：`invoke_wasm_timeout` 阈值，默认 **`0.2`**。
- **`HARNESS_USER_WASM_ALERT_WINDOW_SECS`**：评估窗口秒数，默认 **`300`**。
- **`HARNESS_USER_WASM_ALERT_MIN_EVENTS`**：触发阈值前的最小样本量，默认 **`5`**。
- **`HARNESS_ALERT_WEBHOOK_URL`**：可选；触发/恢复时异步 POST 告警 JSON，失败仅记录日志。
- **`HARNESS_ALERT_OPS_USER_ID`**：可选；通知中心接收人 UUID，缺省使用 nil UUID 作为系统操作员哨兵。

告警排障步骤与 SQL / 日志查询模板见 [`docs/plans/harness-wasm-alert-runbook.md`](../docs/plans/harness-wasm-alert-runbook.md)。

技能 Markdown（只读，Bearer JWT）：

- `GET /api/v1/skills/summary` — `data/skills` 下 Markdown 数量与总字节（与列表同上限）
- `GET /api/v1/skills` — 列出 `data/skills/**/*.md`
- `GET /api/v1/skills/content?path=…` — 读取单个文件（防 `..` 穿越）
- `GET /api/v1/harness/tools` — 当前注册的 Harness 工具（`name` + `description`；调度仍占位）

## 技能资产

Harness 与 REST 技能接口只读 **`backend/data/skills/`**（相对 crate 为 `data/skills/`）；仓库根 **不再**保留第二套 `data/skills`。

## 路线图

见仓库 [`docs/plans/harness-rust-flutter.md`](../docs/plans/harness-rust-flutter.md)。
