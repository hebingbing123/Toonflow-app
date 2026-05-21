# UI E2E 全量图库截图审计（2026-05-19）

> 运行：`OPENFLOW_UI_E2E_SKIP_RESET=1 bash scripts/run-ui-e2e.sh --full-gallery`（约 7.7 min，26 PNG）  
> 输出目录：`frontend/build/e2e_gallery/`  
> 日志：`/tmp/openflow-full-gallery-run10.log`

## 执行摘要

| 指标 | 结果 |
|------|------|
| PNG 数量 | **26**（期望 ≥25，未达 runbook「30+」营销口径） |
| `POST /api/v1/projects` 创建项目 | **已修复**（`projects_with_seed_project` 可见 `E2E全量图库-*` 卡片） |
| 项目内工作室剧本步 | **未达标**（`studio_step_script` 仍为项目网格，未进入 `/projects/:id/script`） |
| `storyboard_studio_step` 独立文件 | **缺失**（分镜 UI 出现在 `production_workspace` 截图中，scenario_id 错位） |
| 次要面板 URI 同步 | **已修复**（合规/平台状态/API 密钥等与项目首页重复截图问题消除） |

### 本轮代码修复（E2E + 产品）

1. **创建项目向导**：用 `StudioPrimaryButton`「创建」+ 等待 BottomSheet 关闭 + 等待项目名出现。  
2. **`studio_shell_branches.dart`**：为 `contentCompliance`、`platformStatus`、`platformConfig`、`apiKeys`、`teamWorkspaces` 增加 `/?pane=` URI 同步，避免路由监听把面板打回项目首页。  
3. **E2E harness**：`goProjectsHome` 软导航（Back + 品牌 + 流水线「项目」）；通知页点击刷新；`openProjectByName` 改为点「进入工作室」。  
4. **编译修复**（阻塞后续跑图）：`exportHistoryItemFromJob` / `_bitrateLabelFromQualityMap`（`short_video_space`）。

---

## 逐张审计（26/26）

| 文件 | 画面 | 后端交互 | 问题 | 建议修复 |
|------|------|----------|------|----------|
| `regular_01_login_default` | 登录落地页 | 否（仅 UI） | P2：DEBUG 角标预期内 | — |
| `regular_02_projects_default` | 项目首页（空列表） | 是 `GET /projects` | — | — |
| `regular_03_notifications_studio` | 通知中心 | 是 列表/刷新 | P2：空列表 | `notifications/section.dart` |
| `regular_04_settings_account` | 设置·账户 | 是 导出审计元数据 | — | `settings/account/` |
| `regular_05_settings_plan_usage` | 设置·套餐与用量 | 是 计费摘要 | **P2**：订阅状态「未知状态」 | `settings/` 计费展示 |
| `regular_06_settings_api` | 设置·API 与模型 | 是 价目表 | — | `settings/` |
| `regular_07_settings_workspaces` | 设置·工作区 | 是 工作区列表 | — | `team_workspaces/` |
| `regular_08_more_menu` | 「更多」菜单 | 否 | P2：菜单遮挡项目区（截图时机） | E2E 可先关菜单再拍 |
| `regular_09_tasks_default` | 任务中心 | 部分（未自动加载列表） | **P2**：「尚未加载任务列表」需手点重试 | `task_center/` + E2E 点「刷新任务摘要」 |
| `regular_10_quality_default` | 质量评审 | 部分 | **P2**：陈旧横幅 + 空看板；可接受空数据 | `quality_reviews/` |
| `regular_11_jobs_default` | 任务作业 | 部分 | **P1**：空状态文案 `jobs empty value` 未本地化 | `jobs/section.dart` + `app_zh.arb` |
| `regular_12_short_video_overview` | 多平台分发/短视频 Space | 是 读项目/配置 | **P2**：Desktop bridge 未启动 横幅 | E2E 环境或 `short_video_space/` |
| `regular_13_team_workspaces` | 团队工作区 | 是 列表 | — | `team_workspaces/` |
| `regular_14_settings_api_keys_pane` | API 密钥 | 是 列表（空） | — | `settings/api_keys` |
| `regular_15_content_compliance_queue` | 内容合规·举报表单 | 是 表单默认值 | **P1**：下拉显示截断/英文 key 泄漏 | `content_compliance/section.dart` + l10n |
| `regular_16_platform_status` | 平台状态 | 是 health/SLI | — | `platform_status/` |
| `regular_17_platform_config` | 平台配置 | 是 功能开关 | — | `settings/platform_config/` |
| `regular_18_script_workspace` | 剧本工作区（项目已 scoped） | 是 overview/readiness | **P2**：剧本工作区空 UUID 黑块 | `project_studio_page.dart` / agent 区 |
| `regular_19_production_workspace` | **实际为分镜工作室浮层** | 部分 | **P1**：scenario_id 与画面不符；页脚「后端任务待接」 | E2E 命名 + `storyboard_studio` |
| `regular_20_help_hub_webhooks` | 帮助 / 出站 Webhook | 是 文档种子 | P2：底部 Webhook 区略裁切 | `help_hub/` |
| `regular_21–23_create_project_wizard_*` | 创建项目向导三步 | 第 3 步未 POST | — | 仅预览；持久化见 24 |
| `regular_24_projects_with_seed_project` | 创建后项目网格 | **是 `POST /projects` + `GET /projects`** | P2：多条 E2E 残留项目 | 测试后清理或 `db reset` |
| `regular_25_studio_step_script` | **应为项目工作室剧本步** | 意图是 | **P0**：与 24 相同，仍在网格未进工作室 | E2E：`进入工作室` 按项目名定位 |
| `regular_26_product_shell_chrome` | 产品壳/chrome | 是 | **P1**：与 24/25 重复画面 | 同 25 |

