# OpenFlow 文档审计与整理方案（2026-05）

## 审计日期
2026-05-19

## 审计范围
`docs/` 目录下的所有 Markdown 文档（共 82 个文件）

---

## 一、当前文档结构分析

### 1.1 目录结构
```
docs/
├── migration/          # 数据库迁移文档（2 个文件）
├── plans/              # 技术路线图与设计文档（68 个文件）
├── runbooks/           # 运维手册（3 个文件）
├── sponsored/          # 赞助商资源（1 个图片）
└── *.md                # 根目录文档（9 个文件）
```

### 1.2 文档分类统计

| 分类 | 数量 | 说明 |
|------|------|------|
| **核心路线图** | 4 | harness-rust-flutter.md, electron-node-parity.md 等 |
| **分方向路线图** | 7 | roadmap-*.md 系列 |
| **ADR（架构决策）** | 4 | adr-*.md 系列 |
| **安全与威胁模型** | 3 | *-threat-model.md, *-security-*.md |
| **运维手册（Runbooks）** | 11 | *-runbook.md, *-guide.md |
| **Workspace 计费** | 13 | workspace-billing-*.md 系列 |
| **Workspace 协作** | 9 | workspace-*.md 系列（非计费） |
| **产品与 UX** | 5 | studio-*.md, short-video-*.md |
| **技术专项** | 7 | http-api-cleanup.md, tasks-*.md 等 |
| **质量与平台** | 5 | quality-rubric.md, platform-*.md |
| **其他专项** | 9 | novel-*.md, model-pricing-prd.md 等 |
| **根目录文档** | 9 | websocket-events.md, global-search.md 等 |
| **迁移文档** | 2 | database-migrations.md, sqlite-to-supabase.md |

---

## 二、发现的问题

### 2.1 结构性问题

#### 问题 1：文档分类不清晰
- **现状**：`docs/plans/` 目录混杂了 68 个文件，包含路线图、ADR、Runbook、产品规格等多种类型
- **影响**：难以快速定位所需文档，新人上手困难
- **建议**：按文档类型重新组织目录结构

#### 问题 2：Runbooks 分散
- **现状**：
  - `docs/runbooks/` 只有 3 个文件
  - `docs/plans/` 中有 11 个 *-runbook.md 文件
- **影响**：运维人员需要在两个目录中查找
- **建议**：统一迁移到 `docs/runbooks/`

#### 问题 3：根目录文档缺少索引
- **现状**：`docs/` 根目录有 9 个独立文档，没有统一的索引文件
- **影响**：不知道有哪些根目录文档可用
- **建议**：创建 `docs/README.md` 作为总索引

#### 问题 4：Workspace 文档过于分散
- **现状**：22 个 workspace 相关文档分散在 plans 目录
- **影响**：难以系统性了解 Workspace 功能
- **建议**：创建 `docs/workspace/` 子目录

### 2.2 内容性问题

#### 问题 5：文档状态不明确
- **现状**：大部分文档没有标注状态（草稿/审核中/已完成/已废弃）
- **影响**：不知道哪些文档是最新的、哪些已过时
- **建议**：在文档头部添加状态标签

#### 问题 6：文档更新日期缺失
- **现状**：大部分文档没有"最后更新"日期
- **影响**：无法判断文档的时效性
- **建议**：添加 YAML front matter 记录更新日期

#### 问题 7：文档间引用不一致
- **现状**：有些用相对路径，有些用绝对路径，有些路径已失效
- **影响**：链接失效，导航困难
- **建议**：统一使用相对路径，并验证所有链接

#### 问题 8：重复或冗余内容
- **现状**：
  - `docs/README.en.md` 与根目录 `README.md` 内容重复
  - 多个 workspace-billing 文档内容有重叠
- **影响**：维护成本高，容易产生不一致
- **建议**：合并重复内容，建立清晰的文档层次

### 2.3 可用性问题

#### 问题 9：缺少快速导航
- **现状**：没有按角色（开发者/运维/产品）分类的导航
- **影响**：不同角色难以快速找到相关文档
- **建议**：创建角色导向的导航页面

#### 问题 10：缺少文档模板
- **现状**：不同类型文档格式不统一
- **影响**：新文档质量参差不齐
- **建议**：创建文档模板（ADR、Runbook、技术规格等）

