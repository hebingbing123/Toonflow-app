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
  <a href="../README.md">简体中文</a> |
  <strong>English</strong>
</p>

<div align="center">

# OpenFlow

  <p align="center">
    <b>
      AI Short Drama Factory
      <br />
      Intelligent Creation Platform Based on Harness Engineering
      <br />
      Rust + Flutter + PostgreSQL 🚀
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
  
  > 🚀 **Modern Tech Stack**: Rust backend + Flutter frontend + PostgreSQL database, complete AI creation workflow from text to video
</div>

---

## 📖 Project Overview

OpenFlow is an AI short drama production platform based on **Harness Engineering** architecture, using **Rust + Flutter + PostgreSQL** tech stack, providing a complete workflow from planning to finished product.

### Core Features

- ✅ **Harness Engineering Architecture**: Unified management of tool registration, permission policies, observability, and Agent loops
- ✅ **Multi-tenant Workspace**: Support for Personal and Enterprise workspaces, member collaboration, and permission grading
- ✅ **Async Task Queue**: Distributed task scheduling based on PostgreSQL `SKIP LOCKED`, supporting long-running tasks like image and video generation
- ✅ **Real-time WebSocket**: Agent tool invocation, streaming dialogue, task status push
- ✅ **Process Isolation Sandbox**: Subprocess pool + WASM runtime for secure user code execution
- ✅ **OpenTelemetry Integration**: OTLP traces export with complete observability support
- ✅ **Billing Webhook**: Multi-provider event handling for Stripe/Alipay/Paddle
- ✅ **Multilingual Support**: Simplified Chinese, Traditional Chinese, English, Thai, Vietnamese, Japanese, Russian

### Application Scenarios

- 🎬 Rapid film/TV adaptation of web novels
- 🏭 Short drama team pipeline collaborative production
- 🚀 Multi-project parallel AI content factory
- 🏢 Enterprise-level content platform for private deployment
- 🧪 Low-cost validation of plot and shot schemes
- 📚 AIGC creation experiments in teaching and research scenarios

---

## 🏗️ Architecture Overview

### Tech Stack

| Layer | Technology | Description |
|-------|------------|-------------|
| **Backend Service** | Rust + Axum + Tokio | Async HTTP/WebSocket API, default port **8666** |
| **Frontend App** | Flutter (Desktop + Web) | Cross-platform client, connects to backend via configurable `API_BASE_URL` |
| **Database** | PostgreSQL (Supabase) | Production: hosted; Development: local CLI (`supabase start`) |
| **Authentication** | Supabase Auth | JWT Bearer token with RLS row-level security |
| **Real-time Communication** | WebSocket (`/api/v1/ws`) | Harness protocol supporting Agent tool invocation and streaming dialogue |
| **API Contract** | OpenAPI 3.1 | Auto-generated docs, browser access at `/api/v1/docs` |

### Directory Structure

```
Toonflow-app/
├── backend/              # Rust backend service
│   ├── src/             # Source code
│   ├── data/skills/     # Skill Markdown files
│   ├── Cargo.toml       # Dependency config
│   └── README.md        # Backend docs
├── frontend/            # Flutter frontend app
│   ├── lib/             # Source code
│   ├── pubspec.yaml     # Dependency config
│   └── README.md        # Frontend docs
├── supabase/            # Database migrations
│   └── migrations/      # SQL migration files
├── docs/                # Documentation
│   └── plans/           # Technical roadmaps
└── scripts/             # Utility scripts
```

For detailed descriptions:
- **`backend/`**: Rust backend service (Axum + SQLx + Tokio), default port **8666**, see [`backend/README.md`](../backend/README.md)
- **`frontend/`**: Flutter client (Desktop + Web), connects to backend via `API_BASE_URL`, see [`frontend/README.md`](../frontend/README.md)
- **`docs/plans/`**: Technical roadmaps and design docs, main roadmap: [`harness-rust-flutter.md`](plans/harness-rust-flutter.md)
- **`supabase/`**: Database migrations and config, Development: `supabase start` (local Docker), Production: Supabase cloud hosting

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| **Rust** | stable | Backend compilation |
| **Flutter** | 3.10+ | Frontend development |
| **Supabase CLI** | latest | Local database |
| **Docker** | latest | Supabase local stack |
| **Node.js** | 18+ | Utility scripts |
| **Yarn** | 1.x | Package management |

### Installation Steps

#### 1. Install Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustc --version
```

#### 2. Install Flutter

```bash
# macOS
brew install --cask flutter

# Verify installation
flutter doctor
```

#### 3. Install Supabase CLI

```bash
# macOS
brew install supabase/tap/supabase

# Verify installation
supabase --version
```

#### 4. Install Node.js & Yarn

```bash
# macOS
brew install node yarn

# Verify installation
node --version
yarn --version
```

### Start Development Environment

#### 1. Clone Repository

```bash
git clone https://github.com/HBAI-Ltd/Toonflow-app.git
cd Toonflow-app
```

#### 2. Start Database

```bash
# Start Supabase local stack (PostgreSQL + Auth)
supabase start

# View connection info
supabase status
```

#### 3. Configure Backend

```bash
cd backend
cp .env.example .env
# Edit .env file, fill in DATABASE_URL and SUPABASE_JWT_SECRET
```

#### 4. Start Backend Service

```bash
cd backend
cargo run --bin toonflow-server
```

Service starts listening on `http://127.0.0.1:8666`

#### 5. Start Frontend App

```bash
cd frontend
flutter pub get

# Web development mode
flutter run -d chrome --dart-define-from-file=dart_defines.dev.json

# Or desktop mode
flutter run -d macos --dart-define-from-file=dart_defines.dev.json
```