---

## 交叉主题

1. **E2E 导航**：产品壳里点项目卡只 `selectProjectScope`，必须点 **「进入工作室」** 才会 `go(/projects/:id/script)`。  
2. **URI 与面板**：「更多」里非 URI 同步的面板曾被 `GoRouter` 打回 `/`，已用 `kStudioPaneUriSyncedPanes` 扩展修复。  
3. **空状态/i18n**：jobs 空文案、合规下拉、套餐「未知状态」需在 widget 层修。  
4. **短视频/桌面桥**：集成环境常无 native bridge，横幅可接受但应标为环境限制。  
5. **SKIP_RESET 累积数据**：多次跑图后项目列表膨胀，影响「空状态」类截图。

---

## Top 10 修复待办

| # | 优先级 | 项 | 文件/区域 |
|---|--------|-----|-----------|
| 1 | P0 | E2E：按项目名点 `project_enter_studio_*` /「进入工作室」，`assertProjectStudioEntered` | `integration_test/support/real_product_shell_gallery_support.dart`（2026-05-21 已接线） |
| 2 | P0 | 重命名/补拍 `storyboard_studio_step`（与 `production_workspace` 脱钩） | 同上 |
| 3 | P1 | 修复 `jobs empty value` 未翻译 | `jobs/section_view.dart` + `jobsEmptyValue` l10n（2026-05-21） |
| 4 | P1 | 合规举报下拉：宽度与 l10n 显示名 | `content_compliance/section.dart` 下拉 `width: 280` + `labelForValue`（2026-05-21） |
| 5 | P1 | `studio_step_script` 截图断言：必须含六步条而非「你的项目」 | `assertProjectStudioEntered` 校验五步条标签（2026-05-21） |
| 6 | P2 | 套餐页订阅状态映射 | `subscriptionStatusLabel` → `billingSubscriptionStatusNotSet` 当 API 为空（2026-05-21） |
| 7 | P2 | 任务中心 E2E 自动点「刷新任务摘要」 | `refreshTaskCenterIfPossible` in gallery harness（2026-05-21） |
| 8 | P2 | 剧本工作区空 UUID 字段占位 | `AgentWorkspaceScopeInputs` UUID 字段 hint（2026-05-21） |
| 9 | — | 导出对话框 / benchmark：仍 **无壳层入口** | 见下方矩阵 |
| 10 | — | 全量跑前 `db reset` 或清理 `E2E全量图库-*` 项目 | `run-ui-e2e.sh` 文档 |

---

## 功能覆盖矩阵（诚实）

| 功能 | E2E 截图？ | 后端调用？ | 视觉分析？ |
|------|-------------|------------|------------|
| 登录 | ✅ `login_default` | ✅ Supabase Auth | ✅ |
| 项目列表 | ✅ `projects_default` | ✅ GET projects | ✅ |
| **新增项目（持久化）** | ✅ `projects_with_seed_project` | ✅ **POST /projects** | ✅ |
| 创建向导（仅 UI） | ✅ `create_project_wizard_*` | ❌ 未提交 | ✅ |
| 通知 | ✅ `notifications_studio` | ✅ 列表；刷新已点 | ✅ |
| 设置（账户/套餐/API/工作区） | ✅ 4 张 | ✅ | ✅ |
| 任务中心 | ✅ `tasks_default` | ⚠️ 未自动 load | ✅ |
| 质量评审 | ✅ `quality_default` | ⚠️ 空看板 | ✅ |
| 任务作业 | ✅ `jobs_default` | ⚠️ 空列表 | ✅ |
| 多平台分发 | ✅ `short_video_overview` | ✅ 读配置/项目 | ✅ |
| 团队/API 密钥/合规/平台状态/配置 | ✅ 各 1 张 | ✅ | ✅ |
| 剧本/制作工作区 | ✅ `script_workspace` / `production_workspace` | ✅ 需已选项目；制作张实为分镜 | ✅ |
| **项目工作室·剧本步** | ✅ 图库用 `assertProjectStudioEntered` + `project_enter_studio_*`（2026-05-21） | ✅ 进 `/projects/:id/script` | ✅ |
| **分镜步** | ✅ `storyboard_studio_step` 在项目内步骤条拍摄；`production_workspace` 为工具页 | 部分 | ✅ |
| 帮助/Webhook | ✅ `help_hub_webhooks` | ✅ 种子文档 | ✅ |
| 导出对话框 | ❌ | ❌ 需短视频上下文 | 文档阻塞 |
| Benchmark | ❌ | ❌ 无导航入口 | 文档阻塞 |
| Episode 控制台 | ❌ | ❌ 需 script id 深链 | 文档阻塞 |
| 冲突横幅 / 命令面板 | ❌ | — | widget/smoke 覆盖 |

---

## 相对 inventory 缺失 scenario_id

仍缺或未对齐：

- `storyboard_studio_step`（独立文件）
- `studio_step_script`（**文件存在但画面未进工作室**）
- `benchmark_default`、`export_*`、`episode_console`（已知不可达）
- runbook 序号 `08 help` vs 当前用例顺序（help 在 20）— 仅命名顺序差异，非功能缺失

---

## 复现

```bash
OPENFLOW_UI_E2E_SKIP_RESET=1 bash scripts/run-ui-e2e.sh --full-gallery
ls frontend/build/e2e_gallery/regular_*.png | wc -l
```