---

## 三、整理方案

### 3.1 新的目录结构（推荐）

```
docs/
├── README.md                          # 📚 文档总索引（新建）
├── CONTRIBUTING.md                    # 📝 文档贡献指南（新建）
├── templates/                         # 📋 文档模板（新建）
│   ├── adr-template.md
│   ├── runbook-template.md
│   ├── spec-template.md
│   └── roadmap-template.md
│
├── getting-started/                   # 🚀 快速开始（新建）
│   ├── README.md
│   ├── for-developers.md
│   ├── for-operators.md
│   └── for-product-managers.md
│
├── architecture/                      # 🏗️ 架构文档（新建）
│   ├── README.md
│   ├── overview.md                    # 从 harness-rust-flutter.md 提取
│   ├── tech-stack.md
│   ├── data-model.md
│   └── adr/                           # ADR 子目录
│       ├── README.md
│       ├── 001-me-api-version-negotiation.md
│       ├── 002-workspace-billing-attribution.md
│       ├── 003-workspace-billing-storage-model.md
│       └── 004-rust-backend-cloudflare-worker.md
│
├── api/                               # 🔌 API 文档（新建）
│   ├── README.md
│   ├── rest-api.md                    # 指向 OpenAPI
│   ├── websocket-events.md            # 从根目录移动
│   └── webhooks.md
│
├── features/                          # ✨ 功能文档（新建）
│   ├── README.md
│   ├── global-search.md               # 从根目录移动
│   ├── workspace/                     # Workspace 功能集合
│   │   ├── README.md
│   │   ├── overview.md
│   │   ├── team-collaboration.md
│   │   ├── billing.md
│   │   ├── permissions.md
│   │   └── security.md
│   ├── short-video/                   # 短视频功能
│   │   ├── README.md
│   │   ├── editing-guide.md
│   │   ├── shortcuts.md
│   │   └── light-editing-spec.md
│   └── harness/                       # Harness 功能
│       ├── README.md
│       ├── tools.md
│       └── wasm-runtime.md
│
├── development/                       # 💻 开发指南（新建）
│   ├── README.md
│   ├── backend-guide.md               # 从 backend/README.md 链接
│   ├── frontend-guide.md              # 从 frontend/README.md 链接
│   ├── testing.md
│   ├── debugging.md
│   └── code-style.md
│
├── operations/                        # 🔧 运维文档（重组）
│   ├── README.md
│   ├── runbooks/                      # 合并所有 runbooks
│   │   ├── README.md
│   │   ├── jobs-pg-queue.md
│   │   ├── harness-wasm-alert.md
│   │   ├── workspace-operations.md
│   │   ├── workspace-invite.md
│   │   ├── workspace-rls-validation.md
│   │   ├── billing-reconciliation.md
│   │   ├── billing-webhook-pii.md
│   │   ├── backfill-job-workspace-id.md
│   │   ├── export-s3-artifacts.md
│   │   └── short-video-optimization-smoke.md
│   ├── monitoring-and-logging.md      # 从根目录移动
│   ├── deployment.md
│   └── troubleshooting.md
│
├── migration/                         # 🔄 迁移文档（保持）
│   ├── README.md                      # 新建索引
│   ├── database-migrations.md
│   └── sqlite-to-supabase.md
│
├── roadmaps/                          # 🗺️ 路线图（重组）
│   ├── README.md
│   ├── master-roadmap.md              # harness-rust-flutter.md 重命名
│   ├── parity-audit.md                # electron-node-parity.md 等
│   ├── backend-harness.md
│   ├── flutter-shell.md
│   ├── jobs-saas.md
│   ├── workspace.md
│   ├── quality.md
│   └── platform-progress.md
│
├── security/                          # 🔒 安全文档（新建）
│   ├── README.md
│   ├── threat-models/
│   │   ├── harness-user-wasm.md
│   │   └── workspace-security-boundary.md
│   ├── workspace-invite-security-review.md
│   └── best-practices.md
│
├── product/                           # 📱 产品文档（新建）
│   ├── README.md
│   ├── deep-links.md                  # 从根目录移动
│   ├── ux/
│   │   ├── studio-competitive-ui-benchmark.md
│   │   ├── studio-design-tokens.md
│   │   └── studio-ix-covenant.md
│   └── specs/
│       ├── ai-drama-quality-token-memory.md
│       ├── model-pricing-prd.md
│       └── novel-intake-crawler-plan.md
│
├── quality/                           # ✅ 质量文档（新建）
│   ├── README.md
│   ├── quality-rubric.md
│   ├── testing-strategy.md
│   └── code-review-guidelines.md
│
└── legacy/                            # 📦 历史文档（新建）
    ├── README.md
    └── deprecated/                    # 已废弃文档
```

