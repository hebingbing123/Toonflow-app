# Requirements Document

## Introduction

本功能（billing-i18n-production）旨在将计费主路径的国际化（i18n）覆盖率提升至生产就绪水平。当前后端计费相关错误码（如配额耗尽、订阅过期）的 `message` 字段仅有英文单语言；Flutter 侧订阅状态展示、计费事件文案、配额耗尽/升级引导、计费错误态文案及 plan_tier 展示名称均存在硬编码或 l10n 缺失问题；OpenAPI 文档中也未说明 `Accept-Language` 对错误响应的影响。

本功能覆盖三个交付层：(1) Backend（Rust）：计费相关错误码 `message` 字段支持中英双语，通过 `Accept-Language` 请求头决定语言；(2) Flutter：`l10n` 全覆盖计费主路径，包括订阅状态展示、计费事件文案、配额耗尽/升级引导、计费错误态文案、plan_tier 展示名称；(3) 契约（OpenAPI）：错误响应 schema 补充 `Accept-Language` 说明。遵循 `full-stack-delivery-covenant.md`：backend + frontend + 契约同里程碑交付。

术语：**Billing_I18n_System** 指本功能所涉及的计费国际化系统；**ApiLocale** 指后端语言偏好枚举（`En`/`Zh`），由 `Accept-Language` 解析得出；**QuotaExceeded** 指 `ApiError::QuotaExceeded` 变体（HTTP 429）；**SubscriptionStatus** 指订阅状态字符串（`active`/`past_due`/`canceled`/`trialing`/`paused`/`unpaid`）；**PlanTier** 指套餐等级字符串（`free`/`pro`/`enterprise`）；**BillingErrorCode** 指计费相关错误码（`quota_exceeded`/`subscription_expired`/`payment_failed`/`subscription_past_due`）；**L10n_Key** 指 Flutter `AppLocalizations` 中的国际化键；**Notification_Center** 指 Flutter 通知中心；**Upgrade_Prompt** 指配额耗尽或订阅异常时的升级引导文案；**OpenAPI_Spec** 指后端 OpenAPI 规范文件。

## Requirements

### Requirement 1

**User Story:** 作为 API 消费者，我希望计费相关错误码的 `message` 字段能根据 `Accept-Language` 请求头返回对应语言的文案，以便我能直接向用户展示可读的错误信息，而无需在客户端维护错误码到文案的映射表。

#### Acceptance Criteria

1. WHEN 请求头包含 `Accept-Language: zh` 或 `Accept-Language: zh-CN` 时，THE Billing_I18n_System SHALL 在 `QuotaExceeded` 错误响应的 `message` 字段中返回中文文案。
2. WHEN 请求头包含 `Accept-Language: en` 或未提供 `Accept-Language` 时，THE Billing_I18n_System SHALL 在 `QuotaExceeded` 错误响应的 `message` 字段中返回英文文案。
3. WHEN `QuotaExceeded` 错误以中文返回时，THE Billing_I18n_System SHALL 保持 `code` 字段值为 `quota_exceeded`，机器可读码不随语言变化。
4. WHEN `QuotaExceeded` 错误以中文返回时，THE Billing_I18n_System SHALL 保持 `retry_after_ms` 字段与 `Retry-After` 响应头数值不变，数值字段不受语言影响。
5. WHEN 请求头包含 `Accept-Language: zh` 时，THE Billing_I18n_System SHALL 在 `subscription_expired` 错误响应的 `message` 字段中返回中文文案。
6. WHEN 请求头包含 `Accept-Language: zh` 时，THE Billing_I18n_System SHALL 在 `payment_failed` 错误响应的 `message` 字段中返回中文文案。
7. WHEN 请求头包含 `Accept-Language: zh` 时，THE Billing_I18n_System SHALL 在 `subscription_past_due` 错误响应的 `message` 字段中返回中文文案。
8. IF `Accept-Language` 请求头包含无法识别的语言标签（既非 `zh` 系也非 `en` 系），THEN THE Billing_I18n_System SHALL 回落到英文文案作为默认值。
9. THE Billing_I18n_System SHALL 通过现有 `REQUEST_LOCALE` task-local 机制传播语言偏好，不引入新的全局状态。

### Requirement 2

