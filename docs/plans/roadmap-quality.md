# 路线图：质量门槛与评测

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md) §6、YAML `quality-bar`。

相关：[`.kiro/specs/ai-drama-quality-optimization/`](../../.kiro/specs/ai-drama-quality-optimization/)（目录存在则 **必做** 与本路线图对齐迭代）。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| `app_quality_review` + REST（列表/详情/统计/分环节） | `baseline_done` | YAML `quality-bar` |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| 人工抽检量表固化（维度、阈值、抽样批次） | `next` | **必做**；母文档 §6 |
| Bad case 集版本化与发版前回归门禁 | `next` | **必做**；须挂钩 CI workflow |
| 分环节通过率面板（产品化，不仅是 API） | `next` | **必做**；含图表化展示 |
| Harness trace ↔ 评测样本关联（skill 版本、模型参数） | `next` | **必做**；依赖 [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F |

## 验收

- API 变更同步 OpenAPI；前端契约与 `rust_api` 一致性由门禁覆盖。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。

### WP-A：人工抽检量表固化

| 项 | 内容 |
|----|------|
| **目标** | 评审员按固定维度打分（画面/叙事/对口型等），阈值与「放行/打回」规则书面化，减少主观漂移。 |
| **依赖** | **必做**：产品与编导对齐维度；业务涉及 UGC **必做**：法务抽检维度签字。 |
| **PR 切片** | （1）书面量表（本文档附录或 `docs/plans/` 专页）；（2）**必做**：结构化——扩展 `app_quality_review`（JSON schema / 列）+ migration + API 校验；（3）Flutter 表单与后端对齐。 |
| **触点** | `backend/src/prompting/quality/handlers/`；`backend/src/prompting/quality/tests.rs`；OpenAPI；Flutter 质量工作台表单。 |
| **测试** | **必做**：`cargo test` quality；**必做**：关键表单/widget 最小测试。 |
| **回滚** | 恢复旧表单；DB 新列可留空 nullable。 |

### WP-B：Bad case 集版本化 + 发版前回归

| 项 | 内容 |
|----|------|
| **目标** | 固定一组 `quality_review_id` 或导出 fixture，发版前对比通过率或人工 spot-check。 |
| **依赖** | WP-A 或现有 `bad_case` 字段语义稳定。 |
| **PR 切片** | （1）**必做**：导出工具（`scripts/` 或 `backend` 只读子命令）；（2）**必做**：`.github/workflows/` 定时或 `workflow_dispatch` job；（3）**必做**：golden 集更新说明与 CODEOWNER/review 规则。 |
| **触点** | `backend/src/prompting/quality/handlers/bad_case_frequency.rs`；CI `ci.yml`。 |
| **测试** | CI job 失败时输出 diff（哪些 id 退化）。 |
| **回滚** | 仅故障或模板错误时暂停 job；**正常运行须保持 workflow 启用**，避免「必做门禁」名存实亡。 |

### WP-C：分环节通过率产品化面板

| 项 | 内容 |
|----|------|
| **目标** | Flutter 质量工作台展示趋势（按 stage、按周），不仅列表 API。 |
| **依赖** | 若聚合不足，**必做**先扩 REST（与本 WP 同一里程碑收口）。 |
| **PR 切片** | （1）`rust_api` 模型与 client；（2）**必做**：图表库选型并落地趋势视图（stage/周）；（3）缓存/防抖。 |
| **触点** | `frontend/lib/rust_api/`；质量相关 `*_section` / dialog；`backend/src/prompting/quality/handlers/`。 |
| **测试** | `flutter test`；golden 或 smoke。 |
| **回滚** | UI flag 隐藏新卡片。 |

### WP-D：Harness trace ↔ 评测样本关联

| 项 | 内容 |
|----|------|
| **目标** | 一条 quality review 可关联 `request_id`、session id、skill 版本、模型参数，便于回归对比。 |
| **依赖** | [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) WP-F（trace id **必做**贯通）。 |
| **PR 切片** | （1）**必做**：结构化关联字段（DB/API；可为 nullable 以兼容旧客户端）；（2）**必做**：Flutter 创建评审时自动填充最近 harness 元数据；（3）**必做**：隐私策略（正文 hash / 不落库敏感段）。 |
| **触点** | `app_quality_review` migration；handlers；`frontend/lib/agent_workspaces/`（读取最近 WS 元数据）。 |
| **测试** | PG 契约 roundtrip；端到端手工清单。 |
| **回滚** | 字段保持 nullable；旧客户端忽略新字段；不得删除已写入关联数据而无迁移。 |
