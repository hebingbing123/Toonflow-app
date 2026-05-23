# Studio 设计 Token（Wave 0）

Flutter 实现：`frontend/lib/design_system/tokens.dart`（`ThemeExtension<StudioTokens>`）。

语义对齐 LumenX CSS 变量 + huobao 纯 CSS 暗色变量；**全深色**为产品默认。

## 背景层级

| Token | 色值（dark） | 用途 |
|-------|-------------|------|
| `bgBase` | `#070D15` | 应用底 |
| `bgSurface` | `#101825` | 主内容区 |
| `bgElevated` | `#152033` | 卡片 |
| `bgInset` | `#0A1018` | 输入框内凹 |

## 玻璃（侧栏/顶栏）

| Token | 说明 |
|-------|------|
| `glass` | `bgElevated @ 75%` + BackdropFilter blur 16 |
| `glassBorder` | 半透明青蓝描边 |

内容区（预览/时间线）**不使用 blur**，保证视频对比度。

## 文本

| Token | 色值 | 用途 |
|-------|------|------|
| `textPrimary` | `#E8F1FF` | 正文 |
| `textSecondary` | `#A2B4CD` | 次要 |
| `textMuted` | `#667892` | 辅助（compact `meta` ≥ 12px，见 `studio_typography.dart`） |

## 字体

- **正文**：Inter（bundled `assets/fonts/Inter-Variable.ttf`）
- **标题/品牌**：Space Grotesk（bundled `assets/fonts/SpaceGrotesk-Variable.ttf`）
- **中文回退**：Noto Sans SC（bundled `assets/fonts/NotoSansSC-Variable.ttf`）
- 运行时 **不** 从 Google Fonts CDN 拉取；主题用 `buildStudioDarkTheme(useBundledFonts: true)`（默认）
- `configureGoogleFontsRuntime()` 禁用 `allowRuntimeFetching`
- 重新下载字体：`bash scripts/download-studio-fonts.sh`
- **等宽**：系统 `monospace` — **仅** job id / JSON 折叠区

## 语义色

| Token | 色值 |
|-------|------|
| `primary` | `#7C97FF` |
| `accent` | `#34C8F0` |
| `danger` | `#FF6D7A` |
| `success` | `#35D49B` |
| `warning` | `#FFB347` |

## 间距

严格 **8px 网格**：8 / 16 / 24 / 32；卡片内边距 16 或 20。语义间距见 `StudioLayoutSpacing`。

## 圆角

- 按钮/输入：10px  
- 卡片：14px  
- 侧栏项：10px  

## 降级

`--dart-define=STUDIO_GLASS=false` 关闭毛玻璃，侧栏/顶栏用实色 `bgElevated`。

## 语义间距与状态色（2025 巡检收口）

| 名称 | 常量 | 说明 |
|------|------|------|
| 页面顶间距 | `StudioLayoutSpacing.pageTop` | 24 |
| 区块间距 | `StudioLayoutSpacing.section` | 24 |
| 卡片内边距 | `StudioLayoutSpacing.cardInner` | 16 |
| 标题-副标题 | `StudioLayoutSpacing.titleSubtitle` | 8 |
| 警告色 | `StudioTokens.warning` | 深色背景上的弱提示 |
| 图标热区 | `StudioSpacing.iconTouchTarget` | 36 |

## StudioTokens vs StudioColors

- **`StudioTokens`**：语义色、文本、边框、侧栏平面色（工作台 UI 真源）。
- **`StudioColors`**：品牌/营销渐变、`loginBackdrop`、`primaryGradient`；平面 `sidebar` / `sidebarBorder` 与 `StudioTokens.dark` 一致。

产品与 PR 视觉约定见 [`studio-visual-guidelines.md`](studio-visual-guidelines.md)。