### Verify Installation

```bash
# Health check
curl http://127.0.0.1:8666/health

# API documentation
open http://127.0.0.1:8666/api/v1/docs

# Run tests
yarn refactor:check
```

---

## 🛠️ Development Guide

### Backend Development

See [`backend/README.md`](../backend/README.md)

**Core Modules**:
- **Harness Core**: Tool registration, WebSocket implementation, process isolation, WASM runtime
- **Async Task Queue**: Task types for image generation, video generation, prompt optimization, etc.
- **Billing Webhook**: Stripe/Alipay/Paddle event handling

**Environment Variables**:
- `DATABASE_URL`: PostgreSQL connection string
- `SUPABASE_JWT_SECRET`: JWT signing key
- `OPENAI_API_KEY` / `LLM_API_KEY`: LLM API key
- `TOONFLOW_LOCAL_ASSET_IMAGE_DIR`: Local asset image storage directory

**Common Commands**:
```bash
cd backend
cargo fmt              # Code formatting
cargo clippy           # Lint check
cargo test             # Unit tests
cargo build --release  # Release build
```

### Frontend Development

See [`frontend/README.md`](../frontend/README.md)

**Run Modes**:
- **Harness Mode**: Development debugging with all probes and debug tools
- **Product Mode**: Product experience with complete UX (project/script/storyboard/asset management)

**Feature Flags**:
- `ENABLE_WORKSPACE_BILLING`: Enable workspace-level billing
- `OPENFLOW_INTERNAL_OPS_TOKEN`: Access internal ops interfaces

**Common Commands**:
```bash
cd frontend
flutter analyze        # Static analysis
flutter test           # Unit tests
flutter build web      # Web build
flutter build macos    # macOS build
```

### CI & Engineering Standards

**Local Refactor Gate**:
```bash
yarn refactor:check
```

This script executes:
1. OpenAPI parsing validation
2. Rust checks (fmt + clippy + test)
3. Flutter checks (analyze + test)

**Database Migrations**:
```bash
# Create new migration
supabase migration new your_migration_name

# Apply migrations
supabase db reset  # Local development
supabase db push   # Production
```

**Code Standards**:
- Rust: Use `rustfmt` for formatting, follow Clippy suggestions
- Flutter: Use `flutter_lints` ruleset, follow Effective Dart guidelines
- Git commits: Use semantic commit messages (Conventional Commits)

---

## 📚 Documentation

- [Backend Development Guide](../backend/README.md)
- [Frontend Development Guide](../frontend/README.md)
- [Technical Roadmap](plans/harness-rust-flutter.md)
- [Feature Parity Checklist](plans/electron-node-parity.md)
- [Database Migration Guide](migration/database-migrations.md)
- [WebSocket Event Protocol](websocket-events.md)

---

## 🔗 Related Repositories

| Repository | Description | Links |
|------------|-------------|-------|
| **Toonflow-app** | Main repository (this repo) | [GitHub](https://github.com/HBAI-Ltd/Toonflow-app) / [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-app) |
| **Toonflow-web** | Legacy Web frontend (historical reference) | [GitHub](https://github.com/HBAI-Ltd/Toonflow-web) / [Gitee](https://gitee.com/HBAI-Ltd/Toonflow-web) |

> 💡 **Tip**: Current main client is in **`frontend/`** (Flutter). **Toonflow-web** is a legacy stack reference repository.

---

## 💌 Contact Us

📧 Email: [ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow Inquiry)

---

## 📜 License

OpenFlow is released as open source under the Apache-2.0 license with supplementary commercial terms.

License details: https://www.apache.org/licenses/LICENSE-2.0

### Supplementary Terms

- If distributing this software as a product to **2 or more independent third parties**, written commercial authorization from HBAI-Ltd is required.
- **≤ 5 legal entities** jointly operating for internal use without external services is considered internal use and **requires no authorization**.
- Do not remove or modify OpenFlow identifiers or copyright information.

### Permanently Free Scenarios

- ✅ Create content with OpenFlow and earn platform revenue sharing
- ✅ Secondary development for your own team's internal use
- ✅ ≤ 5 legal entities jointly operating for internal use
- ✅ Personal learning, research, non-commercial use

### Commercial Authorization Pricing

| Stage | Annual Revenue | Annual Fee |
|-------|---------------|------------|
| 🌱 Support | < ¥100k | **Free upon application** |
| 🚀 Startup | ¥100k–500k | ¥5,000/year |
| 📈 Growth | ¥500k–1.5M | ¥20,000/year |
| 🏢 Scale | ¥1.5M–5M | ¥80,000/year |
| 🌐 Enterprise | > ¥5M | Negotiable |

Complete terms in [LICENSE](../LICENSE) file.

---

## ⭐️ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)](https://www.star-history.com/#HBAI-Ltd/Toonflow-app&type=timeline&legend=top-left)

---

## 🙏 Acknowledgments

Thanks to the following open source projects for supporting OpenFlow:

- [Rust](https://www.rust-lang.org/) / [Tokio](https://tokio.rs/) / [Axum](https://github.com/tokio-rs/axum)
- [Flutter](https://flutter.dev/)
- [Supabase](https://supabase.com/)
- [SQLx](https://github.com/launchbadge/sqlx)
- [PostgreSQL](https://www.postgresql.org/)

Thanks to the following organizations/units/individuals for supporting OpenFlow:

<table>
  <tr>
    <td>
      <b>Sophnet Cloud</b> provides computing power sponsorship
      <a href="https://www.sophnet.com/">[Website]</a>
    </td>
  </tr>
</table>

Complete third-party dependency list available in `NOTICES.txt`

---

##### copyright © Huaibei Ai'a Network Technology Co., Ltd.
