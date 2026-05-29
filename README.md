<p align="center">
  <strong>简体中文</strong> |
  <a href="./docs/README.en.md">English</a>
</p>

<div align="center">

# OpenFlow

<p align="center">
  <b>
    AI 短剧工厂
    <br />
    Rust + Flutter + PostgreSQL 全栈创作平台
    <br />
    闭源云端 SaaS · 注册登录后使用
  </b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/产品-闭源%20SaaS-7C97FF?style=for-the-badge" alt="Proprietary SaaS" />
  <img src="https://img.shields.io/badge/客户端-Desktop%20%2B%20Web-34C8F0?style=for-the-badge" alt="Desktop and Web" />
  <img src="https://img.shields.io/badge/栈-Rust%20%2B%20Flutter%20%2B%20Supabase-1a1a2e?style=for-the-badge" alt="Tech stack" />
</p>

> 从小说/剧本到分镜、资产、制作与短剧发布的 **Harness Engineering** 工作流。  
> 本仓库为**专有源码树**，不对外开源；客户端与生产环境由商务授权分发。

</div>

---

## 项目简介

OpenFlow 是面向短剧团队的 **AI 内容生产平台**：用户在 **Workspace**（个人 / 企业）内完成策划、编剧、分镜、资产、视频制作、质检与发布。业务 API 由 **Rust（Axum）** 提供，客户端为 **Flutter**（macOS / Windows / Linux 桌面 + Web），数据与鉴权依托 **Supabase PostgreSQL + Auth（JWT + RLS）**。

### 产品工作区（Studio Shell）

默认入口 `frontend/lib/main.dart` 启动 **Studio 产品壳**（`StudioProductApp` + `go_router`），主要能力包括：

| 区域 | 说明 |
|------|------|
| **项目** | 项目列表、创建向导、创作旅程（脚本 → 美术 → 资产 → 分镜 → 视频 → 交付） |
| **剧本 / 制作** | Agent 工作区：剧本编辑、生产流水线、分镜工作室 overlay |
| **短剧空间** | 短剧策划、时间线、候选对比、组装导出、发布草稿；PC 三栏 + Mobile 沉浸预览壳 |
| **任务 / 作业** | 任务中心、异步作业队列状态、质量评审 |
| **平台** | 通知、内容合规、API Key、团队 Workspace、平台配置、Benchmark、帮助中心 |

开发者调试可用 **Harness 壳**：`flutter run -t lib/main_harness.dart`（探针、WS 工具面，非终端用户主路径）。

### 后端能力摘要

| 能力 | 实现要点 |
|------|----------|
| REST API | OpenAPI 3.1，`GET /api/v1/docs` 浏览契约；`frontend/lib/rust_api/` 与契约对齐 |
| 实时 | WebSocket `/api/v1/ws`，Harness 协议（Agent 对话、工具调用、流式推送） |
| 任务队列 | PostgreSQL `SKIP LOCKED` 分布式 worker（出图、出视频、导出等） |
| 多租户 | Workspace 成员与 RLS；`GET /api/v1/me` 等受 JWT 保护 |
| 可观测 | 请求 `X-Request-Id`；可选 OTLP trace 导出 |
| 计费 | Stripe / Alipay / Paddle Webhook（环境变量启用） |

桌面端通过 **`rust_core/`** + `flutter_rust_bridge` 提供原生桥接（文件、通知等）；详见 [`frontend/README.md`](frontend/README.md)。

---

## 仓库结构

```
Toonflow-app/
├── backend/                 # Rust 服务（openflow-server，默认 :8666）
├── frontend/                # Flutter 客户端（Studio 产品壳 + Harness）
│   └── lib/
│       ├── design_system/   # Studio 设计系统（组件、主题、异步三态规范）
│       ├── product_shell/   # 路由、侧栏、登录
│       ├── short_video_space/  # 短剧业务（竖切 part 模块）
│       ├── project_studio/  # 项目内创作步骤
│       ├── rust_api/        # OpenAPI 对齐的 Dart API 门面
│       └── native_bridge/   # 桌面 Rust bridge
├── rust_core/               # 桌面原生能力 crate
├── supabase/migrations/     # 数据库迁移（CLI 应用，Rust 不重复跑）
├── docs/
│   ├── roadmaps/            # 技术路线图与 parity 进度（主索引）
│   └── plans/               # UI/UX、E2E、专项计划与 signoff
├── scripts/                 # 门禁、E2E、运维脚本
├── website/                 # 营销静态页（与 API 同端口可选挂载）
├── env/                     # 本地开发环境变量模板（Supabase 演示密钥）
└── AGENTS.md                # AI / CI 协作约定（门禁、竖切、异步三态）
```

历史 **Electron / Node** 栈已从本分支移除；对照旧实现见 `master` 与 [`docs/roadmaps/parity-audit.md`](docs/roadmaps/parity-audit.md)。

---

## 终端用户