### 3.2 文档元数据标准（YAML Front Matter）

所有文档应包含以下元数据：

```yaml
---
title: 文档标题
status: draft | review | active | deprecated
created: 2026-05-19
updated: 2026-05-19
authors:
  - 作者名
reviewers:
  - 审核人
tags:
  - 标签1
  - 标签2
related:
  - path/to/related-doc.md
---
```

### 3.3 文档状态定义

| 状态 | 说明 | 标记 |
|------|------|------|
| `draft` | 草稿，内容未完成 | 🚧 |
| `review` | 审核中，等待反馈 | 👀 |
| `active` | 已完成，当前有效 | ✅ |
| `deprecated` | 已废弃，仅供参考 | ⚠️ |

---

## 四、执行计划

### 阶段 1：准备工作（1-2 天）
- [ ] 创建新的目录结构
- [ ] 创建文档模板
- [ ] 创建 `docs/README.md` 总索引
- [ ] 创建 `docs/CONTRIBUTING.md` 贡献指南

### 阶段 2：文档迁移（3-5 天）
- [ ] 迁移 ADR 文档到 `architecture/adr/`
- [ ] 迁移 Runbooks 到 `operations/runbooks/`
- [ ] 迁移 Workspace 文档到 `features/workspace/`
- [ ] 迁移路线图到 `roadmaps/`
- [ ] 迁移安全文档到 `security/`
- [ ] 迁移产品文档到 `product/`
- [ ] 迁移根目录文档到对应分类

### 阶段 3：内容优化（2-3 天）
- [ ] 为所有文档添加 YAML front matter
- [ ] 更新所有文档间的引用链接
- [ ] 合并重复内容
- [ ] 标记废弃文档并移动到 `legacy/deprecated/`
- [ ] 验证所有链接有效性

### 阶段 4：创建导航（1-2 天）
- [ ] 创建角色导向的快速开始指南
- [ ] 为每个子目录创建 README.md 索引
- [ ] 创建文档搜索索引（可选）
- [ ] 更新根目录 README.md 的文档链接

### 阶段 5：验证与发布（1 天）
- [ ] 运行链接检查工具
- [ ] 团队内部审核
- [ ] 更新 CI/CD 文档检查流程
- [ ] 发布公告

---

## 五、优先级建议

### 高优先级（立即执行）
1. 创建 `docs/README.md` 总索引
2. 合并所有 Runbooks 到 `docs/runbooks/`
3. 为核心文档添加状态标签
4. 修复失效的文档链接

### 中优先级（1-2 周内）
1. 重组 Workspace 文档
2. 创建角色导向的快速开始指南
3. 添加文档模板
4. 迁移 ADR 文档

### 低优先级（1 个月内）
1. 完整的目录重组
2. 创建文档搜索索引
3. 建立文档自动化检查流程

---

## 六、维护建议

### 6.1 文档审核流程
1. 新文档必须使用模板
2. 必须包含 YAML front matter
3. 必须经过至少一人审核
4. 必须更新相关索引文件

### 6.2 定期维护任务
- **每月**：检查并更新文档状态
- **每季度**：审核并归档过时文档
- **每半年**：全面审计文档结构

### 6.3 自动化工具
- 使用 `markdown-link-check` 检查链接
- 使用 `markdownlint` 检查格式
- 使用 CI/CD 自动验证文档

---

## 七、参考资料

