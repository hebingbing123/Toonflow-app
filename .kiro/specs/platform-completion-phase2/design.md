# Design Document: Platform Completion Phase 2

## Overview

本设计文档定义 Toonflow 平台 Phase 2 完成工作的技术实现方案,目标是完成平台剩余关键能力,包括:

1. **Workspace 功能完善** - 统一项目路径权限校验、Jobs 可见性、Scope 标注、角色矩阵测试、RLS 一致性验证
2. **HTTP API 收敛** - 完成 C4+ 和 D 批次的遗留 API 清理
3. **全局搜索服务端保存视图** - 实现跨设备同步的搜索视图持久化
4. **出站 Webhook** - 完整的事件通知机制(含重试、签名、死信队列)
5. **内容合规分阶段通知** - 按升级阶段生成告警并推送到通知中心
6. **i18n 中英收口** - 主路径界面和错误消息的国际化
7. **帮助文档 Hub** - 应用内帮助中心完善
8. **全栈交付约定遵守** - 确保所有功能遵循 backend + frontend + OpenAPI 同步交付
9. **Personal Workspace 保护** - 确保升级不影响现有用户
10. **Parity 文档补充** - 说明多用户可见范围差异

本设计遵循 [`full-stack-delivery-covenant.md`](../../../docs/plans/full-stack-delivery-covenant.md) 约定,所有用户可见功能必须在同一里程碑交付 backend + frontend + OpenAPI 文档。

**与当前代码真源对齐（相对初版需求措辞）**

- **全局搜索保存视图**：`GET`/`PUT /api/v1/search/saved-views`，表 `app_user_search_saved_view`；详见 `tasks.md` 顶部说明与 [`gap-tasks-automation.md`](./gap-tasks-automation.md)。
- **帮助 Hub**：`/api/v1/settings/help/hub` 族端点，环境变量 `TOONFLOW_HELP_HUB_ITEMS_JSON` / `TOONFLOW_HELP_HUB_URL`；非 `help-links`。
- **Webhook**：**用户出站**（`app_outbound_webhook` / `settings/webhooks/outbound` 与 `/api/v1/webhooks` 别名）与 **Stripe 计费入站** `POST /api/v1/webhooks/billing` 是两条线；出站已实现配置、签名、投递历史、**指数退避重试**及部分平台事件（`job.completed` / `job.failed` / `project.created` / `workspace.member.added` 等，见 `tasks.md` WH1–WH3）。
- **Workspace 安全**：应用层授权真源与 RLS 护栏分工见 `docs/plans/workspace-security-boundary.md`；矩阵见 `docs/plans/workspace-rls-consistency-matrix.md`。

### 技术栈

- **Backend**: Rust (Axum framework, SQLx for PostgreSQL)
- **Frontend**: Flutter (Dart)
- **Database**: PostgreSQL (Supabase)
- **API**: REST (OpenAPI 3.0) + WebSocket
- **Testing**: Rust `cargo test`, Flutter `flutter test`, Property-based testing (proptest)

### 架构原则

1. **全栈同步交付** - 用户可见功能必须 backend + frontend + OpenAPI 同时完成
2. **向后兼容** - 保护 personal workspace 和单用户路径
3. **权限一致性** - RLS 策略与 Rust 应用层权限校验保持一致
4. **可观测性** - 所有功能提供审计日志和错误码
5. **门禁验证** - 所有变更通过 `yarn refactor:check`

## Architecture

### 系统架构图

```mermaid
graph TB
    subgraph "Frontend (Flutter)"
        UI[UI Components]
        RustAPI[rust_api Client]
        WS[WebSocket Client]
    end
    
    subgraph "Backend (Rust/Axum)"
        HTTP[HTTP Handlers]
        WS_Handler[WebSocket Handler]
        Auth[Auth Middleware]
        Workspace[Workspace Service]
        Search[Search Service]
        Webhook[Webhook Service]
        Compliance[Compliance Service]
        I18n[I18n Service]
    end
    
    subgraph "Database (PostgreSQL/Supabase)"
        Tables[(Tables)]
        RLS[RLS Policies]
        Migrations[Migrations]
    end
    
    subgraph "External Services"
        SMTP[Email Service]
        Webhook_Target[Webhook Targets]
    end
    
    UI --> RustAPI
    UI --> WS
    RustAPI --> HTTP
    WS --> WS_Handler
    HTTP --> Auth
    Auth --> Workspace
    Auth --> Search
    Auth --> Webhook
    Auth --> Compliance
    HTTP --> Tables
    WS_Handler --> Tables
    Tables --> RLS
    Webhook --> Webhook_Target
    Compliance --> SMTP
