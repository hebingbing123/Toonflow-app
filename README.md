<p>
  <a href="https://github.com/HBAI-Ltd/Toonflow-app">
    <img src="https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white" alt="GitHub" />
  </a>
  &nbsp;|&nbsp;
  <a href="https://gitee.com/HBAI-Ltd/Toonflow-app">
    <img src="https://img.shields.io/badge/Gitee-C71D23?style=flat-square&logo=gitee&logoColor=white" alt="Gitee" />
  </a>
</p>

<p align="center">
  <strong>简体中文</strong> |
  <a href="./docs/README.en.md">English</a>
</p>

<div align="center">


# OpenFlow

  <p align="center">
    <b>
      AI短剧工厂
      <br />
      动动手指，小说秒变剧集！
      <br />
      AI剧本 × AI影像 × 极速生成 🔥
    </b>
  </p>
  <p align="center">
    <a href="https://github.com/HBAI-Ltd/Toonflow-app/stargazers">
      <img src="https://img.shields.io/github/stars/HBAI-Ltd/Toonflow-app?style=for-the-badge&logo=github" alt="Stars Badge" />
    </a>
    <a href="https://www.apache.org/licenses/LICENSE-2.0" target="_blank">
      <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge" alt="Apache-2.0 License Badge" />
    </a>
    <a href="https://github.com/HBAI-Ltd/Toonflow-app/releases">
      <img alt="release" src="https://img.shields.io/github/v/release/HBAI-Ltd/Toonflow-app?style=for-the-badge" />
    </a>
  </p>
  
  > 🚀 **一站式短剧工程**：从文本到角色，从分镜到视频，0门槛全流程AI化，创作效率提升10倍+！
</div>



---

## 架构概览

OpenFlow 采用现代化的 **Monorepo + 前后端分离** 架构，基于 **Harness Engineering** 设计理念构建：

### 技术栈

| 层次 | 技术选型 | 说明 |
|------|---------|------|
| **后端服务** | Rust + Axum + Tokio | 异步 HTTP/WebSocket API，默认端口 **8666** |
| **前端应用** | Flutter (Desktop + Web) | 跨平台客户端，通过可配置 `API_BASE_URL` 连接后端 |
| **数据库** | PostgreSQL (Supabase) | 生产环境托管；开发环境本地 CLI (`supabase start`) |
| **鉴权** | Supabase Auth | JWT Bearer token，支持 RLS 行级安全 |
| **实时通信** | WebSocket (`/api/v1/ws`) | Harness 协议，支持 Agent 工具调用与流式对话 |
| **API 契约** | OpenAPI 3.1 | 自动生成文档，浏览器访问 `/api/v1/docs` |

### 目录结构

| 目录 | 说明 |
|------|------|
| **`backend/`** | Rust 后端服务（Axum + SQLx + Tokio）<br/>• 默认端口 **8666**<br/>• 技能 Markdown 在 `backend/data/skills/`<br/>• 详见 [`backend/README.md`](backend/README.md) |
| **`frontend/`** | Flutter 客户端（桌面 + Web）<br/>• 通过 `API_BASE_URL` 连接后端<br/>• 可选 `SUPABASE_URL` / `SUPABASE_ANON_KEY`<br/>• 详见 [`frontend/README.md`](frontend/README.md) |
| **`docs/plans/`** | 技术路线图与设计文档<br/>• 主路线图：[`harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md)<br/>• 功能对齐清单：[`electron-node-parity.md`](docs/plans/electron-node-parity.md) |
| **`supabase/`** | 数据库迁移与配置<br/>• 开发：`supabase start`（本地 Docker）<br/>• 生产：Supabase 云端托管<br/>• 迁移文件：`supabase/migrations/` |
| **`backend/src/openapi_spec/`** | OpenAPI 规范定义<br/>• `shell.rs` + `generated/` 路径桩<br/>• 运行时合并生成完整文档 |
| **`docs/websocket-events.md`** | WebSocket 事件协议文档<br/>• 稳定链接入口<br/>• 详细规范见 OpenAPI `/api/v1/ws` |
| **`space/`** | 产品专题空间<br/>• 短视频能力借鉴：[`space/short-video/`](space/short-video/) |

### 核心特性

- ✅ **Harness Engineering 架构**：工具注册、权限策略、可观测性、Agent 循环统一管理
- ✅ **多租户 Workspace**：支持 Personal（个人）和 Enterprise（企业）工作空间
- ✅ **异步任务队列**：基于 PostgreSQL `SKIP LOCKED` 的分布式任务调度
- ✅ **实时 WebSocket**：支持 Agent 工具调用、流式对话、任务状态推送
- ✅ **进程隔离沙箱**：`isolated.echo` 工具通过子进程池实现安全隔离
- ✅ **WASM 运行时**：支持用户上传 WASM 模块，带配额与告警机制
- ✅ **OpenTelemetry 集成**：支持 OTLP traces 导出到 Collector
- ✅ **计费 Webhook**：支持 Stripe/Alipay/Paddle 多供应商事件处理

> **重构完成**：旧 Electron + Node 栈已下线（`decommission-electron`）。当前主产品为 `backend/` + `frontend/` 新栈。  
> **自动化协作**：按 [`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md) 连续交付增量即可；Agent 行为约定见 **[`AGENTS.md`](AGENTS.md)**。  
> **危险运维**：HTTP **`/api/v1/settings/danger/*`** 故意保持 **501**；如需按用户清理 SaaS 数据，使用 **`cargo run --bin toonflow-server --manifest-path backend/Cargo.toml -- ops clear-user-data --user-id <uuid> --dry-run`**，确认后再加 **`--execute --confirm clear-user-data:<uuid>`**。

