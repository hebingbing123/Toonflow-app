# Implementation Plan: billing-i18n-production

## Overview

本实现计划将计费主路径国际化（i18n）覆盖率提升至生产就绪水平，分三层交付：

1. **Backend（Rust）**：新增 `error/billing_errors.rs` 辅助模块，扩展 `ApiError` 枚举，修改 `metering/quota.rs`，使计费错误码 `message` 字段支持中英双语。
2. **Flutter（Dart）**：在 `app_en.arb`/`app_zh.arb` 中新增 `billing*` 前缀 L10n Keys，新增 `billing_l10n_helpers.dart`，扩展 `rust_api_error_format.dart`、`notifications/section.dart`、`shell/workspace_context_view.dart`。
3. **OpenAPI 契约**：在计费相关端点补充 `Accept-Language` 说明。

三层在同一里程碑内交付，遵循 `full-stack-delivery-covenant.md`。

---

## Tasks

- [x] 1. 新增 Backend 计费错误辅助模块
  - [x] 1.1 在 `error/api_error.rs` 中新增四个 i18n 变体
    - 新增 `QuotaExceededI18n { en: String, zh: String }`、`SubscriptionExpiredI18n { en: String, zh: String }`、`PaymentFailedI18n { en: String, zh: String }`、`SubscriptionPastDueI18n { en: String, zh: String }` 枚举变体
    - 在 `IntoResponse` 实现中为 `QuotaExceededI18n` 添加处理分支：`code = "quota_exceeded"`，`retry_after_ms` 和 `Retry-After` 逻辑与 `QuotaExceeded` 相同，`message` 根据 `current_locale()` 选择 `en` 或 `zh`
    - 为 `SubscriptionExpiredI18n`（HTTP 403，`code = "subscription_expired"`）、`PaymentFailedI18n`（HTTP 403，`code = "payment_failed"`）、`SubscriptionPastDueI18n`（HTTP 403，`code = "subscription_past_due"`）添加对应 `IntoResponse` 分支
    - 扩展 `is_quota` 检测逻辑，同时匹配 `QuotaExceeded(_)` 和 `QuotaExceededI18n { .. }`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.9_

  - [x] 1.2 新建 `error/billing_errors.rs` 辅助模块
    - 实现 `quota_exceeded_billing_i18n(limit: u64, plan_tier: &str) -> ApiError`：调用 `current_locale()` 读取 task-local `REQUEST_LOCALE`，无 task-local 时默认 `ApiLocale::En`，返回 `ApiError::QuotaExceededI18n { en, zh }`
    - 实现 `subscription_expired_i18n() -> ApiError`、`payment_failed_i18n() -> ApiError`、`subscription_past_due_i18n() -> ApiError`，分别返回对应 `*I18n` 变体
    - 在 `error/mod.rs` 中 `pub mod billing_errors;` 导出
    - _Requirements: 1.1, 1.2, 1.5, 1.6, 1.7, 1.9_

  - [x] 1.3 为 `billing_errors.rs` 编写单元测试（中英文路径 + 不变量 + 无 task-local 回落）
    - 对每个辅助函数，在 `REQUEST_LOCALE.scope(ApiLocale::En)` 和 `REQUEST_LOCALE.scope(ApiLocale::Zh)` 下分别验证 `message` 字段内容
    - 验证 `code` 字段不随语言变化；验证 `QuotaExceededI18n` 的 `retry_after_ms` 与语言无关
    - 直接构造错误（不设置 `REQUEST_LOCALE`），验证回落英文
    - _Requirements: 8.5_

  - [x] 1.4 为 `billing_errors.rs` 编写属性测试（proptest）
    - **Property 1: 计费错误双语响应不变量** — 对任意语言偏好（`En`/`Zh`）和任意 `limit`/`plan_tier` 输入，`code` 字段不变，`message` 随语言变化，`retry_after_ms` 不随语言变化
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**
    - **Property 2: Accept-Language 未知语言标签回落英文** — 对任意不含 `zh`/`en` 系的语言标签字符串，`preferred_locale_from_headers` 返回 `ApiLocale::En`
    - **Validates: Requirements 1.8**
    - _Requirements: 1.8_

