# 技术路线图与设计文档

本目录存放 OpenFlow 的架构设计、技术路线图、ADR（Architecture Decision Records）和运维手册。

## 📋 文档分类

### 🎯 核心路线图

| 文档 | 说明 | 状态 |
|------|------|------|
| [`harness-rust-flutter.md`](./harness-rust-flutter.md) | **主路线图**（→ [`../roadmaps/master-roadmap.md`](../roadmaps/master-roadmap.md)） | ✅ 已完成 |
| [`electron-node-parity.md`](./electron-node-parity.md) | 旧 Electron/Node 与 Rust 后端对照（→ [`../roadmaps/parity-audit.md`](../roadmaps/parity-audit.md)） | ✅ 已完成 |
| [`master-detailed-parity-audit.md`](./master-detailed-parity-audit.md) | 基于 `master` 的详细补漏审计 | ✅ 已完成 |
| [`roadmap-index.md`](./roadmap-index.md) | 路线图总索引（按方向拆分） | 📚 参考 |

### 🏗️ 分方向路线图

| 文档 | 说明 |
|------|------|
| [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) | 后端 Harness 核心实现 |
| [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) | Flutter 前端壳与产品 UX |
| [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) | 异步任务队列与 SaaS 计费 |
| [`roadmap-parity-shipping.md`](./roadmap-parity-shipping.md) | 功能对齐与上线门禁 |
| [`roadmap-quality.md`](./roadmap-quality.md) | 质量评审与回归测试 |
| [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) | 仓库、契约与基础设施 |
| [`roadmap-workspace.md`](./roadmap-workspace.md) | 多租户 Workspace 实现 |

### 📐 架构决策记录（ADR）

| 文档 | 说明 |
|------|------|
| [`adr-me-api-version-negotiation.md`](./adr-me-api-version-negotiation.md) | `/api/v1/me` API 版本协商 |
| [`adr-workspace-billing-attribution.md`](./adr-workspace-billing-attribution.md) | Workspace 计费归属决策 |
| [`adr-workspace-billing-storage-model.md`](./adr-workspace-billing-storage-model.md) | Workspace 计费存储模型 |

### 🔐 安全与威胁模型

| 文档 | 说明 |
|------|------|
| [`harness-user-wasm-threat-model.md`](./harness-user-wasm-threat-model.md) | 用户 WASM 上传威胁模型 |
| [`workspace-security-boundary.md`](./workspace-security-boundary.md) | Workspace 安全边界 |
| [`workspace-invite-security-review.md`](./workspace-invite-security-review.md) | Workspace 邀请安全审查 |

### 📊 运维手册（Runbooks）

| 文档 | 说明 |
|------|------|
| [`jobs-pg-queue-runbook.md`](./jobs-pg-queue-runbook.md) | PostgreSQL 任务队列运维 |
| [`harness-wasm-alert-runbook.md`](./harness-wasm-alert-runbook.md) | Harness WASM 告警排障 |
| [`billing-reconciliation-guide.md`](./billing-reconciliation-guide.md) | 计费对账指南 |
| [`billing-webhook-pii-runbook.md`](./billing-webhook-pii-runbook.md) | 计费 Webhook PII 处理 |
| [`workspace-operations-runbook.md`](./workspace-operations-runbook.md) | Workspace 运维操作 |
| [`workspace-invite-runbook.md`](./workspace-invite-runbook.md) | Workspace 邀请运维 |
| [`workspace-sensitive-operations-runbook.md`](./workspace-sensitive-operations-runbook.md) | Workspace 敏感操作 |
| [`workspace-rls-validation-runbook.md`](./workspace-rls-validation-runbook.md) | Workspace RLS 验证 |

### 💰 计费与 Workspace

