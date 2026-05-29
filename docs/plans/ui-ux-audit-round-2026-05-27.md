# UI/UX 全站审计与修复计划（2026-05-27）

## 目标

从**真实用户视角**检查 OpenFlow Flutter 产品壳：视觉层级、间距、字号、颜色一致性、按钮可点性、空/错/加载态、交互反馈、响应式布局；覆盖 **桌面 macOS**、**窄 Web/手机视口**（375×667）与关键弹窗/Sheet。

## 方法（禁止 Playwright 扫 Flutter Web 画布）

| 阶段 | 手段 | 产出 |
|------|------|------|
| A. 截图审计 | `bash scripts/run-ui-ux-audit-e2e.sh`（macOS `integration_test`） | `.codex/skills/ui-ux-audit/output/e2e/{desktop,mobile}/*.png` |
| A′. 截图自动筛查 | `bash scripts/analyze-ui-ux-audit-screenshots.sh` | 校验分辨率、文件大小（过小≈黑屏/空帧）、列清单供人工扫 |
| B. 静态门禁 | `bash scripts/studio-visual-debt-check.sh` | 禁止 raw Colors、10/11px、业务层 shrinkWrap 热区 |
| C. 规范对照 | `docs/product/ux/studio-visual-guidelines.md`、`frontend/lib/design_system/` | issues.json 维度标签 |
| D. 修复实施 | 按 P0→P1→P2 分批改 `frontend/lib/` | 本计划下方「实施批次」 |

**说明**：Cursor 内置浏览器无法渲染 `flutter-view`，**不作为** UI 验收依据。

## 视口与路由覆盖（E2E 清单）

- **Desktop** 1920×1080 / **Mobile** 375×667
- 登录、项目首页、通知、设置 Hub（账户/用量/API/工作区）
- 更多菜单、任务中心、质量、作业队列、短视频、团队、API 密钥、合规、平台状态/配置
- 脚本/制作 Agent 工作区、帮助 Hub
- 新建项目向导、种子项目工作室（脚本/美术/分镜步）
- **交互 PNG**：创建项目 Sheet、更多菜单、API 密钥 Dialog、合规/帮助/平台配置、任务/短视频/通知筛选与 Dialog

## 审计维度 → 检查项

1. **visual_hierarchy** — 单屏一个主 CTA；AppBar / 流水线 / 内容区分
2. **spacing** — 8px 网格、`StudioLayoutSpacing`、避免游离 magic number
3. **typography** — `StudioTypography` / `studioControlLabelStyle`，无 10/11px
4. **color_consistency** — `StudioTokens` / `ThemeData`，禁止业务 `Colors.*`
5. **touch_targets** — 工具栏/表单 `studioForm*`（~36px）；图标 `studioUtilityIconButtonStyle`（44px）
6. **empty_loading_error** — `StudioEmptyState` / `StudioApiErrorCallout`，非裸 `Text`
7. **interaction_feedback** — disabled/hover/splash；危险操作用 `studioFormDestructive*`
8. **responsive_layout** — `layout_breakpoints.dart` 常量，手机单列、Shell 堆叠顶栏
9. **modal_dialog_patterns** — `StudioAlertDialog` / Sheet；移动用 BottomSheet

## 已知问题登记（实施前）

| ID | 优先级 | 维度 | 页面/区域 | 问题 | 修复方向 |
|----|--------|------|-----------|------|----------|
| UXR-01 | P2 | touch_targets | 美术步 `art_step_panel` | `TextButton.icon` 使用 `VisualDensity.compact` + 过小 padding | 统一 `studioFormIconLabeledButtonStyle`（TextButton 合并） |
| UXR-02 | P2 | color_consistency | 旅程紧凑条 `creator_journey_compact_bar` | 部分 `TextButton.icon` 未走 form/toolbar token | 对齐 `studioFormButtonStyle` / 44px 图标区 |
| UXR-03 | P2 | interaction_feedback | 全局搜索/通知/合规 | 次要 `TextButton.icon` 样式漂移 | 批量套用 form icon 样式 |
| UXR-04 | P1 | empty_loading_error | 项目列表/API 失败 | 红条 `Failed to fetch`（后端未起或鉴权） | 运维：8666 + Supabase；UI 已有 `StudioApiErrorCallout` |
| UXR-05 | P2 | responsive_layout | 项目首页 mobile | 窄屏卡片/顶栏堆叠需对照 mobile PNG | E2E 截图后微调 `projects/section.dart` |
| UXR-06 | P2 | modal_dialog_patterns | 多模块 Dialog 主按钮 | 零星 `FilledButton` 无 `studioFormPrimaryButtonStyle` | 扫尾对齐（workbench、短视频、合规） |