- [x] 2. 修改 `metering/quota.rs` 使用新辅助函数
  - [x] 2.1 将 `quota.rs` 中的 `ApiError::QuotaExceeded(format!(...))` 替换为 `quota_exceeded_billing_i18n(limit, plan_tier)`
    - 扩展 `check_workspace_quota` 函数签名（或从 DB 查询结果中读取 `plan_tier`），将 `plan_tier` 传入辅助函数
    - 替换所有两处 `QuotaExceeded` 调用点
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 3. Checkpoint — Backend 阶段验证
  - 确保所有 Backend 测试通过，运行 `yarn refactor:agent`，ask the user if questions arise.

- [x] 4. 新增 Flutter ARB L10n Keys
  - [x] 4.1 在 `app_en.arb` 和 `app_zh.arb` 中同时新增订阅状态 L10n Keys
    - 新增 `billingSubscriptionStatusActive`、`billingSubscriptionStatusPastDue`、`billingSubscriptionStatusCanceled`、`billingSubscriptionStatusTrialing`、`billingSubscriptionStatusPaused`、`billingSubscriptionStatusUnpaid`、`billingSubscriptionStatusUnknown`（共 7 个 key，两个文件同步）
    - _Requirements: 2.1, 8.3, 8.4_

  - [x] 4.2 在 `app_en.arb` 和 `app_zh.arb` 中同时新增计费通知类型 L10n Keys
    - 新增 `billingNotificationSubscriptionActivated`、`billingNotificationSubscriptionPastDue`、`billingNotificationSubscriptionCanceled`、`billingNotificationPaymentFailed`、`billingNotificationSubscriptionExpired`、`billingNotificationSubscriptionTrialing`、`billingNotificationUnknown`（共 7 个 key，两个文件同步）
    - _Requirements: 3.1, 8.3, 8.4_

  - [x] 4.3 在 `app_en.arb` 和 `app_zh.arb` 中同时新增配额耗尽/升级引导 L10n Keys
    - 新增 `billingQuotaExceededTitle`、`billingQuotaExceededFree`（含 `{plan}` 占位符）、`billingQuotaExceededPro`（含 `{plan}` 占位符）、`billingQuotaResetHint`、`billingUpgradePlan`（共 5 个 key，两个文件同步）
    - 在 `@billingQuotaExceededFree` 和 `@billingQuotaExceededPro` 中声明 `placeholders: { plan: { type: String } }`
    - _Requirements: 4.1, 4.3, 4.6, 8.3, 8.4_

  - [x] 4.4 在 `app_en.arb` 和 `app_zh.arb` 中同时新增计费错误态 L10n Keys
    - 新增 `billingErrorPaymentFailed`、`billingErrorSubscriptionExpired`、`billingErrorSubscriptionPastDue`（共 3 个 key，两个文件同步）
    - _Requirements: 5.1, 8.3, 8.4_

  - [x] 4.5 在 `app_en.arb` 和 `app_zh.arb` 中同时新增套餐展示名称 L10n Keys
    - 新增 `billingPlanTierFree`、`billingPlanTierPro`、`billingPlanTierEnterprise`、`billingPlanTierUnknown`（共 4 个 key，两个文件同步）
    - _Requirements: 6.1, 8.3, 8.4_

  - [x] 4.6 验证 ARB key 集合一致性（属性测试）
    - **Property 8: ARB key 集合一致性不变量** — 解析 `app_en.arb` 和 `app_zh.arb`，断言两者 key 集合完全相同（无缺失、无多余）
    - **Validates: Requirements 8.4**