**User Story:** 作为应用用户，我希望订阅状态（如"已激活"、"逾期未付"、"已取消"等）以界面语言显示，而不是显示原始英文状态码，以便我能清晰理解当前账户的计费状态。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 为 `SubscriptionStatus` 的每个取值（`active`、`past_due`、`canceled`、`trialing`、`paused`、`unpaid`）在 `app_en.arb` 和 `app_zh.arb` 中提供对应的 L10n_Key。
2. WHEN Flutter UI 展示订阅状态时，THE Billing_I18n_System SHALL 使用 L10n_Key 对应的本地化文案，而非直接展示原始状态字符串。
3. IF `SubscriptionStatus` 取值为未知字符串（不在已知枚举范围内），THEN THE Billing_I18n_System SHALL 展示通用的"未知状态"本地化文案，而非原始字符串。
4. WHEN 订阅状态为 `past_due` 时，THE Billing_I18n_System SHALL 在展示文案旁提供视觉区分（如警告色），以引起用户注意。
5. WHEN 订阅状态为 `canceled` 时，THE Billing_I18n_System SHALL 在展示文案旁提供视觉区分（如次要色），以区别于正常状态。

### Requirement 3

**User Story:** 作为应用用户，我希望通知中心中的计费事件通知（如订阅激活、付款失败、订阅到期等）以界面语言显示，以便我能理解计费相关的系统通知。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 为以下计费通知类型在 `app_en.arb` 和 `app_zh.arb` 中提供 L10n_Key：`billing_subscription_activated`、`billing_subscription_past_due`、`billing_subscription_canceled`、`billing_payment_failed`、`billing_subscription_expired`、`billing_subscription_trialing`。
2. WHEN Notification_Center 展示计费事件通知时，THE Billing_I18n_System SHALL 通过 `_notificationTypeLabel` 函数使用对应的 L10n_Key，而非回落到原始 `notificationType` 字符串。
3. IF 计费通知类型不在已知列表中，THEN THE Billing_I18n_System SHALL 展示通用的"计费事件"本地化文案，而非原始类型字符串。
4. THE Billing_I18n_System SHALL 为 webhook 事件摘要（如 `invoice.paid`、`subscription.expired`）在 Notification_Center 的展示提供本地化的事件类型标签。

### Requirement 4

**User Story:** 作为应用用户，我希望当配额耗尽或需要升级套餐时，看到以界面语言显示的引导文案，以便我能理解当前限制并采取相应行动。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 为配额耗尽场景（HTTP 429 / `quota_exceeded`）在 `app_en.arb` 和 `app_zh.arb` 中提供专用的计费语境 L10n_Key，区别于通用速率限制文案。
2. WHEN 用户触发配额耗尽错误时，THE Billing_I18n_System SHALL 展示包含当前套餐名称和 Upgrade_Prompt 的本地化文案。
3. THE Billing_I18n_System SHALL 为升级引导按钮文案在 `app_en.arb` 和 `app_zh.arb` 中提供 L10n_Key（如"升级套餐"/"Upgrade Plan"）。
4. WHEN 用户的 `PlanTier` 为 `free` 且配额耗尽时，THE Billing_I18n_System SHALL 展示引导用户升级到付费套餐的本地化文案。
5. WHEN 用户的 `PlanTier` 为 `pro` 且配额耗尽时，THE Billing_I18n_System SHALL 展示引导用户联系支持或等待配额重置的本地化文案。
6. THE Billing_I18n_System SHALL 为配额重置时间提示（每日 UTC 零点重置）在 `app_en.arb` 和 `app_zh.arb` 中提供 L10n_Key。

### Requirement 5

**User Story:** 作为应用用户，我希望计费相关的错误状态（如付款失败、订阅过期）以界面语言显示，以便我能理解错误原因并知道如何处理。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 为以下 BillingErrorCode 在 `app_en.arb` 和 `app_zh.arb` 中提供 L10n_Key：`payment_failed`、`subscription_expired`、`subscription_past_due`。
2. WHEN Flutter 的 `rust_api_error_format.dart` 处理计费相关错误码时，THE Billing_I18n_System SHALL 使用对应的 L10n_Key 而非硬编码文案。
3. WHEN 后端返回 `subscription_expired` 错误码时，THE Billing_I18n_System SHALL 展示包含续订引导的本地化文案。
4. WHEN 后端返回 `payment_failed` 错误码时，THE Billing_I18n_System SHALL 展示包含更新支付方式引导的本地化文案。
5. IF BillingErrorCode 不在已知列表中，THEN THE Billing_I18n_System SHALL 回落到通用错误文案的本地化版本，而非展示原始错误码字符串。

