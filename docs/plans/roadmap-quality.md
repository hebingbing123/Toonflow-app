# 路线图：质量门槛与评测

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md) §6、YAML `quality-bar`。

相关：[`.kiro/specs/ai-drama-quality-optimization/`](../../.kiro/specs/ai-drama-quality-optimization/)（若存在细化任务）。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| `app_quality_review` + REST（列表/详情/统计/分环节） | `baseline_done` | YAML `quality-bar` |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| 人工抽检量表固化（维度、阈值、抽样批次） | `next` | 母文档 §6 |
| Bad case 集版本化与发版前回归门禁 | `next` | 可与 CI 精选 job 挂钩 |
| 分环节通过率面板（产品化，不仅是 API） | `next` | Flutter 已有工作台入口，可加深报表 |
| Harness trace ↔ 评测样本关联（skill 版本、模型参数） | `next` | 依赖 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) 观测加深 |

## 验收

- API 变更同步 OpenAPI；前端契约与 `rust_api` 一致性由门禁覆盖。