1. 注册 / 登录（Supabase Auth）
2. 创建或加入 Workspace
3. 在 Studio 中管理项目，沿创作旅程完成剧本 → 分镜 → 制作 → 短剧发布
4. 按订阅与用量计费（以部署环境配置为准）

安装包与生产 URL **不在本仓库公开发布**。

---

## 本地开发（授权成员）

> 克隆与使用须遵守 [LICENSE](./LICENSE)。

### 环境要求

| 工具 | 用途 |
|------|------|
| **Rust** stable | 编译 `backend/`、`rust_core/` |
| **Flutter** 3.10+（SDK ^3.10） | 客户端 |
| **Supabase CLI** + **Docker** | 本地 Postgres / Auth |
| **Node.js** + **Yarn** | 根目录门禁与 E2E 脚本 |

### 快速启动

```bash
# 1. 数据库
supabase start
supabase status    # 核对端口与 JWT secret

# 2. 后端
cd backend
cp .env.example .env   # DATABASE_URL、SUPABASE_JWT_SECRET
cargo run --bin openflow-server
# → http://127.0.0.1:8666  （/api/v1/docs 为 API 文档）

# 3. 前端（产品壳，推荐）
cd frontend
flutter pub get
flutter run -d chrome --dart-define-from-file=dart_defines.dev.json
# 桌面：flutter run -d macos --dart-define-from-file=dart_defines.dev.json
```

`env/.env.dev` 与 `frontend/dart_defines.dev.json` 已对齐本地 Supabase 默认端口（见 `supabase/config.toml`）；改端口时需同步两处。

### 健康检查

```bash
curl http://127.0.0.1:8666/api/v1/health
open http://127.0.0.1:8666/api/v1/docs
```

### 工程门禁

日常开发优先使用 **Agent 入口**（增量 / 跳过全量测试）：

```bash
yarn refactor:agent              # 默认 incremental
yarn refactor:agent --quick      # 提交前快速自检
yarn refactor:agent --full       # 与 CI 同级：含 backend/frontend 全量测试
```

等价于 `scripts/refactor-check.sh` 的三种模式，说明见 [`scripts/REFACTOR_CHECK_MODES.md`](scripts/REFACTOR_CHECK_MODES.md)。

其他常用脚本：

```bash
yarn test:ui:e2e                 # 产品壳 UI E2E
cd backend && cargo test         # 仅后端测试
cd frontend && flutter test      # 仅前端测试
```

---

## 开发约定（摘要）

- **全栈竖切**：用户可见能力需 `backend` + `frontend/rust_api` + 契约同里程碑交付（见 [`docs/quality/full-stack-delivery-covenant.md`](docs/quality/full-stack-delivery-covenant.md)）。
- **Flutter UI**：异步加载遵循 [`frontend/lib/design_system/ASYNC_LOADING.md`](frontend/lib/design_system/ASYNC_LOADING.md)；mutation 按钮使用 `StudioDebouncedAction`。
- **单文件体量**：`backend/`、`frontend/lib/` 建议 ≤800 行，过长则拆 `part` / 子模块。
- **Agent 行为**：见根目录 [`AGENTS.md`](AGENTS.md)。

---

## 文档索引

| 文档 | 说明 |
|------|------|
| [`backend/README.md`](backend/README.md) | 环境变量、OpenAPI、任务队列、迁移 |
| [`frontend/README.md`](frontend/README.md) | 运行模式、dart-define、桌面 bridge |
| [`docs/roadmaps/README.md`](docs/roadmaps/README.md) | **技术路线图总入口** |
| [`docs/roadmaps/master-roadmap.md`](docs/roadmaps/master-roadmap.md) | 架构里程碑与分支策略 |
| [`docs/roadmaps/parity-audit.md`](docs/roadmaps/parity-audit.md) | 旧栈 → Rust/Flutter 功能对照 |
| [`docs/plans/flutter-ui-ux-developer-guide.md`](docs/plans/flutter-ui-ux-developer-guide.md) | Studio UI/UX 开发指南 |
| [`docs/plans/short-video-ui-ux-rebuild.md`](docs/plans/short-video-ui-ux-rebuild.md) | 短剧链路 UI 交付说明 |
| [`docs/api/websocket-events.md`](docs/api/websocket-events.md) | WebSocket 事件协议 |
| [`docs/migration/database-migrations.md`](docs/migration/database-migrations.md) | 数据库迁移 |

---

## 许可与联系

OpenFlow 为**闭源专有软件**，完整条款见 **[LICENSE](./LICENSE)**。第三方开源组件见 **`NOTICES.txt`**。

📧 商务 / 授权：[ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow%E5%95%86%E5%8A%A1%E5%92%A8%E8%AF%A2)

---

## 致谢

构建时使用 Rust、Flutter、Supabase、PostgreSQL 等开源生态；产品本身不开源。

<table>
  <tr>
    <td><b>算能云</b> 提供算力赞助 <a href="https://www.sophnet.com/">[官网]</a></td>
  </tr>
</table>

---

<sub>copyright © 淮北艾阿网络科技有限公司</sub>
