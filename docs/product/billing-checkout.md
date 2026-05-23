# 自助购买（Checkout）

登录用户可在 **设置 → 套餐与用量 → 升级套餐** 购买 **创作者档 / Pro 档 / 工作室档**（`enterprise` 仍走商务）。

## 支付方式

| 阶段 | 提供商 | 说明 |
|------|--------|------|
| 1 | 支付宝 | 电脑网站支付；异步通知 `POST /api/v1/webhooks/billing/alipay` |
| 2 | Stripe | Checkout Session + Customer Portal；`POST /api/v1/webhooks/billing/stripe` |
| 3 | BitPay | 发票 + 固定 30 天授权（非自动续费 MVP） |

## API

- `GET /api/v1/billing/plans?currency=CNY`
- `POST /api/v1/billing/checkout` — body: `{ "plan_tier", "provider", "currency" }`
- `GET /api/v1/billing/checkout/{session_id}` — 轮询 `pending` / `paid`
- `POST /api/v1/billing/portal` — Stripe 管理订阅（需已有 `billing_customer_id`）

价目来自 `backend/data/plan_catalog.json`；支付成功后通过现有 webhook 入账更新 `app_user_profile.plan_tier`。

## 开发 / 沙箱

未配置商户密钥时，可设 `BILLING_CHECKOUT_MOCK=1`：创建 checkout 后访问返回的 `mock-pay` URL 完成入账（仅本地/内测）。

## 深链返回

支付完成 return URL 建议指向：

`/?pane=account&tab=plan&checkout=success`

应用会打开套餐页并提示支付已收到。
