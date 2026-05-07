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

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。

### WP-A：人工抽检量表固化

| 项 | 内容 |
|----|------|
| **目标** | 评审员按固定维度打分（画面/叙事/对口型等），阈值与「放行/打回」规则书面化，减少主观漂移。 |
| **依赖** | 产品与编导对齐维度；可选：法务对用户生成内容的抽检要求。 |
| **PR 切片** | （1）量表 Markdown / Notion / 本文档附录；（2）若需结构化：扩展 `app_quality_review` comment JSON schema 或新增字段 + migration；（3）创建 API 校验。 |
| **触点** | `backend/src/prompting/quality/handlers/`；`backend/src/prompting/quality/tests.rs`；OpenAPI；Flutter 质量工作台表单。 |
| **测试** | `cargo test` quality 模块；前端 widget 测试（若有）。 |
| **回滚** | 恢复旧表单；DB 新列可留空 nullable。 |

### WP-B：Bad case 集版本化 + 发版前回归

| 项 | 内容 |
|----|------|
| **目标** | 固定一组 `quality_review_id` 或导出 fixture，发版前对比通过率或人工 spot-check。 |
| **依赖** | WP-A 或现有 `bad_case` 字段语义稳定。 |
| **PR 切片** | （1）`scripts/` 或 `backend` 下导出工具（只读）；（2）`.github/workflows/` 可选 job：每周跑或 manual；（3）文档：如何更新 golden 集。 |
| **触点** | `backend/src/prompting/quality/handlers/bad_case_frequency.rs`；CI `ci.yml`。 |
| **测试** | CI job 失败时输出 diff（哪些 id 退化）。 |
| **回滚** | 关闭 workflow；不影响线上。 |

### WP-C：分环节通过率产品化面板

| 项 | 内容 |
|----|------|
| **目标** | Flutter 质量工作台展示趋势（按 stage、按周），不仅列表 API。 |
| **依赖** | 现有列表/统计 REST 已满足聚合需求（否则先扩 API）。 |
| **PR 切片** | （1）`rust_api` 模型与 client；（2）图表组件（简单 DataTable → 后续图表库）；（3）缓存/防抖避免刷屏请求。 |
| **触点** | `frontend/lib/rust_api/`；质量相关 `*_section` / dialog；`backend/src/prompting/quality/handlers/`。 |
| **测试** | `flutter test`；golden 或 smoke。 |
| **回滚** | UI flag 隐藏新卡片。 |

### WP-D：Harness trace ↔ 评测样本关联

| 项 | 内容 |
|----|------|
| **目标** | 一条 quality review 可关联 `request_id`、session id、skill 版本、模型参数，便于回归对比。 |
| **依赖** | [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F（至少传递 id）；或短期先用现有 `comment` JSON。 |
| **PR 切片** | （1）API schema 扩展 optional 字段；（2）Flutter 创建评审时从最近一次 harness 活动自动填充；（3）隐私：不存用户正文可用 hash。 |
| **触点** | `app_quality_review` migration；handlers；`frontend/lib/agent_workspaces/`（读取最近 WS 元数据）。 |
| **测试** | PG 契约 roundtrip；端到端手工清单。 |
| **回滚** | 字段 optional；旧客户端忽略。 |
