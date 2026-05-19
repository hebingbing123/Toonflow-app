---
title: 运维人员快速开始
status: active
created: 2026-05-19
updated: 2026-05-19
tags:
  - getting-started
  - operations
---

# 运维人员快速开始指南

欢迎加入 OpenFlow 运维团队！本指南将帮助你快速了解系统运维相关的关键信息。

## 📋 系统概览

### 架构简介

OpenFlow 是一个基于 Rust 后端和 Flutter 前端的 SaaS 平台：

- **后端**：Rust + Actix-web + PostgreSQL
- **前端**：Flutter Web
- **数据库**：Supabase (PostgreSQL)
- **部署**：Cloudflare Workers (计划中)
- **监控**：[待补充]

### 核心组件

```
┌─────────────┐
│   用户      │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Flutter    │
│  Frontend   │
└──────┬──────┘
       │
       ▼
┌─────────────┐      ┌─────────────┐
│   Rust      │─────▶│  Supabase   │
│   Backend   │      │  PostgreSQL │
└─────────────┘      └─────────────┘
       │
       ▼
┌─────────────┐
│  External   │
│  Services   │
└─────────────┘
```

## 🔑 访问权限

### 必需权限

- [ ] GitHub 仓库访问权限
- [ ] Supabase 项目访问权限
- [ ] 生产环境服务器访问权限
- [ ] 监控系统访问权限
- [ ] 日志系统访问权限

### 获取权限

联系以下人员获取相应权限：

- **GitHub**: @team-lead
- **Supabase**: @database-admin
- **生产环境**: @devops-lead

## 📚 核心文档

### 运维手册 (Runbooks)

所有运维手册位于 [operations/runbooks/](../operations/runbooks/README.md)：

**数据库相关**：
- [任务队列运维](../operations/runbooks/jobs-pg-queue.md)
- [数据库迁移](../migration/database-migrations.md)

**Workspace 相关**：
- [Workspace 运维操作](../operations/runbooks/workspace-operations.md)
- [Workspace 邀请处理](../operations/runbooks/workspace-invite.md)
- [Workspace RLS 验证](../operations/runbooks/workspace-rls-validation.md)
- [Workspace 敏感操作](../operations/runbooks/workspace-sensitive-operations.md)

**计费相关**：
- [计费对账](../operations/runbooks/billing-reconciliation.md)
- [计费 Webhook PII](../operations/runbooks/billing-webhook-pii.md)
- [计费切换](../operations/runbooks/workspace-billing-cutover.md)
- [计费回滚](../operations/runbooks/workspace-billing-rollback.md)

**其他**：
- [Harness WASM 告警](../operations/runbooks/harness-wasm-alert.md)
- [S3 导出](../operations/runbooks/export-s3-artifacts.md)
- [短视频优化冒烟测试](../operations/runbooks/short-video-optimization-smoke.md)
- [UI E2E 测试](../operations/runbooks/ui-e2e.md)
- [Job Workspace ID 回填](../operations/runbooks/backfill-job-workspace-id.md)

### 安全文档

- [Workspace 安全边界](../security/threat-models/workspace-security-boundary.md)
- [Harness WASM 威胁模型](../security/threat-models/harness-user-wasm.md)
- [Workspace 邀请安全审查](../security/workspace-invite-security-review.md)

### 监控与日志

- [监控和日志系统](../operations/monitoring-and-logging.md)
- [计费 Webhook 保留策略](../operations/billing-webhook-retention-policy.md)

## 🚨 紧急响应

### 告警级别

| 级别 | 响应时间 | 说明 |
|------|---------|------|
| 🔴 P0 - 紧急 | 15 分钟 | 系统完全不可用 |
| 🟠 P1 - 高 | 1 小时 | 核心功能受影响 |
| 🟡 P2 - 中 | 4 小时 | 部分功能受影响 |
| 🟢 P3 - 低 | 1 天 | 轻微问题 |

### 紧急联系人

| 角色 | 联系方式 | 负责范围 |
|------|---------|---------|
| On-call 工程师 | [电话/Slack] | 第一响应 |
| 后端负责人 | [电话/Slack] | 后端问题 |
| 前端负责人 | [电话/Slack] | 前端问题 |
| 数据库管理员 | [电话/Slack] | 数据库问题 |
| 安全负责人 | [电话/Slack] | 安全事件 |

### 常见紧急情况

#### 1. 系统宕机

**症状**：用户无法访问系统

**快速诊断**：
```bash
# 检查后端服务状态
curl https://api.openflow.com/health

# 检查数据库连接
psql -h [host] -U [user] -d openflow -c "SELECT 1;"
```

**处理步骤**：
1. 查看 [相关 Runbook](../operations/runbooks/README.md)
2. 检查监控系统
3. 查看日志
4. 根据情况升级

#### 2. 数据库性能问题

**症状**：查询缓慢，超时