## 实施批次（本轮）

### 批次 1 — 控件 token 扫尾（已完成 2026-05-27）

- 新增 `studioFormTextButtonIconStyle`
- 已改：美术步、合规队列、全局搜索（结果/历史）、通知「加载更多」
- 扫尾完成：旅程紧凑条、`studio_api_error_callout`、合规/通知/团队工作区表单图标按钮；Dialog 主按钮已对齐 `studioFormPrimaryButtonStyle`（含短视频确认框）

### 批次 2 — 响应式（E2E 截图后，已完成 2026-05-27）

- **流水线条**：`width < 760` 改为纵向堆叠；手机步骤 chip **仅图标 + Tooltip**
- **Shell**：手机内容区内边距 16→12
- **Pane 头**：`shortestSide < 600` 时标题与 trailing 操作分行
- **任务中心**：操作栏断点对齐 `kStudioHandsetMaxWidth`
- **项目空态**：手机入门步骤 `maxWidth: infinity`

### 批次 2.5 — 顶栏工作区/项目上下文（已完成）

- **原因**：`titleBarWorkspaceContext` 原先与 `showPipeline` 绑定；进入设置/通知/API 密钥等 **无 pipeline** 的 pane 时，顶栏左侧工作区与项目摘要被整段拿掉。
- **修复**：已登录产品壳内 **始终** 构建 `_buildWorkspaceContextSection` 注入顶栏；`shouldShowStudioPipeline` 仍只控制下方 `StudioPipelineStrip` 显隐。
- **验收**：`dart analyze lib/shell/build_product_shell.dart` 通过；设置页顶栏应仍显示「工作区 · 项目」摘要行。

### 批次 2.6 — E2E 设置 Tab 截图（已完成）

- **现象**：`regular_04`～`regular_07` 四张设置 Hub 截图 **SHA256 完全相同**（已用 `shasum` 验证）。
- **根因**：`openSettingsTabByIndex` 在 `StudioSettingsHubNavigation.requestTab` 之后调用 `goProjectsHome()`，子树在 `consumePending` 前卸载，pending 丢失，始终落在默认「账户」Tab。
- **修复**：已在 `real_product_shell_gallery_support.dart` 改为在 **TabBar 已就绪时直接点 Tab 标签**（中英），并 `ensureVisible` 以适配可滚动 Tab；`analyze-ui-ux-audit-screenshots.sh` 增加重复哈希摘要。

### 批次 3 — 空态与错误态（已完成 2026-05-28）

- 通知合规导出/审计列表：首屏加载改用 `StudioListSkeleton`（非 pane 级 CPI）
- 管理台搜索：查询中展示 `StudioListSkeleton`
- 队列/列表统一 `StudioEmptyState` + 重试 CTA 高度
- 登录/项目空态去重复 banner（矩阵 UX-06 已做，回归 E2E）
- Agent 上下文：[`frontend/lib/design_system/UI_REFACTOR_CONTEXT.md`](../../frontend/lib/design_system/UI_REFACTOR_CONTEXT.md)

## 验收

```bash
bash scripts/run-ui-ux-audit-e2e.sh   # desktop+mobile PNG ≥ 阈值
bash scripts/analyze-ui-ux-audit-screenshots.sh
bash scripts/studio-visual-debt-check.sh
cd frontend && flutter analyze
```

**E2E 回归（2026-05-28）**：`run-ui-ux-audit-e2e.sh` 绿（mobile 20 routes / 7 interactions，desktop 21 routes / 7 interactions）；`analyze-ui-ux-audit-screenshots.sh` 无过小 PNG。Harness 修复：嵌套滚动 `team_workspaces`、overlay 后 `ensureAuditShellReady`、Hero 收尾泵帧、429 时小说导入 checkpoint 不抛错。

问题清单：`.codex/skills/ui-ux-audit/output/issues.json`  
修复后更新 `fixPlanReady: true` 与 `summary.byPriority`。

**2026-05-28 backlog 字面 100%**：B1 `project_editor` 剩余竖切（plan workbench、novel sections、asset launchers）Enter 键盘；`studioFormButtonLabelMetrics` 修复浅色主按钮字色；UXR `TextButton.icon` 高流量 token；E2E + golden 回归绿。