### CI 与工程规范

#### 本地重构门禁

在仓库根目录执行（与 CI 对齐）：

```bash
yarn refactor:check
```

该脚本会依次执行：
1. **OpenAPI 解析校验**：`cargo run --bin export-openapi` 导出 YAML 并验证格式
2. **Rust 检查**：
   - `cargo fmt --check`：代码格式检查
   - `cargo clippy -- -D warnings`：Lint 检查
   - `cargo test`：单元测试
3. **Flutter 检查**：
   - `flutter pub get`：依赖安装
   - `flutter analyze`：静态分析
   - `flutter test`：单元测试

**前置条件**：
- 本机已安装 **Rust stable** 与 **Flutter**
- 已配置 `DATABASE_URL` 和 `SUPABASE_JWT_SECRET`（部分测试需要）

#### 持续集成（CI）

GitHub Actions 配置：[`.github/workflows/ci.yml`](.github/workflows/ci.yml)

**触发条件**：
- 向 `main` / `master` 提交 PR
- 向 `main` / `master` 推送代码

**CI 任务**：

1. **refactor-monorepo**：
   - 执行 `scripts/refactor-check.sh`（与本地一致）
   - 包含 OpenAPI 解析、Rust 和 Flutter 全量检查

2. **supabase-migrations**：
   - `supabase db start`：启动本地数据库
   - `supabase db reset`：应用所有迁移
   - 验证迁移文件语法和执行

3. **legacy-lint**（可选）：
   - `yarn lint`：TypeScript 配置体检（`tsc --noEmit`）
   - 仅检查根目录配置文件

#### 数据库迁移

**迁移文件位置**：`supabase/migrations/`

**命名规范**：`YYYYMMDDHHMMSS_description.sql`

**创建新迁移**：

```bash
# 在仓库根目录
supabase migration new your_migration_name
```

**应用迁移**：

```bash
# 本地开发
supabase db reset  # 重置并应用所有迁移

# 生产环境
supabase db push  # 推送到远程项目
```

**迁移最佳实践**：
- 使用事务（`BEGIN; ... COMMIT;`）
- 添加回滚脚本注释
- 避免破坏性变更（如删除列）
- 使用 `IF NOT EXISTS` / `IF EXISTS`
- 测试迁移的幂等性

详见 [`docs/migration/database-migrations.md`](docs/migration/database-migrations.md)

#### 工具链

**Rust 版本锁定**：[`rust-toolchain.toml`](rust-toolchain.toml)

```toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
```

**依赖更新**：[`.github/dependabot.yml`](.github/dependabot.yml)

自动检查以下依赖更新：
- Cargo（Rust 依赖）
- pub（Flutter 依赖）
- GitHub Actions

#### 代码规范

**Rust**：
- 使用 `rustfmt` 格式化（`cargo fmt`）
- 遵循 Clippy 建议（`cargo clippy`）
- 错误处理使用 `anyhow` 或自定义错误类型
- 异步代码使用 `async/await` + Tokio
- 数据库查询使用 SQLx 编译期校验

**Flutter**：
- 使用 `flutter_lints` 规则集
- 遵循 Effective Dart 指南
- 状态管理使用 Provider
- 异步操作使用 `async/await` + `FutureBuilder`
- 国际化使用 `flutter_localizations`

