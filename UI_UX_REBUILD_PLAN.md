# AI 短剧平台：全端 UI/UX 架构重构实施计划书

> **真源链**：[`frontend/lib/design_system/UI_REFACTOR_CONTEXT.md`](frontend/lib/design_system/UI_REFACTOR_CONTEXT.md) → [`docs/plans/flutter-ui-ux-refactor-18-phases.md`](docs/plans/flutter-ui-ux-refactor-18-phases.md) → [`docs/plans/flutter-ui-ux-refactor-signoff.md`](docs/plans/flutter-ui-ux-refactor-signoff.md)

---

## 一、项目现状评估

### 1.1 已具备的基础设施（不必重复建设）

| 领域 | 现状 | 真源 |
|------|------|------|
| 设计系统 | `StudioTokens` / `buildStudioTheme`、8px 间距、圆角 token、visual-debt 门禁 | [`tokens.dart`](frontend/lib/design_system/tokens.dart)、[`theme.dart`](frontend/lib/design_system/theme.dart) |
| 响应式框架 | 双断点体系：`StudioBreakpoint`（四档）+ `StudioWidthTier`（三档）；`StudioResponsiveLayout` | [`layout_breakpoints.dart`](frontend/lib/design_system/layout_breakpoints.dart)、[`studio_responsive_layout.dart`](frontend/lib/design_system/studio_responsive_layout.dart) |
| 异步三态 | `StudioAsyncDataView` + 骨架屏族；禁止整页 CPI | [`ASYNC_LOADING.md`](frontend/lib/design_system/ASYNC_LOADING.md) |
| 组件库 | Tier 1–4 组件已导出；防抖、乐观 UI、传输队列 | [`components/studio.dart`](frontend/lib/design_system/components/studio.dart) |
| 参考实现 | 分镜工作室已实现 handset drill-down + desktop 三栏 | [`storyboard_studio_page.dart`](frontend/lib/storyboard_studio/storyboard_studio_page.dart) |

Kiro 任务 1–30 与 signoff 第二十六轮已声明 **A 类（规范+门禁）与 B 类高收益扫尾已交付**。本计划 **不推翻** 已有设计系统，而是 **补齐短剧业务链路与 18 阶段指南之间的断层**。

### 1.2 与 18 阶段指南的冲突点（按严重度）

| 冲突类别 | 具体表现 | 涉及文件 |
|----------|----------|----------|
| **跨端布局红线（阶段 4）** | `ShortVideoSpaceView` 以 `SingleChildScrollView` + `Column` 纵向堆叠；仅 `>=1100px` 局部双列、`>=960px` 组装 input\|export 并排；**无** persistent 镜头轨\|预览\|操作三栏 | [`view.dart`](frontend/lib/short_video_space/view.dart)、[`view_production_panel.dart`](frontend/lib/short_video_space/view_production_panel.dart)、[`section.dart`](frontend/lib/short_video_space/section.dart) |
| **9:16 沉浸预览缺失（阶段 4/7）** | 项目默认 `_videoRatio = '9:16'`，但 `PreviewPlayer` 硬编码 `aspectRatio: 16/9`；**全库零 import** | [`preview_player.dart`](frontend/lib/short_video_space/components/preview_player.dart)、[`section_timeline.dart`](frontend/lib/short_video_space/section_timeline.dart) |
| **AI 生成状态反馈断层（阶段 3/10）** | Video Step 仅分段按钮 + Agent 面板，无预览区；时间线预览 `launchUrl` 外部打开 | [`studio_video_step_panel.dart`](frontend/lib/project_studio/studio_video_step_panel.dart)、[`section_production_assembly.dart`](frontend/lib/short_video_space/section_production_assembly.dart) |
| **UI 硬编码残留（阶段 1）** | DS 组件内零散魔法数；`StudioButton` variant 未实现 | [`studio_button.dart`](frontend/lib/design_system/components/studio_button.dart) |
| **交互反馈漂移（阶段 2）** | `projects_grid_view.dart` 裸 `GestureDetector` 未登记豁免 | [`projects_grid_view.dart`](frontend/lib/project_studio/projects_grid_view.dart) |
| **持续治理（阶段 11/14/18）** | ~~除 Benchmark 外无首屏 deferred；`view.dart` 2100+ 行~~ → 已竖切 `view_*` / `section_*` part 模块，目录内无单文件 >800 行；`deferred_section.dart` 已接入 | [`view.dart`](frontend/lib/short_video_space/view.dart)、[`deferred_section.dart`](frontend/lib/short_video_space/deferred_section.dart) |