**快速诊断**：
```sql
-- 查看慢查询
SELECT * FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

-- 查看活动连接
SELECT * FROM pg_stat_activity 
WHERE state = 'active';
```

**处理步骤**：
1. 参考 [任务队列 Runbook](../operations/runbooks/jobs-pg-queue.md)
2. 检查是否有长时间运行的查询
3. 考虑终止问题查询
4. 分析并优化

#### 3. 计费问题

**症状**：用户报告计费异常

**处理步骤**：
1. 参考 [计费对账 Runbook](../operations/runbooks/billing-reconciliation.md)
2. 检查计费 Webhook 日志
3. 验证数据一致性
4. 必要时联系计费系统负责人

## 🔧 日常运维任务

### 每日检查

- [ ] 检查系统监控面板
- [ ] 查看告警通知
- [ ] 检查关键服务状态
- [ ] 查看错误日志
- [ ] 检查数据库性能指标

### 每周任务

- [ ] 审查上周的事件和告警
- [ ] 检查数据库备份
- [ ] 更新运维文档
- [ ] 审查系统资源使用情况
- [ ] 计划维护窗口

### 每月任务

- [ ] 审查和更新 Runbooks
- [ ] 进行灾难恢复演练
- [ ] 审查安全日志
- [ ] 优化系统性能
- [ ] 更新监控和告警规则

## 📊 监控与指标

### 关键指标

**系统健康**：
- API 响应时间 (P50, P95, P99)
- 错误率
- 请求量 (QPS)
- 系统可用性 (SLA)

**数据库**：
- 连接数
- 查询延迟
- 慢查询数量
- 数据库大小

**业务指标**：
- 活跃用户数
- 任务创建/完成数
- Workspace 数量
- 计费事件数

### 监控工具

- **系统监控**: [待补充]
- **日志聚合**: [待补充]
- **告警系统**: [待补充]
- **性能分析**: [待补充]

## 🔐 安全最佳实践

### 访问控制

- 使用最小权限原则
- 定期审查访问权限
- 使用 MFA (多因素认证)
- 不在日志中记录敏感信息

### 数据保护

- 定期备份数据库
- 加密敏感数据
- 遵循 [PII 处理规范](../operations/runbooks/billing-webhook-pii.md)
- 定期进行安全审计

### 操作规范

- 所有生产操作必须有 Runbook
- 高风险操作需要双人确认
- 记录所有重要操作
- 使用版本控制管理配置

## 🛠️ 常用工具和命令

### 数据库操作

```bash
# 连接数据库
psql -h [host] -U [user] -d openflow

# 查看表大小
SELECT 
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

# 查看索引使用情况
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

### 日志查看

```bash
# 查看后端日志
tail -f /var/log/openflow/backend.log

# 搜索错误
grep -i error /var/log/openflow/backend.log | tail -100

# 查看特定时间段的日志
journalctl -u openflow-backend --since "2026-05-19 10:00" --until "2026-05-19 11:00"
```

### 服务管理

```bash
# 检查服务状态
systemctl status openflow-backend

# 重启服务
systemctl restart openflow-backend

# 查看服务日志
journalctl -u openflow-backend -f
```

## 📖 学习资源

### 内部文档

- [架构文档](../architecture/adr/README.md)
- [API 文档](../api/websocket-events.md)
- [功能文档](../features/)
- [质量标准](../quality/quality-rubric.md)

### 外部资源

- [PostgreSQL 文档](https://www.postgresql.org/docs/)
- [Supabase 文档](https://supabase.com/docs)
- [Rust 文档](https://doc.rust-lang.org/)
- [SRE Book](https://sre.google/books/)

## 🤝 获取帮助

### 文档

- 首先查看相关 [Runbook](../operations/runbooks/README.md)
- 搜索 [文档总索引](../README.md)
- 查看 [安全文档](../security/)

### 团队沟通

- **Slack**: #ops-team 频道
- **紧急情况**: 使用 on-call 系统
- **非紧急问题**: 创建 GitHub Issue

### 升级路径

1. 查看 Runbook
2. 联系 on-call 工程师
3. 升级到相关负责人
4. 必要时召集紧急会议

## 🎯 入职检查清单

- [ ] 获取所有必需的访问权限
- [ ] 阅读所有核心 Runbooks
- [ ] 了解监控和告警系统
- [ ] 熟悉紧急响应流程
- [ ] 加入相关 Slack 频道
- [ ] 设置开发环境
- [ ] 完成一次模拟演练
- [ ] 与团队成员见面

## 🚀 下一步

- [ ] 阅读所有 [Runbooks](../operations/runbooks/README.md)
- [ ] 熟悉监控系统
- [ ] 了解系统架构
- [ ] 参与一次 on-call 轮值
- [ ] 更新或创建新的 Runbook

---

**欢迎加入 OpenFlow 运维团队！** 🔧

如有问题，随时在 Slack #ops-team 频道联系团队。
