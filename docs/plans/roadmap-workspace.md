# Workspace 路线图

母表：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)（Workspace W1–W11 全量任务总表，仍为真源）。  
总索引：[`roadmap-index.md`](./roadmap-index.md)。  
进度记录：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)。

## 定位

本分册把团队 Workspace 方向从“平台级总表”提升为 `roadmap-*` 入口，方便按阶段排期、追踪收口和与其他方向并列查看。  
**真源不变**：具体勾选、细项说明、边界条件仍以 [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) 为准；本文件只做阶段摘要、依赖顺序与后续主攻面整理。

## 当前状态

| Phase | 状态 | 说明 |
|------|------|------|
| W1 Workspace 生命周期 | `baseline_done` | 企业空间创建、列表、详情、PATCH、归档/恢复、active enterprise 配额 |
| W2 成员与邀请 | `baseline_done` | 成员增删改、邀请闭环、审计、速率限制、invite runbook |
| W3 当前上下文切换 | `baseline_done` | `current_workspace` 切换、自动回退 personal、客户端刷新 |
| W4 资源范围 | `baseline_done` | 项目/小说/资产/jobs 等按 workspace 成员语义收口 |
| W5 权限矩阵 | `next` | workspace 级默认矩阵与 billing 绑定口径已定稿；项目级角色 W5.2 仍待产品决定 |
| W6 Flutter 产品面 | `baseline_done` | 选择器、创建、成员管理、接受邀请、空状态、`rust_api` 对齐 |
| W7 Harness / WS | `baseline_done` | attach `workspaceUuid`、权限与回归矩阵 |
| W8 计费与配额 | `next`（实现） | W8.1 已定为 user-scope；W8.2–W8.4 **规格草案**见 [`workspace-billing-future-workspace-scope.md`](./workspace-billing-future-workspace-scope.md)；若改 workspace-scope 再实施迁移与运营面收口 |
| W9 安全 | `baseline_done` | W9.1–W9.4 已书面收口：安全边界、一致性矩阵、敏感操作流程、邀请安全评审 |
| W10 观测与运维 | `next` | W10.1 已实现并打通关键 trace/log 字段；W10.2 指标实现仍待补；W10.3 runbook 已完成 |
| W11 发布与门禁 | `baseline_done` | W11.1–W11.4 已书面收口：进度同步、roadmap 索引、迁移公告、refactor gate 真源 |

## 已完成基线

- W1–W4：workspace 生命周期、成员关系、当前上下文、项目与 jobs 作用域已经落地
- W6–W7：Flutter 与 Harness/WS 客户端路径已对齐
- W9.1：workspace 安全边界文档已补齐，见 [`workspace-security-boundary.md`](./workspace-security-boundary.md)
- W9.2：workspace RLS 一致性矩阵已补齐，见 [`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md)
- W8.1：workspace 计费口径已定为 user-scope，见 [`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md)
- W5.3：workspace 默认项目权限策略已补齐，见 [`workspace-project-permission-policy.md`](./workspace-project-permission-policy.md)
- W9.3：敏感操作 Runbook 已补齐，见 [`workspace-sensitive-operations-runbook.md`](./workspace-sensitive-operations-runbook.md)
- W9.4：邀请安全评审已补齐，见 [`workspace-invite-security-review.md`](./workspace-invite-security-review.md)
- W10.1/W10.2：workspace observability spec 已补齐，见 [`workspace-observability-spec.md`](./workspace-observability-spec.md)
- W10.1：workspace observability 关键字段已落地到 HTTP / jobs / Harness，W10.2 仍待补管理指标实现
- W10.3：workspace 运维 Runbook 已补齐，见 [`workspace-operations-runbook.md`](./workspace-operations-runbook.md)
- W11.2：本分册已建立，`roadmap-index.md` 可直接跳转到 workspace 方向
- W11.3：workspace 迁移公告已补齐，见 [`workspace-migration-notice.md`](./workspace-migration-notice.md)
- W11.4：workspace 方向的合并门禁已锚定到仓库根 `AGENTS.md` 与 [`full-stack-delivery-covenant.md`](./full-stack-delivery-covenant.md)

## 下一阶段

优先继续以下低耦合或必须收口项：

1. **W10.2 实现**：按 [`workspace-observability-spec.md`](./workspace-observability-spec.md) 落地 workspace 成员数 / 项目数 / 活跃 jobs 只读查询或内部接口
2. **W9 验证**：按 [`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md) 做 staging 验证，并把敏感操作 / invite review 纳入发布清单
3. **W8.2–W8.4**：仅在明确需要 workspace-scope billing 时，再收字段迁移、webhook 形状与运营视图

## 执行与依赖

- 计费与配额：W5.4 已由 W8.1 定稿为 user-scope；W8.2–W8.4 仅在未来重开 workspace-scope billing 时进入实现
- 安全与观测：W9/W10 可并行推进，但文档必须锚定现有实现，不预支未来架构
- 发布与门禁：W11 随各阶段收口同步更新，避免再次回到“只有总表、没有入口”的状态

## 文档触点

- 总表与勾选：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)
- 运维排障：[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)
- 观测规格：[`workspace-observability-spec.md`](./workspace-observability-spec.md)
- 计费口径决策：[`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md)
- 项目权限默认策略：[`workspace-project-permission-policy.md`](./workspace-project-permission-policy.md)
- RLS 一致性矩阵：[`workspace-rls-consistency-matrix.md`](./workspace-rls-consistency-matrix.md)
- 敏感操作：[`workspace-sensitive-operations-runbook.md`](./workspace-sensitive-operations-runbook.md)
- 邀请安全评审：[`workspace-invite-security-review.md`](./workspace-invite-security-review.md)
- 邀请专项：[`workspace-invite-runbook.md`](./workspace-invite-runbook.md)
- 迁移公告：[`workspace-migration-notice.md`](./workspace-migration-notice.md)
- WS 回归：[`harness-agent-workspaces-regression-matrix.md`](./harness-agent-workspaces-regression-matrix.md)
- 平台主进度：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)
