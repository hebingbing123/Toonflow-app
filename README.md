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
      基于 Harness Engineering 的智能创作平台
      <br />
      闭源云端 SaaS · 注册登录后使用
    </b>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/产品-闭源%20SaaS-7C97FF?style=for-the-badge" alt="Proprietary SaaS" />
    <img src="https://img.shields.io/badge/访问-注册登录-34C8F0?style=for-the-badge" alt="Registration required" />
    <img src="https://img.shields.io/badge/技术栈-Rust%20%2B%20Flutter%20%2B%20PostgreSQL-1a1a2e?style=for-the-badge" alt="Tech stack" />
  </p>
  
  > 🚀 **现代化技术栈**：Rust 后端 + Flutter 前端 + PostgreSQL 数据库，从文本到视频的完整 AI 创作工作流  
  > 🔒 **非开源产品**：不提供公开源码或开源自部署版本；客户端与接入文档由商务授权发放。
</div>

---

## 📖 项目简介

OpenFlow 是基于 **Harness Engineering** 架构的 **闭源云端 SaaS** AI 短剧生产平台，采用 **Rust + Flutter + PostgreSQL** 技术栈，提供从策划到成片的完整工作流。用户须**注册并登录**后进入 Workspace 进行创作；业务 API 使用 Supabase Auth 签发的 JWT，并配合数据库 RLS 做租户隔离。

### 核心特性

- ✅ **Harness Engineering 架构**：工具注册、权限策略、可观测性、Agent 循环统一管理
- ✅ **多租户 Workspace**：支持 Personal（个人）和 Enterprise（企业）工作空间，成员协作，权限分级
- ✅ **异步任务队列**：基于 PostgreSQL `SKIP LOCKED` 的分布式任务调度，支持图片生成、视频生成等长时任务
- ✅ **实时 WebSocket**：Agent 工具调用、流式对话、任务状态推送
- ✅ **进程隔离沙箱**：子进程池 + WASM 运行时，安全执行用户代码
- ✅ **OpenTelemetry 集成**：OTLP traces 导出，完整的可观测性支持
- ✅ **计费 Webhook**：支持 Stripe/Alipay/Paddle 多供应商事件处理
- ✅ **多语言支持**：简体中文、English

### 应用场景

- 🎬 网文/小说快速影视化改编
- 🏭 短剧团队流水线协作生产
- 🚀 多项目并行的 AI 内容工厂
- 🏢 企业团队订阅与多成员协作生产
- 🧪 低成本验证剧情与镜头方案

---

## 🏗️ 架构概览

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

```
Openflow-app/
├── backend/              # Rust 后端服务
│   ├── src/             # 源代码
│   ├── data/skills/     # 技能 Markdown
│   ├── Cargo.toml       # 依赖配置
│   └── README.md        # 后端文档
├── frontend/            # Flutter 前端应用
│   ├── lib/             # 源代码
│   ├── pubspec.yaml     # 依赖配置
│   └── README.md        # 前端文档
├── website/             # 产品介绍宣传页（静态 HTML，见 website/README.md）
├── supabase/            # 数据库迁移
│   └── migrations/      # SQL 迁移文件
├── docs/                # 文档
│   └── plans/           # 技术路线图
└── scripts/             # 工具脚本
```

详细说明：
- **`backend/`**：Rust 后端服务（Axum + SQLx + Tokio），默认端口 **8666**，详见 [`backend/README.md`](backend/README.md)
- **`frontend/`**：Flutter 客户端（桌面 + Web），通过 `API_BASE_URL` 连接后端，详见 [`frontend/README.md`](frontend/README.md)
- **`website/`**：产品介绍落地页（中/英）；与后端同启时访问 **http://127.0.0.1:8666/**（详见 [`website/README.md`](website/README.md)）
- **`docs/plans/`**：技术路线图与设计文档，主路线图：[`harness-rust-flutter.md`](docs/plans/harness-rust-flutter.md)
- **`supabase/`**：数据库迁移与配置，开发：`supabase start`（本地 Docker），生产：Supabase 云端托管

---

## 🌐 平台使用（终端用户）

1. **注册账号**：通过官方 Web 或桌面客户端完成注册（Supabase Auth）。
2. **登录平台**：获取会话与 JWT，未登录仅可访问登录/注册等公开页面。
3. **进入 Workspace**：创建或加入 Personal / Enterprise 工作空间，开始剧本、分镜与资产生成。
4. **订阅与计费**：按 Workspace 套餐与用量结算（Stripe / Alipay / Paddle 等，以环境配置为准）。

客户端安装包与生产环境地址由运营或商务提供，**不在此仓库公开发布**。

---

## 🚀 本地开发（授权团队成员）

> 本仓库为**专有软件**源码树，仅供经授权的内部研发与合作伙伴使用。克隆与部署须遵守 [LICENSE](./LICENSE)。

### 前置条件

| 工具 | 版本要求 | 用途 |
|------|---------|------|
| **Rust** | stable | 后端编译 |
| **Flutter** | 3.10+ | 前端开发 |
| **Supabase CLI** | latest | 本地数据库 |
| **Docker** | latest | Supabase 本地栈 |
| **Node.js** | 18+ | 工具脚本 |
| **Yarn** | 1.x | 包管理 |

### 安装步骤

#### 1. 安装 Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version
```

#### 2. 安装 Flutter

```bash
# macOS
brew install --cask flutter