| 文档 | 说明 |
|------|------|
| [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) | Workspace 团队协作完整计划 |
| [`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md) | Workspace 计费范围决策 |
| [`workspace-billing-feature-flag-guide.md`](./workspace-billing-feature-flag-guide.md) | Workspace 计费功能开关指南 |
| [`workspace-billing-cutover-runbook.md`](./workspace-billing-cutover-runbook.md) | Workspace 计费切换手册 |
| [`workspace-billing-rollback-runbook.md`](./workspace-billing-rollback-runbook.md) | Workspace 计费回滚手册 |
| [`workspace-billing-migration-notice.md`](./workspace-billing-migration-notice.md) | Workspace 计费迁移通知 |
| [`workspace-migration-notice.md`](./workspace-migration-notice.md) | Workspace 迁移通知 |
| [`workspace-release-checklist.md`](./workspace-release-checklist.md) | Workspace 发布检查清单 |

### 🎨 产品与 UX

| 文档 | 说明 |
|------|------|
| [`short-video-light-editing-spec.md`](./short-video-light-editing-spec.md) | 短视频轻量编辑规格 |
| [`moneyprinter-short-video-space.md`](./moneyprinter-short-video-space.md) | MoneyPrinter 短视频空间 |
| [`studio-competitive-ui-benchmark.md`](./studio-competitive-ui-benchmark.md) | Studio 竞品 UI 基准 |
| [`studio-design-tokens.md`](./studio-design-tokens.md) | Studio 设计令牌 |
| [`studio-ix-covenant.md`](./studio-ix-covenant.md) | Studio 交互约定 |

### 🔧 技术专项

| 文档 | 说明 |
|------|------|
| [`ai-drama-quality-token-memory-spec.md`](./ai-drama-quality-token-memory-spec.md) | AI 短剧质量、Token 优化与记忆治理 |
| [`http-api-cleanup.md`](./http-api-cleanup.md) | HTTP API 收敛与旧路由下线 |
| [`tasks-http-api-cleanup.md`](./tasks-http-api-cleanup.md) | 任务 HTTP API 清理 |
| [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md) | 任务队列可观测性 |
| [`database-migration-history-policy.md`](./database-migration-history-policy.md) | 数据库迁移历史策略 |
| [`backend-domain-layer-review.md`](./backend-domain-layer-review.md) | 后端领域层审查 |
| [`ddd-full-migration-c.md`](./ddd-full-migration-c.md) | DDD 完整迁移 C 阶段 |

### 📈 质量与平台

| 文档 | 说明 |
|------|------|
| [`quality-rubric.md`](./quality-rubric.md) | 质量评分标准 |
| [`platform-capabilities-backlog.md`](./platform-capabilities-backlog.md) | 平台能力待办清单 |
| [`platform-config-plan-overrides.md`](./platform-config-plan-overrides.md) | 平台配置计划覆盖 |
| [`openflow-platform-progress.md`](./openflow-platform-progress.md) | Openflow 平台进度 |
| [`full-stack-delivery-covenant.md`](./full-stack-delivery-covenant.md) | 全栈交付约定 |

### 🔄 其他专项

| 文档 | 说明 |
|------|------|
| [`novel-intake-crawler-plan.md`](./novel-intake-crawler-plan.md) | 小说导入爬虫计划 |
| [`model-pricing-prd.md`](./model-pricing-prd.md) | 模型定价 PRD |
| [`assets-generate-job-payload-v2.md`](./assets-generate-job-payload-v2.md) | 资产生成任务 Payload V2 |
| [`harness-ws-context-matrix.md`](./harness-ws-context-matrix.md) | Harness WebSocket 上下文矩阵 |
| [`workspace-project-permission-policy.md`](./workspace-project-permission-policy.md) | Workspace 项目权限策略 |
| [`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md) | Workspace RLS 一致性矩阵 |
| [`workspace-observability-spec.md`](./workspace-observability-spec.md) | Workspace 可观测性规格 |
| [`billing-webhook-retention-policy.md`](./billing-webhook-retention-policy.md) | 计费 Webhook 保留策略 |

## 📖 阅读指南

### 新开发者入门

1. 先读 **[`harness-rust-flutter.md`](./harness-rust-flutter.md)** 了解整体架构和技术选型
2. 再读 **[`electron-node-parity.md`](./electron-node-parity.md)** 了解功能对齐情况
3. 根据兴趣方向选择对应的分路线图

### 运维人员

1. 先读 **[`jobs-pg-queue-runbook.md`](./jobs-pg-queue-runbook.md)** 了解任务队列运维
2. 再读 **[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)** 了解 Workspace 运维
3. 根据具体问题查阅对应的 Runbook

### 产品经理

1. 先读 **[`harness-rust-flutter.md`](./harness-rust-flutter.md)** 了解技术能力边界
2. 再读 **[`short-video-light-editing-spec.md`](./short-video-light-editing-spec.md)** 了解产品规格
3. 查阅 **[`studio-*`](./studio-competitive-ui-benchmark.md)** 系列文档了解 UX 设计

## 🔄 文档维护

- 所有路线图文档应保持与代码实现同步
- ADR 一旦确定不应修改，新决策应创建新的 ADR
- Runbook 应定期更新，确保操作步骤准确
- 已完成的路线图应标记状态并归档

## 📝 文档规范

- 使用 Markdown 格式
- 文件名使用小写字母和连字符
- 包含清晰的标题和目录
- 代码示例使用语法高亮
- 包含更新日期和作者信息（可选）
