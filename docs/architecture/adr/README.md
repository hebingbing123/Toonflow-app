# 架构决策记录（ADR）

本目录包含 OpenFlow 项目的架构决策记录（Architecture Decision Records）。

## 什么是 ADR？

ADR 是记录重要架构决策的文档，包括：
- 决策的背景和上下文
- 考虑的备选方案
- 最终决策及其理由
- 决策的后果和影响

## 📋 决策列表

| 编号 | 标题 | 状态 | 日期 |
|------|------|------|------|
| 001 | [/api/v1/me API 版本协商](./001-me-api-version-negotiation.md) | ✅ 已采纳 | 2025-Q4 |
| 002 | [Workspace 计费归属决策](./002-workspace-billing-attribution.md) | ✅ 已采纳 | 2025-Q4 |
| 003 | [Workspace 计费存储模型](./003-workspace-billing-storage-model.md) | ✅ 已采纳 | 2025-Q4 |
| 004 | [Rust 后端 Cloudflare Worker](./004-rust-backend-cloudflare-worker.md) | 🚧 评估中 | 2026-Q1 |

## 📝 ADR 模板

创建新的 ADR 时，请使用 [ADR 模板](../../templates/adr-template.md)。

## 🔄 ADR 状态

- 🚧 **草稿**：正在编写中
- 👀 **评审中**：等待团队审核
- ✅ **已采纳**：决策已被采纳并实施
- ⚠️ **已废弃**：决策已被新的 ADR 替代
- ❌ **已拒绝**：决策未被采纳

