# 模型价目与扣费语义（PRD 摘要）

> 运营可改 [`backend/data/model_pricing.json`](../../backend/data/model_pricing.json) 发版，无需改业务逻辑。

## 字段

| 字段 | 说明 |
|------|------|
| `pricing_unit` | `per_1k_tokens` \| `per_image` \| `per_video_second` \| `per_job` |
| `credits_per_unit` | 每单位积分（展示与预估） |
| `cny_cents_per_unit` | 每单位人民币分 |
| `tier` | `economy` \| `balanced` \| `quality`（对齐生产 patch `ModelTier`） |
| `value_tier` | 静态「值不值」标签：`economy` \| `balanced` \| `quality` |
| `best_for` | 一句适用场景（中/英由 UI l10n 覆盖时可仅存 en key） |

## 扣费语义（首期）

- API **`POST /api/v1/billing/estimate`** 仅返回 **预估**；`warnings` 含 `estimate_only`（未实际扣款）。
- **Job 配额**：每提交一条主线生成任务仍计 1 次 `daily_job_quota`（与积分展示并行）。
- **BYOK**：用户配置自有供应商 Key 时，estimate 返回 `platform_billing_exempt` warning，价目仅作参考。

## 任务默认量（estimate `quantity` 缺省）

见 `model_pricing.json` → `task_defaults`。