### Requirement 6

**User Story:** 作为应用用户，我希望套餐等级名称（如 Free、Pro、Enterprise）以本地化的展示名称显示，以便在不同语言界面下保持一致的产品体验。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 为 `PlanTier` 的每个取值（`free`、`pro`、`enterprise`）在 `app_en.arb` 和 `app_zh.arb` 中提供展示名称 L10n_Key。
2. WHEN Flutter UI 展示套餐名称时（包括 workspace billing 卡片、配额耗尽提示、升级引导等），THE Billing_I18n_System SHALL 使用 L10n_Key 对应的本地化展示名称；IF 本地化文件缺失或损坏，THE Billing_I18n_System SHALL 展示占位文案（如"---"）而非原始 `plan_tier` 字符串。
3. IF `PlanTier` 取值为未知字符串，THEN THE Billing_I18n_System SHALL 展示通用的"未知套餐"本地化文案，而非原始字符串。
4. THE Billing_I18n_System SHALL 确保 `workspaceBillingPlan` 等现有 L10n_Key 中的 `{tier}` 占位符使用本地化展示名称填充，而非原始 `plan_tier` 字符串。

### Requirement 7

**User Story:** 作为 API 集成开发者，我希望 OpenAPI 文档中明确说明哪些错误响应支持 `Accept-Language` 多语言，以便我能正确配置客户端请求头并向用户展示本地化错误信息。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 在 OpenAPI_Spec 的全局 `parameters` 或相关端点的 `parameters` 中补充 `Accept-Language` 请求头的说明，包括支持的语言值（`zh`、`en`）和默认值（`en`）。
2. THE Billing_I18n_System SHALL 在计费相关端点（`POST /api/v1/webhooks/billing`、`GET /api/v1/me`）的错误响应 schema 描述中注明 `message` 字段受 `Accept-Language` 影响。
3. THE Billing_I18n_System SHALL 在 OpenAPI_Spec 中为 `quota_exceeded`（429）错误响应补充说明：`message` 字段内容随 `Accept-Language` 变化，`code` 和 `retry_after_ms` 字段不变。
4. THE Billing_I18n_System SHALL 确保 OpenAPI_Spec 变更后，`cargo run --bin export-openapi` 可正常导出且无解析错误。

### Requirement 8

**User Story:** 作为开发团队成员，我希望计费 i18n 功能在 backend、frontend 和 OpenAPI 契约三个层面同里程碑交付，以避免出现"后端已支持多语言但前端仍硬编码"或"前端已使用 l10n key 但后端未返回对应语言"的不一致窗口期。

#### Acceptance Criteria

1. THE Billing_I18n_System SHALL 确保 backend 计费错误码多语言（Requirement 1）、Flutter l10n 覆盖（Requirements 2–6）和 OpenAPI 契约更新（Requirement 7）在同一里程碑内完成交付。
2. WHEN 变更涉及 `backend/`、`frontend/` 或 `docs/websocket-events.md` 时，THE Billing_I18n_System SHALL 在合并前通过 `yarn refactor:agent --full` 门禁检查（含 `flutter analyze`、`flutter test`、`cargo clippy`、`cargo test`）。
3. THE Billing_I18n_System SHALL 确保单文件行数不超过 800 行；若新增 L10n_Key 导致 `app_en.arb` 或 `app_zh.arb` 超出合理规模，SHALL 按语义分组组织 key 命名（如 `billing*` 前缀），且语义分组操作必须同时应用于所有语言文件，不得仅对单一语言文件分组而导致 key 集合不一致。
4. THE Billing_I18n_System SHALL 持续保持 `app_en.arb` 和 `app_zh.arb` 中的 key 集合完全一致（无缺失、无多余），此约束为持续不变量，不限于新增 key 时；任何新增 key 的操作必须同时更新所有语言文件，不得仅更新单一语言文件。
5. THE Billing_I18n_System SHALL 为新增的 backend 计费错误码多语言逻辑提供单元测试，覆盖中英文两种语言路径。