**Git 提交规范**：
- 使用语义化提交信息（Conventional Commits）
- 格式：`<type>(<scope>): <subject>`
- 类型：`feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- 示例：`feat(harness): add WASM runtime support`

#### 发布流程

1. **更新版本号**：
   - `backend/Cargo.toml`：`version = "x.y.z"`
   - `frontend/pubspec.yaml`：`version: x.y.z+build`

2. **生成 Changelog**：
   - 汇总本次发布的功能、修复和破坏性变更

3. **创建 Git Tag**：
   ```bash
   git tag -a vx.y.z -m "Release x.y.z"
   git push origin vx.y.z
   ```

4. **GitHub Release**：
   - 在 GitHub 上创建 Release
   - 上传构建产物（桌面安装包）
   - 附上 Changelog

5. **部署生产环境**：
   - 后端：构建 Docker 镜像并部署
   - 前端：构建 Web 版本并部署到 CDN
   - 数据库：应用新迁移（`supabase db push`）

详见 [`.github/workflows/release.yml`](.github/workflows/release.yml)

# 🌐 多语言支持

OpenFlow 支持以下语言界面：

| 语言 | Language |
|------|----------|
| 简体中文 | Chinese (Simplified) |
| 繁體中文 | Chinese (Traditional) |
| English | English |
| ไทย | Thai |
| Tiếng Việt | Vietnamese |
| 日本語 | Japanese |
| Русский | Russian |

> 💡 更多语言适配中，欢迎贡献翻译！

---

# 🌟 主要功能

OpenFlow v1.0.8 是面向短剧生产的 AI 工作台，围绕“策划 → 编剧 → 分镜 → 出片”构建完整闭环，并支持本地化、可编程、可持续迭代的生产流程。

- ✅ **无限画布生产工作台**  
  以类无限画布形式组织剧本、角色、分镜、素材与视频节点，支持自由编排、回溯与并行生产，不受线性步骤限制。
- ✅ **三层 Agent 协作体系**  
  决策层、执行层、监督层协同工作，覆盖任务拆解、内容生成、质量审阅与修订反馈，提升稳定性与成片一致性。
- ✅ **持久化 Agent 记忆**  
  基于本地 ONNX 向量检索的跨会话记忆系统，支持短期消息、长期摘要和语义召回，确保多轮创作连续性。
- ✅ **可编程供应商系统**  
  支持在设置中心直接编写供应商 TypeScript 逻辑并即时生效，无需改源码或重启，便于私有化和多模型接入。
- ✅ **章节事件图谱驱动改编**  
  自动提取原著章节事件并结构化存储，剧本改编按事件图谱精准调用上下文，减少长文本信息丢失。
- ✅ **Skill 文件化配置**  
  ScriptAgent 与 ProductionAgent 的核心提示词外化为 Markdown Skill 文件，支持在线编辑与快速调优。

---

# 📦 应用场景

- 网文/小说快速影视化改编
- 短剧团队流水线协作生产
- 多项目并行的 AI 内容工厂
- 私有化部署的企业级内容平台
- 低成本验证剧情与镜头方案
- 教学与研究场景下的 AIGC 创作实验

---

# 🔰 使用指南

## 🚀 v1.0.8 快速上手

1. 启动应用并登录（默认账号：`admin` / `admin123`）。
2. 在设置中心完成模型供应商配置（文本/图像/视频模型）。
3. 新建项目并导入原著，执行章节事件提取。
4. 进入 ScriptAgent 生成故事骨架、改编策略与结构化剧本。
5. 切换到 ProductionAgent，在无限画布中组织分镜、素材与视频节点。
6. 对分镜图进行节点化精调后回流工作台，完成视频拼接与导出。


## 📺 视频教程(待更新，老版本教程已无参考价值)

https://www.bilibili.com/video/BV1na6wB6Ea2
**OpenFlow 8 分钟快速上手 AI 视频**
👉 [点击观看](https://www.bilibili.com/video/BV1na6wB6Ea2/?share_source=copy_web&vd_source=5b718c25439a901a34c7bc0c1d35b38e)

---



# 🚀 安装

## 前置条件

在安装和使用本软件之前，请准备以下内容：

- ✅ 大语言模型 AI 服务接口地址
- ✅ Sora 或豆包视频服务接口地址
- ✅ Nano Banana Pro 图片生成模型服务接口

## 本机安装

### 1. 下载与安装

| 操作系统 | GitHub                                                  | Atomgit                                               | 夸克网盘下载                                    | 说明           |
| :------: | :----------------------------------------------------------- | :------------------------------------------------------------ | :---------------------------------------------- | :------------- |
| Windows  | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |
|  Linux   | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |
|  macOS   | [Release](https://github.com/HBAI-Ltd/Toonflow-app/releases) | [Release](https://gitcode.com/HBAI-Ltd/Toonflow-app/releases) | [夸克网盘](https://pan.quark.cn/s/94ef07509df0) | 官方发布安装包 |

> [!CAUTION]
> MacOS 系统请到 设置-隐私与安全性 配置安全性否则可能因证书问题无法正常打开
>
> 参考知乎文档：[https://www.zhihu.com/question/433389276](https://www.zhihu.com/question/433389276)

> 因 Gitee OS 环境限制及 Release 文件上传大小限制，暂不提供 Gitee Release 下载地址。

### 2. 启动服务

安装完成后，启动程序即可开始使用本服务。

> ⚠️ **首次登录**  
> 账号：`admin`  
> 密码：`admin123`

## Docker 与自建服务（新栈）

旧版 **`yarn docker:local`**、根目录 **`data/serve`**、固定端口 **10588** 等与 Electron 内嵌 Node 一体的方案 **已移除**。自建 API 请参考：

- **`backend/README.md`**：`cargo run --bin toonflow-server`、**`DATABASE_URL`**（Supabase Postgres）及可选存储/模型环境变量  
- **`supabase/`** 与 **`docs/migration/database-migrations.md`**  
- 契约：**合并 OpenAPI**（`GET /api/v1/openapi.yaml` 或 `export-openapi`）、**`docs/websocket-events.md`**

容器镜像若仍引用历史 Dockerfile，以路线图 **[`docs/plans/harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md)** 为准逐步替换。

## 云端部署

旧版 **Node + PM2 + `data/serve/app.js`** 已下线。请在具备 **Postgres（推荐 Supabase）** 的环境中部署 **`backend/`**，客户端将 **`API_BASE_URL`** 指向该服务（见 **`frontend/README.md`**）。

---

# 🔧 开发流程指南

> [!CAUTION]
> 🚧 **PR 提交规范** 🚧
>
> ⛔ `master` 分支不接受任何 PR ｜ ✅ 请将 PR 提交到 `develop` 分支
>
> 欢迎开发者们共同参与 OpenFlow 的共创。如有兴趣加入，请在交流群内联系主理人 ACT

