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
