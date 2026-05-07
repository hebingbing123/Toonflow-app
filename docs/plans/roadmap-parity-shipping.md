# 路线图：Parity、发版门禁、旧栈下线

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`product-shipping-bar`、`master-detailed-parity-audit`、`decommission-electron`、`implementation-order`。

主表：[`electron-node-parity.md`](./electron-node-parity.md)  
审计：[`master-detailed-parity-audit.md`](./master-detailed-parity-audit.md)

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| Electron/Node 服务端移除、仓库以 Rust+Flutter 为准 | `baseline_done` | `decommission-electron` |
| Parity 与契约测试大量补齐 | `baseline_done` | `product-shipping-bar`、`master-detailed-parity-audit` YAML completed |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| Parity 表增量维护（新 REST/WS 必须回填） | `next` | 任何新接口合并前检查 |
| 灰度 / 回滚 Runbook（部署拓扑、Feature flag） | `next` | 母文档 `product-shipping-bar` 语义 |
| 九平台真实发布验收（P12） | `blocked` | 见 [`.kiro/specs/short-video-space/P-SECTION-STATUS.md`](../../.kiro/specs/short-video-space/P-SECTION-STATUS.md) |

## 验收

- CI：`refactor-monorepo` / `yarn refactor:check`。
- 发版前：对照 `electron-node-parity.md` 关键路径与用户验收清单。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。

### WP-A：Parity 表增量维护（合并门禁）

| 项 | 内容 |
|----|------|
| **目标** | 任意新增或语义变更的 REST/WS 在合并前更新 [`electron-node-parity.md`](./electron-node-parity.md)（或子表）与 OpenAPI/WS 文档。 |
| **依赖** | Reviewer 执行 checklist；可选 Danger/bot 提示。 |
| **PR 切片** | （1）PR 模板 checklist 一条「parity updated?」；（2）大功能：单独 docs commit。 |
| **触点** | `electron-node-parity.md`；`docs/websocket-events.md`；`backend` OpenAPI 导出。 |
| **测试** | `yarn refactor:check`；人工 diff parity 表与 router。 |
| **回滚** | 文档 revert；不影响线上。 |

### WP-B：灰度与回滚 Runbook

| 项 | 内容 |
|----|------|
| **目标** | 生产部署可「先 canary 流量 → 全量」或「一键回到上一镜像/二进制」，并写明 DB 迁移顺序（先迁移后代码或反之）。 |
| **依赖** | 实际编排（K8s / systemd / PaaS）由运维提供名词。 |
| **PR 切片** | （1）`docs/plans/release-runbook.md`：拓扑、环境变量、健康检查 URL、回滚命令；（2）与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) WP-B 交叉引用。 |
| **触点** | 部署脚本（若有）；`GET /api/v1/ready`；迁移目录。 |
| **测试** | Staging 演练：部署 N+1 → 回滚 N；记录 RTO。 |
| **回滚** | 按 Runbook 执行；迁移不可逆项单独标注。 |

### WP-C：九平台真实发布验收（P12）

| 项 | 内容 |
|----|------|
| **目标** | 短剧发布链路在各平台真实账号下走通（上架策略外）。 |
| **依赖** | 真实凭证与合规；见 [`.kiro/specs/short-video-space/P-SECTION-STATUS.md`](../../.kiro/specs/short-video-space/P-SECTION-STATUS.md)。 |
| **PR 切片** | 通常为「运营 + 工程联合」里程碑；（1）staging 用测试号；（2）生产分批平台；（3）每平台残留 issues 回填 parity 或 kiro。 |
| **触点** | `frontend/lib/short_video_space/`；后端 publish/export 相关 handler（以 parity 表为准）。 |
| **测试** | 人工矩阵签字；自动化仅辅助（mock API）。 |
| **回滚** | 关闭发布入口 feature；内容侧下架流程按平台文档。 |
