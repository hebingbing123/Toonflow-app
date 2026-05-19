# 运维手册（Runbooks）

本目录包含 OpenFlow 平台的运维操作手册。

## 📋 手册列表

### 任务队列
- [PostgreSQL 任务队列运维](./jobs-pg-queue.md)

### Harness 系统
- [Harness WASM 告警排障](./harness-wasm-alert.md)

### Workspace 运维
- [Workspace 运维操作](./workspace-operations.md)
- [Workspace 邀请运维](./workspace-invite.md)
- [Workspace RLS 验证](./workspace-rls-validation.md)
- [Workspace 敏感操作](./workspace-sensitive-operations.md)

### 计费系统
- [计费对账指南](./billing-reconciliation.md)
- [计费 Webhook PII 处理](./billing-webhook-pii.md)
- [Workspace 计费切换](./workspace-billing-cutover.md)
- [Workspace 计费回滚](./workspace-billing-rollback.md)

### 数据维护
- [Job Workspace ID 回填](./backfill-job-workspace-id.md)
- [S3 制品导出](./export-s3-artifacts.md)

### 性能优化
- [短视频优化烟测](./short-video-optimization-smoke.md)

### 测试
- [UI E2E 测试 Runbook](./ui-e2e.md)

## 📖 使用指南

每个 Runbook 包含：
- **问题描述**：什么情况下使用此手册
- **前置条件**：需要的权限和工具
- **操作步骤**：详细的执行步骤
- **验证方法**：如何确认操作成功
- **回滚方案**：出错时如何恢复
- **常见问题**：FAQ 和故障排查