- [x] 5. 新建 `l10n/billing_l10n_helpers.dart` 辅助函数文件
  - [x] 5.1 实现订阅状态和套餐等级辅助函数
    - 实现 `subscriptionStatusLabel(AppLocalizations l10n, String? status) -> String`：映射已知 `SubscriptionStatus` 到对应 L10n_Key，未知值返回 `l10n.billingSubscriptionStatusUnknown`
    - 实现 `subscriptionStatusColor(BuildContext context, String? status) -> Color?`：`past_due` 返回 `warningColor`，`canceled` 返回 `secondaryColor`，其余返回 `null`
    - 实现 `planTierDisplayName(AppLocalizations l10n, String? planTier) -> String`：映射 `free`/`pro`/`enterprise` 到对应 L10n_Key，未知值返回 `l10n.billingPlanTierUnknown`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 6.1, 6.2, 6.3_

  - [x] 5.2 实现通知类型和配额耗尽辅助函数
    - 实现 `billingNotificationTypeLabel(AppLocalizations l10n, String notificationType) -> String`：映射已知计费通知类型到对应 L10n_Key，未知类型返回 `l10n.billingNotificationUnknown`
    - 实现 `quotaExceededMessage(AppLocalizations l10n, String? planTier) -> String`：`free` 套餐返回 `l10n.billingQuotaExceededFree(plan: planTierDisplayName(l10n, planTier))`，`pro` 套餐返回 `l10n.billingQuotaExceededPro(plan: ...)`，其他返回 `billingQuotaExceededTitle`
    - _Requirements: 3.2, 3.3, 4.2, 4.4, 4.5_

  - [x] 5.3 为 `billing_l10n_helpers.dart` 编写属性测试
    - **Property 3: 未知枚举值回落通用文案** — 对任意不在已知枚举范围内的字符串，`subscriptionStatusLabel`、`planTierDisplayName` 返回通用占位文案而非原始字符串
    - **Validates: Requirements 2.3, 6.3**
    - **Property 4: 计费通知类型标签本地化** — 对任意已知计费通知类型，`billingNotificationTypeLabel` 返回的字符串不等于原始 `notificationType` 字符串
    - **Validates: Requirements 3.2, 3.3**
    - **Property 5: 套餐感知配额耗尽文案** — 对任意 `PlanTier`，`quotaExceededMessage` 返回的文案包含该套餐的本地化展示名称，且 `free` 套餐文案与 `pro` 套餐文案不同
    - **Validates: Requirements 4.2, 4.4, 4.5**
    - **Property 7: PlanTier 展示名称本地化** — 对任意已知 `PlanTier`，`planTierDisplayName` 在中英文两种 locale 下返回不同字符串，且均不等于原始 `plan_tier` 字符串
    - **Validates: Requirements 6.1, 6.2, 6.4**

- [x] 6. 扩展 Flutter 现有文件使用新 L10n Keys
  - [x] 6.1 扩展 `l10n/rust_api_error_format.dart` 处理计费错误码
    - 在 `formatRustApiExceptionForDisplay` 中，在现有 `quota_exceeded` 处理之前新增计费错误码分支：`subscription_expired` → `l10n.billingErrorSubscriptionExpired`，`payment_failed` → `l10n.billingErrorPaymentFailed`，`subscription_past_due` → `l10n.billingErrorSubscriptionPastDue`
    - 未知 `BillingErrorCode` 回落 `l10n.rustApiClientUnknownError`
    - _Requirements: 5.2, 5.3, 5.4, 5.5_

  - [x] 6.2 为 `rust_api_error_format.dart` 编写属性测试
    - **Property 6: 计费错误码 Flutter 本地化** — 对任意已知 `BillingErrorCode`，`formatRustApiExceptionForDisplay` 返回的字符串不等于原始 `code` 字符串，且在中英文两种 locale 下返回不同文案
    - **Validates: Requirements 5.2, 5.3, 5.4**

  - [x] 6.3 扩展 `notifications/section.dart` 的 `_notificationTypeLabel` 函数
    - 在 `switch` 中新增六个计费通知类型分支（`billing_subscription_activated`、`billing_subscription_past_due`、`billing_subscription_canceled`、`billing_payment_failed`、`billing_subscription_expired`、`billing_subscription_trialing`），使用 `billingNotificationTypeLabel` 辅助函数
    - 修改 `default` 分支：若 `notificationType.startsWith('billing_')` 则返回 `l10n.billingNotificationUnknown`，否则保持原有行为（返回原始字符串）
    - _Requirements: 3.2, 3.3, 3.4_

  - [x] 6.4 修改 `shell/workspace_context_view.dart` 使用本地化 PlanTier 名称
    - 将 `workspaceBillingPlan(workspacePlanTier ?? l10n.workspaceBillingUnknownTier)` 中的 `workspacePlanTier` 替换为 `planTierDisplayName(l10n, workspacePlanTier)`，使 `{tier}` 占位符填充本地化展示名称
    - 导入 `billing_l10n_helpers.dart`
    - _Requirements: 6.2, 6.4_

