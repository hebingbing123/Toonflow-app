# Studio 设计 Token（Wave 0）

Flutter 实现：`frontend/lib/design_system/tokens.dart`（`ThemeExtension<StudioTokens>`）。

语义对齐 LumenX CSS 变量 + huobao 纯 CSS 暗色变量；**全深色**为产品默认。

## 背景层级

| Token | 色值（dark） | 用途 |
|-------|-------------|------|
| `bgBase` | `#0D0F14` | 应用底 |
| `bgSurface` | `#141820` | 主内容区 |
| `bgElevated` | `#1A1F2B` | 卡片 |
| `bgInset` | `#0A0C10` | 输入框内凹 |

## 玻璃（侧栏/顶栏）

| Token | 说明 |
|-------|------|
| `glass` | `bgElevated @ 72%` + BackdropFilter blur 16 |
| `glassBorder` | `white @ 8%` 顶高光 |

内容区（预览/时间线）**不使用 blur**，保证视频对比度。

## 文本

| Token | 字号 | 用途 |
|-------|------|------|
| `textPrimary` | 15px | 正文 |
| `textSecondary` | 13px | 次要 |
| `textMuted` | 12px（compact `meta` 档，见 `studio_typography.dart`） | 辅助 |

## 字体

- **正文**：Inter（`google_fonts`）
- **标题/品牌**：Space Grotesk
- **等宽**：JetBrains Mono — **仅** job id / JSON 折叠区

## 语义色

| Token | 色值 |
|-------|------|
| `primary` | `#7C6CF0` |
| `accent` | `#00CEC9` |
| `danger` | `#FF6B6B` |
| `success` | `#2ECC71` |

## 间距

严格 **8px 网格**：8 / 16 / 24 / 32；卡片内边距 16 或 20。

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

产品与 PR 视觉约定见 [`studio-visual-guidelines.md`](studio-visual-guidelines.md)。