**结论**：设计系统层已成熟，**业务层短剧链路是最大短板**——尤其是移动端 9:16 沉浸与 PC 多栏编辑。

---

## 二、多端差异化布局专项

### 2.1 手机端（Mobile，width < 600）

**目标**：9:16 沉浸式短剧预览 + 底部单手创作流

| 能力 | 目标方案 |
|------|----------|
| 预览画幅 | `PreviewPlayer` 接受 `videoRatio`；`9:16` → `AspectRatio(9/16)` |
| 沉浸全屏 | `ImmersivePreviewPage`：全屏 `PreviewPlayer` + `StudioSystemUiSurface` |
| 创作流 | 底部固定创作 Dock + 上滑参数 Sheet |
| 镜头切换 | 全屏模式 PageView 滑切镜头 |

### 2.2 PC/Web 端（width >= 960）

**目标**：三栏 Master-Detail（左镜头轨、中参数、右预览）

| 栏位 | 内容 | 宽度建议 |
|------|------|----------|
| 左栏（Master） | 镜头轨 / 候选列表 / 发布草稿列表 | flex: 2 |
| 中栏（Detail） | 脚本摘要、生成参数、平台文案 | flex: 4 |
| 右栏（Preview） | `PreviewPlayer` + 导出/排期操作 | flex: 4 |

---

## 三、优先级矩阵（P0–P2）

### P0 — 短剧跨端体验红线

| 任务 | 原阶段 | 理由 |
|------|--------|------|
| `ShortVideoResponsiveShell`；PC 三栏 / Mobile 沉浸壳 | 4 | 最大架构断层 |
| `PreviewPlayer` 支持 `videoRatio`；接线 timeline/候选/组装 | 4 | 组件已写好但未用 |
| Mobile `ImmersivePreviewPage` + 底部创作 Dock | 4 | 短剧核心场景 |
| 短剧链路 AI 生成态统一骨架屏与错误页 | 3 | 生成等待体验 |
| 生成/导出/批量发布按钮防抖 + loading | 10 | 防重复触发 |

### P1 — 体验增强

Hero 动画、PC hover/焦点、haptic、GestureDetector 清理、表单 Shake、拆分 `view.dart`、`StudioButton` variant。

### P2 — 持续治理

const/RepaintBoundary、deferred 首屏、分端高清资产、文档修正、测试覆盖。

---

## 四、文件影响清单

### 批次 A：P0 跨端壳 + 预览接线

- `frontend/lib/short_video_space/layout/short_video_responsive_shell.dart`（新建）
- `frontend/lib/short_video_space/layout/short_video_desktop_shell.dart`（新建）
- `frontend/lib/short_video_space/layout/short_video_mobile_shell.dart`（新建）
- `frontend/lib/short_video_space/routes/immersive_preview_page.dart`（新建）
- `frontend/lib/short_video_space/components/preview_player.dart`（改造）
- `frontend/lib/short_video_space/section.dart`、`view.dart`、`section_timeline.dart` 等

### 测试与门禁

```bash
bash scripts/studio-visual-debt-check.sh
cd frontend && flutter test test/short_video_space/
yarn refactor:agent --quick
```

---

## 五、P0 核心切入点

1. **阶段 4 跨端布局**：Short Video Space → Mobile 9:16 沉浸壳 + PC 三栏 Master-Detail
2. **PreviewPlayer 接线**：接入 `videoRatio`，替换 timeline 外部浏览器预览
3. **阶段 3 AI 生成三态**：统一 `StudioAsyncDataView` 骨架屏与友好错误页
4. **阶段 10 生成防抖**：短剧生成/导出/批量发布全路径 `StudioDebouncedAction`

---

## 六、交付状态（2026-05）

| 批次 | 状态 | 说明 |
|------|------|------|
| P0 跨端壳 + 预览 | ✅ | `ShortVideoResponsiveShell`、`ImmersivePreviewPage`、`PreviewPlayer` `videoRatio` |
| P0 异步三态 | ✅ | `_ShortVideoPanelFetchBody`、`StudioAsyncDataView` 覆盖生产/导出/发布/时间线等 |
| P0 防抖 | ✅ | 生成/导出/发布/配音/TTS/项目配置等 mutation 按钮已接 `StudioDebouncedAction` |
| P1 拆分与增强 | ✅ | `view.dart` / `section*` / `support_publish_*` 等巨石文件已竖切 |
| P2 治理 | ✅ | deferred 首屏、文档同步、53 项短剧+PreviewPlayer 测试绿 |

合并前建议：`cd frontend && flutter analyze lib/short_video_space/` + `yarn refactor:agent --quick`（用户未要求 commit 时不自动提交）。
