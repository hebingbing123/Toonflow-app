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
| W5 权限矩阵 | `next` | 项目级角色与计费绑定仍未定稿；workspace 级默认矩阵已落地 |
| W6 Flutter 产品面 | `baseline_done` | 选择器、创建、成员管理、接受邀请、空状态、`rust_api` 对齐 |
| W7 Harness / WS | `baseline_done` | attach `workspaceUuid`、权限与回归矩阵 |
| W8 计费与配额 | `next` | `plan_tier` / quota 仍待 user vs workspace 策略定稿 |
| W9 安全 | `next` | RLS / service-role / 双路径一致性文档与评审未收口 |
| W10 观测与运维 | `next` | W10.3 runbook 已完成；trace 与指标仍待补 |
| W11 发布与门禁 | `next` | 本分册索引完成；版本公告与合并门禁收口仍待补 |

## 已完成基线

- W1–W4：workspace 生命周期、成员关系、当前上下文、项目与 jobs 作用域已经落地
- W6–W7：Flutter 与 Harness/WS 客户端路径已对齐
- W10.3：workspace 运维 Runbook 已补齐，见 [`workspace-operations-runbook.md`](./workspace-operations-runbook.md)
- W11.2：本分册已建立，`roadmap-index.md` 可直接跳转到 workspace 方向

## 下一阶段

优先继续以下低耦合或必须收口项：

1. **W9.1**：补 Rust `DATABASE_URL` / RLS / service-role 责任边界文档
2. **W10.1**：梳理 `workspace_id` 在 HTTP / jobs / Harness 的 trace 贯通计划
3. **W10.2**：定义 workspace 级成员数 / 项目数 / 活跃 jobs 指标口径
4. **W11.3–W11.4**：整理迁移公告与“全量 `yarn refactor:check` 为合并必跑”书面门禁

## 执行与依赖

- 计费与配额：W8 受产品/财务策略约束，默认晚于 W5.4 定稿
- 安全与观测：W9/W10 可并行推进，但文档必须锚定现有实现，不预支未来架构
- 发布与门禁：W11 随各阶段收口同步更新，避免再次回到“只有总表、没有入口”的状态

## 文档触点

- 总表与勾选：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)
- 运维排障：[`workspace-operations-runbook.md`](./workspace-operations-runbook.md)
- 邀请专项：[`workspace-invite-runbook.md`](./workspace-invite-runbook.md)
- WS 回归：[`harness-agent-workspaces-regression-matrix.md`](./harness-agent-workspaces-regression-matrix.md)
- 平台主进度：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)