- [x] 7. Checkpoint — Flutter 阶段验证
  - 确保所有 Flutter 测试通过，运行 `yarn refactor:agent`，ask the user if questions arise.

- [x] 8. 更新 OpenAPI 契约
  - [x] 8.1 在 `billing/openapi.rs` 中补充 `Accept-Language` 参数说明
    - 在 `post_billing_webhook` 和 `GET /api/v1/me` 端点的 `#[utoipa::path]` 宏 `params` 中添加 `Accept-Language` header 参数说明（支持值：`zh`、`en`；默认值：`en`）
    - 在 429 响应的 `description` 中注明：`message` 字段内容随 `Accept-Language` 变化，`code` 和 `retry_after_ms` 字段不变
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 8.2 验证 OpenAPI 导出无解析错误
    - 运行 `cargo run --bin export-openapi` 确认导出成功且无解析错误
    - _Requirements: 7.4_

- [x] 9. Final Checkpoint — 全量门禁验证
  - `yarn refactor:agent --full`：OpenAPI 导出、`cargo fmt`/`clippy -D warnings`、全量 `cargo test`（含 `-j 1 -- --test-threads=1` 串行集成测试）、Flutter `analyze`/`test` 已通过（2026-05）。
  - 计费 UI 展示名称随 L10n 后，相关 Widget 测试需断言本地化文案（如英文 `Plan: Enterprise`），与 `billingPlanTier*` ARB 一致。

---

## Notes

- 标有 `*` 的子任务为可选测试任务，可跳过以加快 MVP 交付
- 每个任务引用具体需求条款以保证可追溯性
- ARB key 必须同时写入 `app_en.arb` 和 `app_zh.arb`，key 集合保持完全一致（Requirement 8.4）
- 所有新增文件控制在 800 行以内（Requirement 8.3）
- Backend 属性测试使用 `proptest`，最少 100 次迭代（proptest 默认 256 次）
- Flutter 属性测试使用 `glados` 或手写生成器
- 每个属性测试注释中标注：`Feature: billing-i18n-production, Property N: <property_text>`
- 三层（Backend + Flutter + OpenAPI）须在同一里程碑内完成，合并前须通过 `yarn refactor:agent --full` 门禁

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2"] },
    { "id": 2, "tasks": ["1.3"] },
    { "id": 3, "tasks": ["1.4"] },
    { "id": 4, "tasks": ["2.1"] },
    { "id": 5, "tasks": ["3"] },
    { "id": 6, "tasks": ["4.1"] },
    { "id": 7, "tasks": ["4.2"] },
    { "id": 8, "tasks": ["4.3"] },
    { "id": 9, "tasks": ["4.4"] },
    { "id": 10, "tasks": ["4.5"] },
    { "id": 11, "tasks": ["4.6"] },
    { "id": 12, "tasks": ["5.1"] },
    { "id": 13, "tasks": ["5.2"] },
    { "id": 14, "tasks": ["5.3"] },
    { "id": 15, "tasks": ["6.1"] },
    { "id": 16, "tasks": ["6.2"] },
    { "id": 17, "tasks": ["6.3"] },
    { "id": 18, "tasks": ["6.4"] },
    { "id": 19, "tasks": ["7"] },
    { "id": 20, "tasks": ["8.1"] },
    { "id": 21, "tasks": ["8.2"] },
    { "id": 22, "tasks": ["9"] }
  ]
}
```
