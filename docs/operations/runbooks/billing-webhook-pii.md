# 计费 Webhook 与 PII 运行手册

本文档对应 `.kiro/specs/workspace-scope-billing/pii-hygiene-audit.md` 中 **Retention / DB 访问控制 / 运维处理** 的收口说明；实现以当前仓库迁移与后端路径为准。

## 1. 数据与风险面

- 表 **`public.app_billing_webhook_event`** 含 **`payload`**（供应商原始 JSON），可能含邮箱、客户 id、账单地址片段等 **PII**。
- 运营审计 API **`GET /api/v1/webhooks/billing/events`** 仅应在开启 **`BILLING_WEBHOOK_EVENTS_LIST_ENABLED=1`** 时使用，且需 **内部 ops** 流程与鉴权（见 `backend/src/billing/events_list`）。

## 2. 保留策略（Retention）

**推荐策略（可按合规要求调整）**

| 数据 | 建议 | 说明 |
|------|------|------|
| 行级元数据 | 长期保留 | `provider`、`event_type`、`raw_event_id`、`event_created_at`、`is_informational_event` 等用于去重与审计 |
| **`payload` 全文** | 有限期保留 + 可归档 | 例如 **90～180 天** 后对 `payload` 置空或迁移至冷存储；细则由法务/合规定稿 |

**落地方式（选型，非强制一次做完）**

1. **定期任务**：按 `created_at` 将超窗行的 `payload` 更新为 `NULL` 或 `{"redacted":true}`（需迁移允许可空或 JSON 占位）。
2. **备份**：若整库备份含该表，备份保留周期应 ≤ 与线上一致的保留承诺。

## 3. 数据库访问控制（已实现 + 运维注意）

迁移 **`supabase/migrations/20260410000000_billing_webhook_payload_access_control.sql`** 已：

- 对 **`authenticated` / `anon`** 撤销对 **`payload`** 列的 `SELECT`。
- 将 **`payload`** 的 `SELECT` 授予 **`ops_role`**（仅运维/受控连接应使用该角色）。
- 保留非 payload 列对应用角色的合理访问（以该迁移为准）。

**运维注意**

- 应用默认通过 **服务端连接串** 写入，勿用 **Supabase Dashboard/SQL Editor** 以高权限账户批量导出 `payload` 到不可控渠道。
- 新环境应用迁移后确认 **`ops_role`** 存在且与人类运维账号解耦。

## 4. 运维 PII 处理指南

1. **日志**：勿将 `payload` 全文打进应用日志；调试只记 `provider_event_id` / `raw_event_id` / `event_type`。
2. **工单**：勿粘贴完整 `payload`；必要时脱敏后附件并限权。
3. **删号 / 被遗忘请求**：在合规流程下，可按 `user_id` 关联的 billing 审计需求，对关联事件做匿名化或与法务确认后删除（当前以个案 runbook 为准，不设自动全删以免破坏账务审计）。

## 5. 相关代码与规格

- Webhook 入库：`backend/src/billing/ingest/webhook_ingest.rs`
- 事件列表：`backend/src/billing/events_list/`
- PII 审计结论：`.kiro/specs/workspace-scope-billing/pii-hygiene-audit.md`
