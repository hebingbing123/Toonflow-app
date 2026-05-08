# 平台级能力补遗（全栈任务池，与路线图正交）

**用途**：主路线图（`harness-rust-flutter`、`roadmap-*`、[`workspace-team-full-plan.md`](./workspace-team-full-plan.md)）已覆盖 **核心产品链**；本文件收集 **平台级** 常见能力，避免「文档里从未出现 → 团队以为不用做」。  
**交付**：每条默认 **Rust + OpenAPI（如适用）+ Flutter（或 Web 管理端）**；参见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

**状态**：`planned`（未排期）— 纳入某 Phase 时在对应主计划打勾并在此更新链接。

---

## A. 用户可感知与账户

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-A1 | **应用内通知中心**（任务完成、成员邀请、计费事件摘要） | 事件表或复用 WS + REST 列表 | 铃铛/列表、已读、深链跳转 | 可与 jobs/billing 事件对齐 |
| P-A2 | **全局搜索**（跨项目标题、剧本、资产元数据） | 搜索 API + 索引策略（PG `tsvector` 或外包） | 统一搜索框、结果分组 | 注意权限按 workspace |
| P-A3 | **账户：导出数据 / 删除账号**（合规） | 异步导出 job + 下载链接；删号 CASCADE 策略 | 设置页危险操作 + 二次确认 | GDPR 类诉求 |
| P-A4 | **功能开关 / 远程配置**（按 plan 或 workspace） | 配置 API + 缓存 | 客户端拉取与 UI 灰显 | 与 feature flag Runbook 联动 |

---

## B. 集成与自动化（「平台」对外接口）

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-B1 | **用户级或 workspace 级 API Key**（只读/读写 scope） | 签发、哈希存储、轮换、审计 | 设置页管理 keys、展示一次明文 | 与限流、审计联动 |
| P-B2 | **出站 Webhook**（项目状态、任务完成 → 客户 URL） | 注册 URL、签名校验、重试、死信 | 配置 UI + 测试投递按钮 | **tracked**：已落地最小版（settings CRUD + test 投递 + 迁移），commit `09bf5190` |
| P-B3 | **公开只读 Status / Health 页**（非鉴权或弱鉴权） | 聚合 `/health`、队列深度、依赖项 | 静态页或 Flutter Web 路由 | **tracked**：已新增 Flutter `/status` 页，公开聚合 `/health` / `/api/v1/health` / `/api/v1/ready` / `/api/v1/version`，并在带 `INTERNAL_OPS_TOKEN` 时附加队列统计；见 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) WP-E |

---

## C. 运营与治理

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-C1 | **管理台扩展**（超越 billing events 列表） | 用户/空间只读、封禁、配额调整 API | 内部路由或独立 build | RBAC 须极严 |
| P-C2 | **内容与合规队列**（举报、人工审核） | 表 + 工作流 API | 审核台 UI | 母文档 § 合规提及 |
| P-C3 | **审计日志用户可见切片**（「谁改了我的项目」） | 读模型 API | 项目设置 / 活动时间线 | 与 W2.7 审计表可共用 |

---

## D. 体验与国际化

| ID | 能力 | Backend | Flutter / 产品面 | 备注 |
|----|------|---------|-------------------|------|
| P-D1 | **产品文案 i18n 收口**（中英至少） | 错误码 `message` 多语言可选 | `l10n` 全覆盖主路径 | 与 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) 联动 |
| P-D2 | **应用内帮助 / 文档 Hub** | 深链或 CDN 文档 URL 配置 | 帮助抽屉、外链 WebView | **tracked**：已落地最小版（env 驱动 links + settings endpoint + Flutter pane），commit `d0ba94f2` |
| P-D3 | **429 / 配额耗尽统一 UX** | 统一 `code` + `Retry-After` | 全局拦截器 + Snackbar/对话框 | **tracked**：已接入共享 `rust_api_feedback` 处理层与 Projects / Jobs / Task Center / Team Workspaces / System Probes 主路径；见 [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) WP-D |

---

## E. 纳入主计划的提示

将上表某行 **排入迭代** 时：

1. 在对应 **`roadmap-*`** 或 **`workspace-team-full-plan`** 增加 WP 或子节；  
2. 本表该行列状态改为 **`tracked`** 并写上 **文档锚点**；  
3. 合并仍须满足 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

---

*审阅节奏：每季度扫一遍本表与 `harness-rust-flutter` 正文 §，补漏不重复造轮子。*