## 🛠️ 技术栈

### 后端（Backend）

| 类别 | 技术 | 说明 |
|------|------|------|
| **语言** | Rust (Edition 2021) | 类型安全、内存安全、高性能 |
| **Web 框架** | Axum 0.8 | 基于 Tower 的异步 HTTP 框架 |
| **异步运行时** | Tokio | 高性能异步 I/O |
| **数据库** | PostgreSQL + SQLx | 编译期 SQL 校验，连接池管理 |
| **鉴权** | Supabase Auth + JWT | HS256 签名校验，RLS 行级安全 |
| **WebSocket** | Axum WS | 原生 WebSocket 支持 |
| **API 文档** | utoipa 5.4 | OpenAPI 3.1 自动生成 |
| **可观测性** | tracing + OpenTelemetry | 结构化日志 + OTLP traces |
| **限流** | tower_governor | 基于 IP 的令牌桶限流 |
| **沙箱** | 子进程 + wasmi | 进程隔离 + WASM 运行时 |

**核心依赖**：
- `sqlx` 0.8：PostgreSQL 驱动，支持迁移与编译期查询校验
- `serde` + `serde_json`：序列化/反序列化
- `reqwest`：HTTP 客户端，用于调用 LLM API
- `jsonwebtoken`：JWT 签名校验
- `uuid`：UUID v4 生成
- `chrono`：时间处理
- `tower-http`：CORS、Trace、Request ID 中间件

### 前端（Frontend）

| 类别 | 技术 | 说明 |
|------|------|------|
| **框架** | Flutter 3.10+ | 跨平台 UI 框架 |
| **平台** | Desktop (macOS/Windows/Linux) + Web | 不含移动端 |
| **状态管理** | Provider + ChangeNotifier | 响应式状态管理 |
| **网络** | http + web_socket_channel | REST + WebSocket 客户端 |
| **鉴权** | supabase_flutter 2.8 | Supabase Auth SDK |
| **本地存储** | shared_preferences | 持久化配置 |
| **路由** | go_router 14.8 | 声明式路由 |
| **国际化** | flutter_localizations + intl | 多语言支持 |

**核心依赖**：
- `supabase_flutter`：Supabase 客户端，处理登录/会话
- `http`：REST API 调用
- `web_socket_channel`：WebSocket 连接
- `video_player`：视频播放
- `audioplayers`：音频播放
- `google_fonts`：字体加载（支持代理）

### 数据库（Database）

| 类别 | 技术 | 说明 |
|------|------|------|
| **数据库** | PostgreSQL 15+ | 关系型数据库 |
| **托管** | Supabase | 生产环境云端托管 |
| **本地开发** | Supabase CLI | `supabase start` 本地 Docker 栈 |
| **迁移** | Flyway 式 SQL | 版本化迁移文件 |
| **RLS** | Row Level Security | 行级安全策略 |

**核心表**：
- `app_project`：项目（UUID 主键 + numeric_id 兼容）
- `app_script`：剧本
- `app_storyboard`：分镜
- `app_asset`：资产（角色/场景/道具）
- `app_novel`：小说章节
- `app_generation_job`：异步任务队列
- `app_agent_memory`：Agent 记忆
- `app_workspace`：工作空间（personal/enterprise）
- `app_workspace_member`：成员关系

### 基础设施（Infrastructure）

| 类别 | 技术 | 说明 |
|------|------|------|
| **CI/CD** | GitHub Actions | 自动化测试与构建 |
| **容器** | Docker | 本地开发与部署 |
| **监控** | OpenTelemetry Collector | Traces 收集 |
| **限流** | tower_governor | IP 级别令牌桶 |
| **对象存储** | AWS S3 (可选) | 资产文件存储 |

## 开发环境准备

### 必需工具

| 工具 | 版本要求 | 用途 |
|------|---------|------|
| **Rust** | stable (见 `rust-toolchain.toml`) | 后端编译 |
| **Flutter** | 3.10+ | 前端开发 |
| **Node.js** | 18+ | 根目录工具脚本 |
| **Yarn** | 1.x | 包管理与脚本 |
| **Supabase CLI** | latest | 本地数据库 |
| **Docker** | latest | Supabase 本地栈 |

### 环境配置

#### 1. 安装 Rust

```bash
# 使用 rustup 安装（会自动读取 rust-toolchain.toml）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# 验证安装
rustc --version
cargo --version
```

#### 2. 安装 Flutter

```bash
# macOS (使用 Homebrew)
brew install --cask flutter

# 或从官网下载：https://flutter.dev/docs/get-started/install

# 验证安装
flutter doctor
```

#### 3. 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# 其他平台见：https://supabase.com/docs/guides/cli

# 验证安装
supabase --version
```

#### 4. 安装 Node.js 与 Yarn

```bash
# macOS
brew install node yarn

# 验证安装
node --version
yarn --version
```

## 快速开始（开发者）

### 1. 克隆仓库

```bash
git clone https://github.com/HBAI-Ltd/Toonflow-app.git
cd Toonflow-app
```

### 2. 启动本地数据库

```bash
# 在仓库根目录启动 Supabase 本地栈（PostgreSQL + Auth）
supabase start

