# Workspace 功能文档

本目录包含 OpenFlow Workspace（团队工作空间）功能的所有相关文档。

## 📋 功能概览

Workspace 是 OpenFlow 的多租户协作单元，支持团队成员共享项目、管理权限和统一计费。

## 📁 文档列表

### 核心功能

| 文档 | 说明 |
|------|------|
| [权限策略](./permissions.md) | 项目权限与角色定义 |
| [团队协作](./team-collaboration.md) | 团队成员管理与协作功能 |
| [可观测性规格](./observability.md) | Workspace 监控与可观测性 |
| [RLS 一致性矩阵](./rls-consistency-matrix.md) | Row Level Security 策略矩阵 |

### 计费

| 文档 | 说明 |
|------|------|
| [计费范围决策](./billing-scope.md) | 计费归属与范围的决策说明 |
| [计费功能标志](./billing-feature-flags.md) | 计费功能开关配置指南 |
| [计费未来规划](./billing-future-scope.md) | 计费功能扩展规划 |
| [计费 Job 创建审计](./billing-job-creation-audit.md) | Job 创建与计费关联审计 |

### 迁移与发版

| 文档 | 说明 |
|------|------|
| [迁移通知](./migration-notice.md) | Workspace 迁移说明 |
| [计费迁移通知](./billing-migration-notice.md) | 计费系统迁移说明 |
| [发版检查清单](./release-checklist.md) | Workspace 功能发版前检查项 |

### 回滚

| 文档 | 说明 |
|------|------|
| [计费回滚流程](./billing-rollback-procedures.md) | 计费功能回滚操作步骤 |
| [计费 Schema 回滚](./billing-schema-rollback.md) | 数据库 Schema 回滚方案 |
| [计费预发验证](./billing-staging-validation.md) | 预发环境验证检查清单 |

## 🔗 相关文档

- [Workspace 运维手册](../../operations/runbooks/workspace-operations.md)
- [Workspace 邀请安全审查](../../security/workspace-invite-security-review.md)
- [Workspace 安全边界](../../security/threat-models/workspace-security-boundary.md)
- [计费 Webhook 保留策略](../../operations/billing-webhook-retention-policy.md)
