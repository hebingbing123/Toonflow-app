# AI 短剧平台：全端 UI/UX 架构重构实施计划书

> **真源链**：[`frontend/lib/design_system/UI_REFACTOR_CONTEXT.md`](../../frontend/lib/design_system/UI_REFACTOR_CONTEXT.md) → [`flutter-ui-ux-refactor-18-phases.md`](flutter-ui-ux-refactor-18-phases.md) → [`flutter-ui-ux-refactor-signoff.md`](flutter-ui-ux-refactor-signoff.md)

---

## 一、项目现状评估

### 1.1 已具备的基础设施（不必重复建设）

| 领域 | 现状 | 真源 |
|------|------|------|
| 设计系统 | `StudioTokens` / `buildStudioTheme`、8px 间距、圆角 token、visual-debt 门禁 | [`tokens.dart`](../../frontend/lib/design_system/tokens.dart)、[`theme.dart`](../../frontend/lib/design_system/theme.dart) |
| 响应式框架 | 双断点体系：`StudioBreakpoint`（四档）+ `StudioWidthTier`（三档）；`StudioResponsiveLayout` | [`layout_breakpoints.dart`](../../frontend/lib/design_system/layout_breakpoints.dart)、[`studio_responsive_layout.dart`](../../frontend/lib/design_system/studio_responsive_layout.dart) |
| 异步三态 | `StudioAsyncDataView` + 骨架屏族；禁止整页 CPI | [`ASYNC_LOADING.md`](../../frontend/lib/design_system/ASYNC_LOADING.md) |
| 组件库 | Tier 1–4 组件已导出；防抖、乐观 UI、传输队列 | [`components/studio.dart`](../../frontend/lib/design_system/components/studio.dart) |
| 参考实现 | 分镜工作室已实现 handset drill-down + desktop 三栏 | [`storyboard_studio_page.dart`](../../frontend/lib/storyboard_studio/storyboard_studio_page.dart) |

Kiro 任务 1–30 与 signoff 第二十六轮已声明 **A 类（规范+门禁）与 B 类高收益扫尾已交付**。本计划补齐短剧业务链路与 18 阶段指南之间的断层。

### 1.2 原冲突点与当前状态

| 冲突类别 | 原表现 | 当前状态 |
|----------|--------|----------|
| **跨端布局（阶段 4）** | 纵向堆叠、无 persistent 三栏 | ✅ `ShortVideoResponsiveShell`：PC 三栏 + Mobile 沉浸壳 |
| **9:16 沉浸预览（阶段 4/7）** | `PreviewPlayer` 硬编码 16:9 | ✅ `videoRatio` 接线 timeline/候选/组装；`ImmersivePreviewPage` |
| **AI 生成三态（阶段 3/10）** | 外链预览、缺骨架/错误页 | ✅ `_ShortVideoPanelFetchBody` + 生产/导出/发布/时间线覆盖 |
| **防抖（阶段 10）** | 生成/导出重复触发 | ✅ 短剧 mutation 路径 `StudioDebouncedAction` |
| **巨石文件（阶段 11/14/18）** | `view.dart` 2100+ 行 | ✅ `view_*` / `section_*` part 竖切，目录内无单文件 >800 行 |
| **持续治理** | 无 deferred 首屏 | ✅ `deferred_section.dart`；`StudioButton` variant 已落地 |
| **待观察（非阻塞）** | Video Step 预览区、部分 GestureDetector 豁免登记 | 🟡 见 [`flutter-ui-ux-refactor-18-phases.md`](flutter-ui-ux-refactor-18-phases.md) C 类 |

---

## 二、多端差异化布局专项

### 2.1 手机端（Mobile，width < 600）

| 能力 | 方案 |
|------|------|
| 预览画幅 | `PreviewPlayer` + `videoRatio` → `AspectRatio(9/16)` |
| 沉浸全屏 | `ImmersivePreviewPage` + `StudioSystemUiSurface` |
| 创作流 | 底部创作 Dock + 上滑参数 Sheet |
| 镜头切换 | 全屏 PageView / 播放列表 |

### 2.2 PC/Web 端（width >= 960）

| 栏位 | 内容 | 宽度建议 |
|------|------|----------|
| 左栏（Master） | 镜头轨 / 候选 / 发布草稿 | flex: 2 |
| 中栏（Detail） | 脚本摘要、生成参数、平台文案 | flex: 4 |
| 右栏（Preview） | `PreviewPlayer` + 导出/排期 | flex: 4 |

---

## 三、优先级矩阵（P0–P2）

### P0 — 短剧跨端体验红线

| 任务 | 状态 |
|------|------|
| `ShortVideoResponsiveShell`；PC 三栏 / Mobile 沉浸壳 | ✅ |
| `PreviewPlayer` `videoRatio`；接线 timeline/候选/组装 | ✅ |
| `ImmersivePreviewPage` + 底部创作 Dock | ✅ |
| 短剧链路异步三态（骨架屏 / 错误页） | ✅ |
| 生成/导出/批量发布防抖 | ✅ |

### P1 — 体验增强

Hero、PC hover/焦点、haptic、表单 Shake、`view.dart` 拆分、`StudioButton` variant — **已交付主链路**。

### P2 — 持续治理

const/RepaintBoundary、deferred 首屏、分端资产、文档与测试 — **已交付基线**。

---

## 四、关键路径索引

```
frontend/lib/short_video_space/
  layout/short_video_responsive_shell.dart
  routes/immersive_preview_page.dart
  view.dart + view_shell_widgets.dart      # _ShortVideoPanelFetchBody
  section_build*.dart                       # section 竖切
  components/preview_player*.dart
```

### 测试与门禁

```bash
bash scripts/studio-visual-debt-check.sh
cd frontend && flutter test test/short_video_space/ test/preview_player_test.dart
yarn refactor:agent --quick
```

---

## 五、交付状态（2026-05）

| 批次 | 状态 | 说明 |
|------|------|------|
| P0 跨端壳 + 预览 | ✅ | `ShortVideoResponsiveShell`、`ImmersivePreviewPage`、`PreviewPlayer` `videoRatio` |
| P0 异步三态 | ✅ | `_ShortVideoPanelFetchBody`、`StudioAsyncDataView` 覆盖生产/导出/发布/时间线等 |
| P0 防抖 | ✅ | 生成/导出/发布/配音/TTS/项目配置等 mutation 已接 `StudioDebouncedAction` |
| P1 拆分与增强 | ✅ | `view.dart` / `section*` / `support_publish_*` 等巨石文件已竖切 |
| P2 治理 | ✅ | deferred 首屏、文档同步、53 项短剧+PreviewPlayer 测试绿 |
