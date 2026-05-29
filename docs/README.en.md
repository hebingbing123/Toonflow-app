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
      Proprietary Cloud SaaS · Sign in required
    </b>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/Product-Proprietary%20SaaS-7C97FF?style=for-the-badge" alt="Proprietary SaaS" />
    <img src="https://img.shields.io/badge/Access-Registration%20required-34C8F0?style=for-the-badge" alt="Registration required" />
    <img src="https://img.shields.io/badge/Stack-Rust%20%2B%20Flutter%20%2B%20PostgreSQL-1a1a2e?style=for-the-badge" alt="Tech stack" />
  </p>
  
  > 🚀 **Modern Tech Stack**: Rust backend + Flutter frontend + PostgreSQL database, complete AI creation workflow from text to video  
  > 🔒 **Not open source**: No public source or self-hosted OSS distribution; clients and integration docs are provided under commercial license.
</div>

---

## 📖 Project Overview

OpenFlow is a **proprietary cloud SaaS** AI short drama production platform based on **Harness Engineering**, using **Rust + Flutter + PostgreSQL**. Users must **register and sign in** before accessing Workspace creation features. Protected APIs require Supabase Auth JWTs with database RLS for tenant isolation.

### Core Features

- ✅ **Harness Engineering Architecture**: Unified management of tool registration, permission policies, observability, and Agent loops
- ✅ **Multi-tenant Workspace**: Support for Personal and Enterprise workspaces, member collaboration, and permission grading
- ✅ **Async Task Queue**: Distributed task scheduling based on PostgreSQL `SKIP LOCKED`, supporting long-running tasks like image and video generation
- ✅ **Real-time WebSocket**: Agent tool invocation, streaming dialogue, task status push
- ✅ **Process Isolation Sandbox**: Subprocess pool + WASM runtime for secure user code execution
- ✅ **OpenTelemetry Integration**: OTLP traces export with complete observability support
- ✅ **Billing Webhook**: Multi-provider event handling for Stripe/Alipay/Paddle
- ✅ **Multilingual Support**: Simplified Chinese, English

### Application Scenarios

- 🎬 Rapid film/TV adaptation of web novels
- 🏭 Short drama team pipeline collaborative production
- 🚀 Multi-project parallel AI content factory
- 🏢 Enterprise team subscriptions and multi-member collaboration
- 🧪 Low-cost validation of plot and shot schemes

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
├── backend/                 # Rust server (openflow-server, :8666)
├── frontend/                # Flutter Studio shell + Harness
│   └── lib/
│       ├── design_system/   # Studio design system
│       ├── product_shell/   # Router, sidebar, login
│       ├── short_video_space/
│       ├── project_studio/
│       └── rust_api/        # OpenAPI-aligned Dart API
├── rust_core/               # Desktop native bridge
├── supabase/migrations/
├── docs/roadmaps/           # Technical roadmaps (start here)
├── docs/plans/              # UI/UX, E2E, signoff
└── scripts/                 # Gates and E2E
```

For detailed descriptions:
- **`backend/`**: See [`backend/README.md`](../backend/README.md)
- **`frontend/`**: Default entry `lib/main.dart` → `StudioProductApp`; see [`frontend/README.md`](../frontend/README.md)
- **`docs/roadmaps/`**: Main index [`README.md`](roadmaps/README.md); blueprint [`master-roadmap.md`](roadmaps/master-roadmap.md)
- **`supabase/`**: `supabase start` locally; hosted in production

---

## 🌐 Using the Platform (End Users)

1. **Register** via the official Web or desktop client (Supabase Auth).
2. **Sign in** to obtain a session and JWT; unauthenticated users only see public pages such as login/register.
3. **Enter a Workspace** (Personal or Enterprise) to create scripts, storyboards, and assets.
4. **Subscription & billing** per Workspace plan and usage (Stripe / Alipay / Paddle, depending on deployment).

Installers and production URLs are provided by operations or sales—not published from this repository.

---

## 🚀 Local Development (Authorized Team Members)

> This repository is **proprietary** source code for authorized internal development and partners only. See [LICENSE](../LICENSE).

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

#### 1. Obtain Source Code

After your lead grants Git access, clone from your **authorized remote** (do not publish source to public repositories):

```bash
git clone <your-authorized-remote-url>
cd Openflow-app
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
cargo run --bin openflow-server
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
curl http://127.0.0.1:8666/api/v1/health
open http://127.0.0.1:8666/api/v1/docs

# Engineering gate (prefer agent entry)
yarn refactor:agent              # incremental (default)
yarn refactor:agent --quick      # pre-commit
yarn refactor:agent --full       # CI parity
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
- `OPENFLOW_LOCAL_ASSET_IMAGE_DIR`: Local asset image storage directory

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

**Refactor gate** (see [`scripts/REFACTOR_CHECK_MODES.md`](../scripts/REFACTOR_CHECK_MODES.md)):

```bash
yarn refactor:agent              # daily default
yarn refactor:agent --quick
yarn refactor:agent --full       # before merge / release
```

`yarn refactor:check` remains the full CI-equivalent entry when needed.

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

- [Backend](../backend/README.md) · [Frontend](../frontend/README.md)
- [Roadmaps index](roadmaps/README.md) · [Master roadmap](roadmaps/master-roadmap.md)
- [Parity audit](roadmaps/parity-audit.md)
- [Studio UI developer guide](plans/flutter-ui-ux-developer-guide.md)
- [Short-video UI delivery](plans/short-video-ui-ux-rebuild.md)
- [WebSocket events](api/websocket-events.md) (alias: [websocket-events.md](websocket-events.md))
- [Database migrations](migration/database-migrations.md)
- [Agent conventions](../AGENTS.md)

---

> 💡 **Tip**: The main client lives in **`frontend/`** (Flutter). Legacy Web stack references are internal only—not open source.

---

## 💌 Contact Us

📧 Email: [ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow Inquiry)

---

## 📜 License & Authorization

OpenFlow is **proprietary, closed-source software**—**not open source**. Full terms: **[LICENSE](../LICENSE)**.

Summary:

- **SaaS use**: Register and sign in; use the hosted platform within your subscription.
- **Source & artifacts**: No public source release; client/server distribution requires commercial authorization.
- **Redistribution**: Providing the product to **≥2 independent third parties** requires written license; ≤5 legal entities internal joint use—see LICENSE.
- **Pricing** (annual, summary): support tier under ¥100k may apply free → startup ¥5,000 → growth ¥20k → scale ¥80k → enterprise negotiable.

📧 Licensing: [ltlctools@outlook.com](mailto:ltlctools@outlook.com?subject=OpenFlow%20Licensing)

---

## 🙏 Third-Party Open Source Components

The OpenFlow **product** is proprietary, but it is built with these **third-party open source** libraries (each under its own license):

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