# 查看连接信息（复制 DB URL 和 JWT secret）
supabase status
```

输出示例：
```
API URL: http://127.0.0.1:64321
DB URL: postgresql://postgres:postgres@127.0.0.1:64322/postgres
anon key: eyJ...
service_role key: eyJ...
```

### 3. 配置后端环境变量

```bash
cd backend
cp .env.example .env
```

编辑 `.env` 文件，填入必需配置：

```bash
# 数据库连接（从 supabase status 获取）
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:64322/postgres

# JWT 密钥（从 supabase status 获取 service_role key 对应的 secret）
SUPABASE_JWT_SECRET=your-jwt-secret-here

# 可选：LLM API 密钥（用于 Agent 对话和画风提取）
OPENAI_API_KEY=sk-...
# 或使用兼容 API
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.your-provider.com/v1

# 可选：图片生成模型
TOONFLOW_IMAGE_MODEL=dall-e-3

# 可选：本地资产图片存储目录
TOONFLOW_LOCAL_ASSET_IMAGE_DIR=/path/to/asset/images

# 可选：编译时 Git SHA（用于版本追踪）
# export TOONFLOW_GIT_SHA=$(git rev-parse HEAD)
```

### 4. 启动后端服务

```bash
cd backend
cargo run --bin toonflow-server
```

服务启动后监听 `http://127.0.0.1:8666`

**健康检查**：
```bash
curl http://127.0.0.1:8666/health
curl http://127.0.0.1:8666/api/v1/health
```

**API 文档**：浏览器访问 `http://127.0.0.1:8666/api/v1/docs`

### 5. 配置前端环境

```bash
cd frontend
flutter pub get
```

创建 `dart_defines.dev.json`（已有默认配置）：

```json
{
  "API_BASE_URL": "http://127.0.0.1:8666",
  "SUPABASE_URL": "http://127.0.0.1:64321",
  "SUPABASE_ANON_KEY": "your-anon-key-from-supabase-status"
}
```

### 6. 启动前端应用

```bash
cd frontend

# Web 开发模式（推荐）
flutter run -d chrome --dart-define-from-file=dart_defines.dev.json

# 或桌面模式
flutter run -d macos --dart-define-from-file=dart_defines.dev.json  # macOS
flutter run -d windows --dart-define-from-file=dart_defines.dev.json  # Windows
flutter run -d linux --dart-define-from-file=dart_defines.dev.json  # Linux
```

### 7. 运行测试与检查

```bash
# 在仓库根目录

# 安装依赖
yarn install

# 运行完整重构门禁（包含 OpenAPI 解析、Rust 和 Flutter 检查）
yarn refactor:check

# 或分步运行
cd backend
cargo fmt --check  # 代码格式检查
cargo clippy -- -D warnings  # Lint 检查
cargo test  # 单元测试

cd ../frontend
flutter analyze  # 静态分析
flutter test  # 单元测试
```

### 8. 数据迁移（可选）

如果需要从旧 SQLite 数据库迁移：

```bash
cd backend

# 设置环境变量
export SQLITE_PATH=/path/to/old/db2.sqlite
export DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:64322/postgres

# 运行迁移工具
cargo run --bin toonflow-sqlite-import --release

# 在 Supabase SQL Editor 中执行（使用 service_role）
SELECT * FROM public.promote_import_snapshots();
```

详见 [`docs/migration/sqlite-to-supabase.md`](docs/migration/sqlite-to-supabase.md)

### 常见问题

**Q: 后端启动失败，提示数据库连接错误**  
A: 确保 `supabase start` 已运行，并且 `.env` 中的 `DATABASE_URL` 与 `supabase status` 输出一致。

**Q: 前端无法连接后端**  
A: 检查 `dart_defines.dev.json` 中的 `API_BASE_URL` 是否正确，确保后端服务已启动。

**Q: WebSocket 连接失败**  
A: 确保 `SUPABASE_ANON_KEY` 配置正确，并且后端日志中没有 JWT 校验错误。

**Q: 图片生成任务失败**  
A: 检查 `.env` 中的 `OPENAI_API_KEY` 或 `LLM_API_KEY` 是否配置，以及模型是否支持图片生成。

## 前端开发

### 目录结构

```
frontend/
├── lib/
│   ├── account/              # 账户管理
│   ├── admin_console/        # 管理控制台
│   ├── agent_workspaces/     # Agent 工作区（Script/Production）
│   ├── api_keys/             # API 密钥管理
│   ├── auth/                 # 鉴权模块
│   ├── benchmark/            # 性能基准测试
│   ├── content_compliance/   # 内容合规
│   ├── design_system/        # 设计系统组件
│   ├── episode_console/      # 剧集控制台
│   ├── global_search/        # 全局搜索
│   ├── jobs/                 # 任务管理
│   ├── l10n/                 # 国际化（自动生成）
│   ├── locale/               # 语言切换
│   ├── navigation/           # 路由导航
│   ├── notifications/        # 通知中心
│   ├── overview/             # 概览页
│   ├── platform/             # 平台适配
│   ├── platform_status/      # 平台状态
│   ├── product_shell/        # 产品壳（登录/侧栏）
│   ├── project_editor/       # 项目编辑器
│   ├── project_studio/       # 项目工作室
│   ├── projects/             # 项目列表
│   ├── quality_reviews/      # 质量评审
│   ├── rust_api/             # Rust API 客户端
│   ├── script_editor/        # 剧本编辑器
│   ├── settings/             # 设置中心
│   ├── shell/                # 应用壳
│   ├── short_video_space/    # 短视频空间
│   ├── skills_harness/       # 技能 Harness
│   ├── storyboard_editor/    # 分镜编辑器
│   ├── storyboard_studio/    # 分镜工作室
│   ├── studio/               # 工作室
│   ├── system_probes/        # 系统探针
│   ├── task_center/          # 任务中心
│   ├── team_workspaces/      # 团队工作空间
│   ├── utils/                # 工具函数
│   ├── config.dart           # 配置管理
│   ├── home_page.dart        # 首页（Harness 探针）
│   ├── main.dart             # 主入口
│   ├── main_harness.dart     # Harness 模式入口
│   ├── main_product.dart     # 产品模式入口
│   └── rust_api.dart         # Rust API 封装
├── test/                     # 单元测试
├── integration_test/         # 集成测试
├── assets/                   # 静态资源
├── pubspec.yaml              # 依赖配置
└── README.md                 # 前端文档
```