# 验证安装
flutter doctor
```

#### 3. 安装 Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

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

### 启动开发环境

#### 1. 获取源码

由团队负责人授予 Git 访问权限后，从**内部/授权远程仓库**克隆（勿将源码上传至公开仓库或对外分发）：

```bash
git clone <your-authorized-remote-url>
cd Openflow-app   # 或你的本地目录名
```

#### 2. 启动数据库

```bash
# 启动 Supabase 本地栈（PostgreSQL + Auth）
supabase start

# 查看连接信息
supabase status
```

#### 3. 配置后端

```bash
cd backend
cp .env.example .env
# 编辑 .env 文件，填入 DATABASE_URL 和 SUPABASE_JWT_SECRET
```

#### 4. 启动后端服务

```bash
cd backend
cargo run --bin openflow-server
```

服务启动后监听 `http://127.0.0.1:8666`（根路径 `/` 为产品介绍页，`/api/v1/*` 为 API）

#### 5. 启动前端应用

```bash
cd frontend
flutter pub get

# Web 开发模式
flutter run -d chrome --dart-define-from-file=dart_defines.dev.json

# 或桌面模式
flutter run -d macos --dart-define-from-file=dart_defines.dev.json
```

### 验证安装

```bash
# 健康检查
curl http://127.0.0.1:8666/health

# API 文档
open http://127.0.0.1:8666/api/v1/docs

# 运行测试
yarn refactor:check
```

---

## 🛠️ 开发指南

### 后端开发

详见 [`backend/README.md`](backend/README.md)

**核心模块**：
- **Harness 核心**：工具注册、WebSocket 实现、进程隔离、WASM 运行时
- **异步任务队列**：图片生成、视频生成、提示词优化等任务类型
- **计费 Webhook**：Stripe/Alipay/Paddle 事件处理

**环境变量**：
- `DATABASE_URL`：PostgreSQL 连接串
- `SUPABASE_JWT_SECRET`：JWT 签名密钥
- `OPENAI_API_KEY` / `LLM_API_KEY`：LLM API 密钥
- `OPENFLOW_LOCAL_ASSET_IMAGE_DIR`：本地资产图片存储目录

**常用命令**：
```bash
cd backend
cargo fmt              # 代码格式化
cargo clippy           # Lint 检查
cargo test             # 单元测试
cargo build --release  # 发布构建
```

### 前端开发

详见 [`frontend/README.md`](frontend/README.md)

**运行模式**：
- **Harness 模式**：开发调试，包含所有探针和调试工具
- **Product 模式**：产品体验，完整的 UX（项目/剧本/分镜/资产管理）

**功能开关**：
- `ENABLE_WORKSPACE_BILLING`：启用 workspace 级别计费
- `OPENFLOW_INTERNAL_OPS_TOKEN`：访问内部运维接口

**常用命令**：
```bash
cd frontend
flutter analyze        # 静态分析
flutter test           # 单元测试
flutter build web      # Web 构建
flutter build macos    # macOS 桌面构建
flutter build linux    # Linux 桌面构建
flutter build windows  # Windows 桌面构建
```

**桌面发布产物**：
- macOS：`openflow_app.app`
- Linux：`bundle/openflow_app`（含同目录 `lib/` 下的 Rust bridge）
- Windows：`openflow_app.exe`（同目录携带 `openflow_core_bridge.dll`）

仓库内 GitHub Actions 已切到 Flutter desktop 发布链，并会为三个桌面平台分别产出可分发压缩包。

### CI 与工程规范

**本地重构门禁**：
```bash
yarn refactor:check
```

该脚本会执行：
1. OpenAPI 解析校验
2. Rust 检查（fmt + clippy + test）
3. Flutter 检查（analyze + test）

**数据库迁移**：
```bash
# 创建新迁移
supabase migration new your_migration_name

# 应用迁移
supabase db reset  # 本地开发
supabase db push   # 生产环境
```

**代码规范**：
- Rust：使用 `rustfmt` 格式化，遵循 Clippy 建议
- Flutter：使用 `flutter_lints` 规则集，遵循 Effective Dart 指南
- Git 提交：使用语义化提交信息（Conventional Commits）

---

## 📚 文档

- [后端开发指南](backend/README.md)
- [前端开发指南](frontend/README.md)
- [技术路线图](docs/plans/harness-rust-flutter.md)
- [功能对齐清单](docs/plans/electron-node-parity.md)
- [数据库迁移指南](docs/migration/database-migrations.md)
- [WebSocket 事件协议](docs/websocket-events.md)

---

> 💡 **提示**：当前主客户端在 **`frontend/`**（Flutter）。历史 Web 栈仅作内部参考，不对外开源。

---

## 💌 联系我们

📧 邮箱：[ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow咨询)

---

## 📜 许可与授权

OpenFlow 为**闭源专有软件**，**非开源**；完整条款见 **[LICENSE](./LICENSE)**。

摘要：

- **SaaS 使用**：注册登录后，在授权订阅范围内使用云端平台。
- **源码与制品**：不对外提供公开源码；客户端/服务端分发须商务授权。
- **再分发**：向 **≥2 个独立第三方** 提供本软件产品须书面商业授权；≤5 法人纯内部联合使用见 LICENSE。
- **商业定价**（年费摘要）：扶持期年收入不足 10 万可申请免费 → 初创 ¥5,000 → 成长 ¥2 万 → 规模 ¥8 万 → 企业面议。

📧 授权咨询：[ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow%E6%8E%88%E6%9D%83%E5%92%A8%E8%AF%A2)

---

## 🙏 第三方组件致谢

OpenFlow 产品本身为闭源，但构建时使用了以下**第三方开源**库（其许可独立于本产品）：

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

---

##### copyright © 淮北艾阿网络科技有限公司
