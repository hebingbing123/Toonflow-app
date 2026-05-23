# OpenFlow 文档中心

欢迎来到 OpenFlow 文档中心。本文档库覆盖技术架构、API 协议、运维手册、功能规格和产品设计。

## 🚀 快速开始

| 角色 | 入口 |
|------|------|
| **创作者 / 制片 / 运营** | [**OpenFlow 用户操作手册**](./product/user-manual.md)（Studio 六步全链路） |
| 开发者 | [开发者快速开始](./getting-started/for-developers.md) |
| 运维人员 | [运维人员快速开始](./getting-started/for-operators.md) |

## 📁 文档目录

### 🏗️ 架构

- [架构决策记录（ADR）](./architecture/adr/README.md) — 重要技术决策的背景与理由
- [后端领域层设计](./architecture/backend-domain-layer-review.md)
- [DDD 迁移方案](./architecture/ddd-full-migration-c.md)

### 🔌 API

- [WebSocket 事件协议](./api/websocket-events.md) — 实时通信事件定义

### ✨ 功能

- [全局搜索](./features/global-search.md)
- **Workspace**：[计费](./features/workspace/billing-scope.md) · [权限](./features/workspace/permissions.md) · [协作](./features/workspace/team-collaboration.md) · [可观测性](./features/workspace/observability.md)
- **短视频**：[用户指南](./features/short-video/user-guide.md) · [快捷键](./features/short-video/shortcuts.md) · [轻编辑规格](./features/short-video/light-editing-spec.md)
- **Harness**：[WS 上下文矩阵](./features/harness/ws-context-matrix.md)

### 🔧 运维

- [Runbooks 索引](./operations/runbooks/README.md) — 所有运维操作手册
- [监控与日志](./operations/monitoring-and-logging.md)
- [计费 Webhook 保留策略](./operations/billing-webhook-retention-policy.md)

### 🗺️ 路线图

- [主路线图](./roadmaps/master-roadmap.md) — 整体技术方向与里程碑
- [功能对齐审计](./roadmaps/parity-audit.md)
- [平台进度](./roadmaps/platform-progress.md)
- [路线图总索引](./roadmaps/index.md)

### 🔒 安全

- [Workspace 安全边界](./security/threat-models/workspace-security-boundary.md)
- [Harness WASM 威胁模型](./security/threat-models/harness-user-wasm.md)
- [Workspace 邀请安全审查](./security/workspace-invite-security-review.md)

### 📱 产品

- [**用户操作手册**](./product/user-manual.md) — Studio 六步：剧本 → 成片（创作者主文档）
- [深链接](./product/deep-links.md)
- **UX**：[竞品 UI 基准](./product/ux/competitive-ui-benchmark.md) · [设计 Token](./product/ux/design-tokens.md) · [交互约定](./product/ux/ix-covenant.md)
- **规格**：[AI 短剧质量](./product/specs/ai-drama-quality-token-memory.md) · [模型定价](./product/specs/model-pricing-prd.md) · [小说采集](./product/specs/novel-intake-crawler.md)

### ✅ 质量

- [质量评分标准](./quality/quality-rubric.md)
- [全栈交付约定](./quality/full-stack-delivery-covenant.md)

### 🔄 迁移

- [数据库迁移指南](./migration/database-migrations.md)
- [SQLite → Supabase](./migration/sqlite-to-supabase.md)
- [迁移历史策略](./migration/database-migration-history-policy.md)

### 📋 模板

- [ADR 模板](./templates/adr-template.md)
- [Runbook 模板](./templates/runbook-template.md)
- [技术规格模板](./templates/spec-template.md)

## 📝 贡献文档

参阅 [CONTRIBUTING.md](./CONTRIBUTING.md) 了解文档规范和提交流程。