### 运行模式

#### Harness 模式（开发调试）

```bash
cd frontend
flutter run -d chrome -t lib/main_harness.dart --dart-define-from-file=dart_defines.dev.json
```

特点：
- 长页面布局，包含所有探针和调试工具
- 直接访问 REST API、WebSocket、Agent 工具
- 适合后端接口调试和功能验证

#### Product 模式（产品体验）

```bash
cd frontend
flutter run -d chrome -t lib/main_product.dart --dart-define-from-file=dart_defines.dev.json
```

特点：
- 侧栏导航 + 登录页
- 完整的产品 UX（项目/剧本/分镜/资产管理）
- 类似 [waoowaoo](https://github.com/waooAI/waoowaoo) 的信息架构

### 功能开关

#### Workspace 计费

```bash
# 启用 workspace 级别计费（默认关闭）
flutter run -d chrome --dart-define=ENABLE_WORKSPACE_BILLING=true
```

详见 [`docs/plans/workspace-billing-feature-flag-guide.md`](docs/plans/workspace-billing-feature-flag-guide.md)

#### 内部运维 Token

```bash
# 访问内部运维接口（如队列统计）
flutter run -d chrome --dart-define=OPENFLOW_INTERNAL_OPS_TOKEN=your-secret-token
```

### 国际化

支持的语言：
- 简体中文 (zh)
- 繁體中文 (zh_TW)
- English (en)
- ไทย (th)
- Tiếng Việt (vi)
- 日本語 (ja)
- Русский (ru)

添加新翻译：
1. 编辑 `lib/l10n/app_*.arb` 文件
2. 运行 `flutter gen-l10n` 生成代码
3. 在应用中使用 `AppLocalizations.of(context)!.yourKey`

### 测试

```bash
cd frontend

# 单元测试
flutter test

# 集成测试（需要后端运行）
flutter test integration_test/

# 特定测试文件
flutter test test/rust_api_support_test.dart

# 覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 构建

```bash
cd frontend

# Web 构建
flutter build web --release

# 桌面构建
flutter build macos --release  # macOS
flutter build windows --release  # Windows
flutter build linux --release  # Linux
```

构建产物：
- Web: `build/web/`
- macOS: `build/macos/Build/Products/Release/`
- Windows: `build/windows/runner/Release/`
- Linux: `build/linux/x64/release/bundle/`

## 后端开发

### 目录结构

```
backend/
├── src/
│   ├── app/                  # 应用核心（路由、状态）
│   ├── assets/               # 资产管理
│   ├── auth/                 # 鉴权中间件
│   ├── billing/              # 计费 Webhook
│   ├── error/                # 错误处理
│   ├── harness/              # Harness 核心
│   │   ├── http.rs           # Harness HTTP 端点
│   │   ├── ws/               # WebSocket 实现
│   │   ├── tools/            # 工具注册
│   │   ├── isolate/          # 进程隔离
│   │   └── wasm_runtime.rs   # WASM 运行时
│   ├── jobs/                 # 异步任务队列
│   ├── llm/                  # LLM 客户端
│   ├── manuals/              # 创作手册
│   ├── narrative/            # 叙事管理
│   ├── openapi_spec/         # OpenAPI 规范
│   ├── production/           # 制作工作台
│   ├── projects/             # 项目管理
│   ├── prompting/            # 提示词管理
│   ├── publish/              # 发布管理
│   ├── scope/                # 作用域管理
│   ├── scripting/            # 剧本管理
│   ├── search/               # 搜索功能
│   ├── settings/             # 设置管理
│   ├── short_video/          # 短视频
│   ├── state/                # 应用状态
│   ├── telemetry/            # 可观测性
│   ├── vendor/               # 供应商配置
│   ├── workspaces/           # 工作空间
│   ├── lib.rs                # 库入口
│   ├── main.rs               # 主程序入口
│   └── metrics.rs            # 指标收集
├── data/
│   ├── skills/               # 技能 Markdown
│   ├── models/               # 模型配置
│   ├── prompts/              # 提示词模板
│   └── models_catalog.json   # 模型目录
├── tests/                    # 集成测试
├── Cargo.toml                # 依赖配置
├── build.rs                  # 构建脚本
└── README.md                 # 后端文档
```

### 核心模块

#### Harness 核心

**工具注册**（`src/harness/tools/`）：
- `echo`：回显工具（测试用）
- `isolated.echo`：子进程隔离回显
- `skills.read`：读取技能文件
- `wasm.probe`：WASM 运行时探针

**WebSocket 实现**（`src/harness/ws/`）：
- `upgrade.rs`：WebSocket 升级
- `connection.rs`：连接管理
- `dispatch.rs`：消息分发
- `auth.rs`：鉴权处理
- `tool.rs`：工具调用
- `agent.rs`：Agent 运行
- `chat.rs`：对话管理

**进程隔离**（`src/harness/isolate/`）：
- 子进程池管理
- 帧协议通信
- 并发槽控制
- TTL 与复用策略

#### 异步任务队列

**任务类型**（`src/jobs/`）：
- `asset.generate.image`：单张资产图片生成
- `asset.generate.batch`：批量资产图片生成
- `asset.polish.prompt`：提示词优化
- `asset.polish.batch`：批量提示词优化
- `video.generate`：视频生成
- `voiceover.generate`：配音生成

**队列机制**：
- 基于 PostgreSQL `SKIP LOCKED`
- 多实例 worker 协调
- 任务状态机：`queued` → `running` → `succeeded`/`failed`/`cancelled`
- 幂等性支持（`Idempotency-Key`）

#### 计费 Webhook

**支持的供应商**（`src/billing/`）：
- Stripe：订阅事件、发票事件
- Alipay：支付事件
- Paddle：订阅事件、交易事件

**事件处理**：
- HMAC 签名校验
- 去重（`provider:event_id`）
- 状态机保护（防止乱序回滚）
- 审计日志（`app_billing_webhook_event`）

### 环境变量

#### 必需配置

```bash
# 数据库连接
DATABASE_URL=postgresql://user:pass@host:port/db

# JWT 密钥（Supabase service_role secret）
SUPABASE_JWT_SECRET=your-jwt-secret
```

#### LLM 配置

```bash
# OpenAI 兼容 API
OPENAI_API_KEY=sk-...
OPENAI_BASE_URL=https://api.openai.com/v1  # 可选

# 或使用通用配置
LLM_API_KEY=sk-...
LLM_BASE_URL=https://api.your-provider.com/v1
LLM_MODEL=gpt-4o-mini  # 默认文本模型

# 图片生成模型
TOONFLOW_IMAGE_MODEL=dall-e-3
```

#### 存储配置

```bash
# 本地资产图片存储
TOONFLOW_LOCAL_ASSET_IMAGE_DIR=/path/to/images

# 本地画风封面存储
TOONFLOW_LOCAL_ART_STYLE_COVER_DIR=/path/to/covers

# AWS S3（可选）
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_BUCKET_NAME=your-bucket
```

#### Harness 配置

```bash
# 进程隔离并发槽
HARNESS_ISOLATE_MAX_CONCURRENT=4

# 进程池（默认开启）
HARNESS_ISOLATE_POOL=1

# 预热进程数
HARNESS_ISOLATE_PREFORK=2

# 空闲 TTL（秒）
HARNESS_ISOLATE_POOL_IDLE_TTL_SECS=300

# 最大进程年龄（秒）
HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS=3600

# WebSocket 频道白名单（逗号分隔）
HARNESS_WS_CHANNELS=script,production

# 禁用 WASM 探针
HARNESS_WASM_PROBE_DISABLED=0

# 用户 WASM 体量上限（字节）
HARNESS_USER_WASM_MAX_BYTES=524288
```

#### 计费配置

```bash
# Webhook 密钥
BILLING_WEBHOOK_SECRET=your-webhook-secret

# 时间戳容差（秒）
BILLING_TOONFLOW_TOLERANCE_SECS=300

# 强制时间戳校验
BILLING_TOONFLOW_REQUIRE_TIMESTAMP=1

# 事件列表端点（生产环境建议关闭）
BILLING_WEBHOOK_EVENTS_LIST_ENABLED=0

# 货币-供应商映射（可选）
BILLING_CURRENCY_PROVIDER_MAP=CNY:alipay,USD:stripe
```

#### 限流配置

```bash
# 信任转发头（仅在受信反向代理后启用）
RATE_LIMIT_TRUST_FORWARDED_HEADERS=0

# 令牌桶参数
RATE_LIMIT_REFILL_MS=20
RATE_LIMIT_BURST=100
```

#### 可观测性配置

```bash
# OpenTelemetry 导出
TOONFLOW_OTEL_EXPORT_ENABLED=1
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317
OTEL_SERVICE_NAME=toonflow-server

# 采样率（0.0-1.0）
TOONFLOW_OTEL_SAMPLE_RATE=1.0

# 任务队列指标间隔（秒，0 关闭）
JOB_QUEUE_METRICS_INTERVAL_SECS=60

# 内部运维 Token
OPENFLOW_INTERNAL_OPS_TOKEN=your-ops-token
```

#### Worker 配置

```bash
# Worker 实例 ID（多实例部署时区分）
WORKER_ID=worker-1

# Agent 记忆注入限制
TOONFLOW_AUTO_MEMORY_MAX_CHARS=8000
TOONFLOW_AUTO_MEMORY_KEEP_ROWS=50
TOONFLOW_AUTO_MEMORY_FETCH_LIMIT=100
TOONFLOW_STYLE_BIBLE_NOTE_MAX_CHARS=2000
TOONFLOW_STAGE_SUMMARY_NOTE_MAX_CHARS=2000
```

### 测试

```bash
cd backend

# 单元测试
cargo test

# 集成测试（需要数据库）
cargo test --test '*' -- --ignored

# 特定测试
cargo test --test harness_isolate_echo

# 覆盖率（需要 tarpaulin）
cargo tarpaulin --out Html
```

### 构建

```bash
cd backend

# 开发构建
cargo build

# 发布构建
cargo build --release

# 构建所有二进制
cargo build --release --bins
```

二进制文件：
- `toonflow-server`：主服务
- `toonflow-sqlite-import`：SQLite 迁移工具
- `export-openapi`：导出 OpenAPI 规范
- `reconcile-billing`：计费对账工具
- `quality-export`：质量数据导出
- `quality-regression-check`：质量回归检查
- `backfill-job-workspace-id`：任务 workspace_id 回填

### 运维工具

#### 导出 OpenAPI

```bash
cd backend
cargo run --bin export-openapi > openapi.yaml
```

#### 数据迁移

```bash
cd backend
export SQLITE_PATH=/path/to/db2.sqlite
export DATABASE_URL=postgresql://...
cargo run --bin toonflow-sqlite-import --release
```

#### 清理用户数据

```bash
cd backend
cargo run --bin toonflow-server -- ops clear-user-data \
  --user-id <uuid> \
  --dry-run

# 确认后执行
cargo run --bin toonflow-server -- ops clear-user-data \
  --user-id <uuid> \
  --execute \
  --confirm clear-user-data:<uuid>
```

#### 计费对账

```bash
cd backend
cargo run --bin reconcile-billing --release
```

#### 质量数据导出

```bash
cd backend
cargo run --bin quality-export --release
```

---

# 🔗 相关仓库

| 仓库             | 说明                               | GitHub                                             | Gitee                                            |
| ---------------- | ---------------------------------- | -------------------------------------------------- | ------------------------------------------------ |
| **Toonflow-app** | 完整客户端（本仓库，推荐普通用户） | [GitHub](https://github.com/HBAI-Ltd/Toonflow-app) | [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-app) |
| **Toonflow-web** | 旧版 Web 前端（历史参考）         | [GitHub](https://github.com/HBAI-Ltd/Toonflow-web) | [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-web) |

> 💡 **提示**：当前主客户端在 **`frontend/`**（Flutter）。**Toonflow-web** 为旧栈参考仓库。

---

# 👨‍👩‍👧‍👦 微信交流群

---

# 💌 联系我们

📧 邮箱：[ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow咨询)

---

# 📜 许可证

OpenFlow 基于 Apache-2.0 协议开源发布，并附有补充商业协议。

许可证详情：https://www.apache.org/licenses/LICENSE-2.0

## 补充协议

- 若将本软件以产品形式分发给 **2 个及以上独立第三方**使用，须取得 HBAI-Ltd **书面商业授权**。
- **≤ 5 个法人**联合运营内部使用，不对外提供服务的，视为内部使用，**无需授权**。
- 不得删除或修改 OpenFlow 中的标识或版权信息。

## 永久免费场景

- ✅ 用 OpenFlow 制作内容并获得平台分账
- ✅ 二次开发供自己团队内部使用
- ✅ ≤ 5 个法人联合运营内部使用
- ✅ 个人学习、研究、非商业用途

## 商业授权定价

| 阶段 | 年销售额 | 年费 |
|------|---------|------|
| 🌱 扶持期 | < ¥10 万 | **申请即可免费授权** |
| 🚀 初创期 | ¥10–50 万 | ¥5,000/年 |
| 📈 成长期 | ¥50–150 万 | ¥20,000/年 |
| 🏢 规模期 | ¥150–500 万 | ¥80,000/年 |
| 🌐 企业级 | > ¥500 万 | 面议 |

> **不追溯条款**：v1.0.8 发布前基于 AGPL-3.0 使用的用户，继续按 AGPL-3.0 执行，不受本协议变更约束。

完整协议详见 [LICENSE](./LICENSE) 文件。

---

# ⭐️ 星标历史

[![Star History Chart](https://api.star-history.com/svg?repos=HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)](https://www.star-history.com/#HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)

---

# 🙏 致谢

感谢以下开源项目为 OpenFlow 提供支持（当前栈节选）：

- [Rust](https://www.rust-lang.org/) / [Tokio](https://tokio.rs/) / [Axum](https://github.com/tokio-rs/axum)
- [Flutter](https://flutter.dev/)
- [Supabase](https://supabase.com/)
- [SQLx](https://github.com/launchbadge/sqlx)
- [PostgreSQL](https://www.postgresql.org/)

感谢以下组织/单位/个人为 OpenFlow 提供支持：

<table>
  <tr>
    <td>
      <b>算能云</b> 提供算力赞助
      <a href="https://www.sophnet.com/">[官网]</a>
    </td>
  </tr>
</table>

完整的第三方依赖清单请查阅 `NOTICES.txt`

##### copyright © 淮北艾阿网络科技有限公司