- [Divio Documentation System](https://documentation.divio.com/)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [Write the Docs](https://www.writethedocs.org/)
- [The Documentation Compendium](https://github.com/kylelobo/The-Documentation-Compendium)

---

## 八、附录

### A. 文档清单（按当前位置）

#### docs/ 根目录（9 个）
1. global-search.md - 全局搜索功能文档
2. monitoring-and-logging.md - 监控和日志系统
3. product-deep-links.md - 产品深链接
4. README.en.md - 英文 README（与根 README 重复）
5. short-video-editing-shortcuts.md - 短视频编辑快捷键
6. short-video-editing-user-guide.md - 短视频编辑用户指南
7. task-center-rework-routing.md - 任务中心路由重构
8. websocket-events.md - WebSocket 事件协议
9. worker-workspace-validation.md - Worker Workspace 验证

#### docs/plans/（68 个）
**核心路线图（4 个）**
1. harness-rust-flutter.md - 主路线图
2. electron-node-parity.md - 功能对照表
3. master-detailed-parity-audit.md - 详细补漏审计
4. roadmap-index.md - 路线图总索引

**分方向路线图（7 个）**
5. roadmap-backend-harness.md
6. roadmap-flutter-shell.md
7. roadmap-jobs-saas.md
8. roadmap-parity-shipping.md
9. roadmap-quality.md
10. roadmap-repo-contract-infra.md
11. roadmap-workspace.md

**ADR（4 个）**
12. adr-me-api-version-negotiation.md
13. adr-rust-backend-cloudflare-worker.md
14. adr-workspace-billing-attribution.md
15. adr-workspace-billing-storage-model.md

**安全与威胁模型（3 个）**
16. harness-user-wasm-threat-model.md
17. workspace-security-boundary.md
18. workspace-invite-security-review.md

**运维手册（8 个在 plans/）**
19. jobs-pg-queue-runbook.md
20. harness-wasm-alert-runbook.md
21. billing-reconciliation-guide.md
22. billing-webhook-pii-runbook.md
23. workspace-operations-runbook.md
24. workspace-invite-runbook.md
25. workspace-sensitive-operations-runbook.md
26. workspace-rls-validation-runbook.md

**Workspace 计费（13 个）**
27. workspace-billing-cutover-runbook.md
28. workspace-billing-feature-flag-guide.md
29. workspace-billing-future-workspace-scope.md
30. workspace-billing-job-creation-audit.md
31. workspace-billing-migration-notice.md
32. workspace-billing-rollback-procedures.md
33. workspace-billing-rollback-runbook.md
34. workspace-billing-schema-rollback.md
35. workspace-billing-scope-decision.md
36. workspace-billing-staging-validation-checklist.md
37. workspace-migration-notice.md
38. workspace-release-checklist.md
39. workspace-team-full-plan.md

**Workspace 其他（6 个）**
40. workspace-observability-spec.md
41. workspace-project-permission-policy.md
42. workspace-rls-consistency-matrix.md
43. harness-ws-context-matrix.md
44. billing-webhook-retention-policy.md

**产品与 UX（5 个）**
45. short-video-light-editing-spec.md
46. moneyprinter-short-video-space.md
47. studio-competitive-ui-benchmark.md
48. studio-design-tokens.md
49. studio-ix-covenant.md

**技术专项（7 个）**
50. ai-drama-quality-token-memory-spec.md
51. http-api-cleanup.md
52. http-api-cleanup-h0-inventory.md
53. tasks-http-api-cleanup.md
54. tasks-pg-queue-observability.md
55. database-migration-history-policy.md
56. backend-domain-layer-review.md
57. ddd-full-migration-c.md

**质量与平台（5 个）**
58. quality-rubric.md
59. platform-capabilities-backlog.md
60. platform-config-plan-overrides.md
61. openflow-platform-progress.md
62. full-stack-delivery-covenant.md

**其他专项（9 个）**
63. novel-intake-crawler-plan.md
64. model-pricing-prd.md
65. assets-generate-job-payload-v2.md
66. ui-review-2026-05-18.md
67. ui-surface-inventory.md

#### docs/runbooks/（3 个）
68. backfill-job-workspace-id.md
69. export-s3-artifacts.md
70. short-video-optimization-smoke.md

#### docs/migration/（2 个）
71. database-migrations.md
72. sqlite-to-supabase.md

---

**总计：82 个文档文件（不含图片）**

