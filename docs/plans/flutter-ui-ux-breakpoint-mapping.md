# Flutter UI/UX — 断点对照表

Kiro 规格（[requirements.md](../../.kiro/specs/flutter-ui-ux-architecture-refactor/requirements.md) Req 3）与仓库产品断点（[layout_breakpoints.dart](../../frontend/lib/design_system/layout_breakpoints.dart)）映射。**产品常量优先**，`StudioBreakpoint` 为文档/API 别名。

## 宽度档位

| Kiro / 规格 | 宽度范围 | 仓库常量 / API | `StudioWidthTier` |
|-------------|----------|----------------|-------------------|
| mobile | &lt; 600 | `kStudioHandsetMaxWidth` (600) | `handset` |
| tablet | 600 – 960 | `kStudioGridDesktopMinWidth` (960) 以下 | `tablet` |
| desktop | 960 – 1280 | `kStudioGridDesktopMinWidth`+ | `desktop` |
| wide | &gt; 1280 | 无单独常量；typography 在 1280/1720 切换 | `desktop`（宽屏用 `studioGridCrossAxisCount` desktopWide） |

## 产品专用断点（保留，勿改为 Kiro 数值）

| 常量 | 值 | 用途 |
|------|-----|------|
| `kStudioTwoColumnMinWidth` | 1100 | 双栏布局 |
| `kStudioPipelineInlineMinWidth` | 760 | 标题 + pipeline 单行 |
| `kStudioCompactHeaderMinWidth` | 720 | 紧凑页头 |
| `kStudioShellCompactTopChromeMaxWidth` | 860 | Shell 顶栏折叠 |
| `kStudioShellStackedTopChromeMaxWidth` | 1240 | Shell 顶栏堆叠 |

## 字体档位（`studioTypographyForWidth`）

| 视口宽度 | 配置 |
|----------|------|
| &lt; 1280 | `StudioTypography.compact` |
| 1280 – 1719 | `StudioTypography.regular` |
| ≥ 1720 | `StudioTypography.large` |

集成：`StudioProductApp` → `studioAdaptiveDesktopTheme`（[studio_adaptive_theme.dart](../../frontend/lib/design_system/studio_adaptive_theme.dart)）。

## 触摸目标

| 平台 | 最小逻辑像素 | API |
|------|--------------|-----|
| iOS / Android | 44 | `StudioSpacing.touchTargetForPlatform` |
| macOS / Windows / Linux | 36 | 同上 |
| 当前上下文 | — | `StudioSpacing.touchTargetForContext(context)` |

## API

- `StudioBreakpoint.fromWidth(width)` — 映射 Kiro 四档
- `studioWidthTier(width)` — 三档（handset/tablet/desktop）
- `StudioResponsiveLayout` — [studio_responsive_layout.dart](../../frontend/lib/design_system/studio_responsive_layout.dart)
