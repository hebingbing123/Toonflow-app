# Flutter UX 舒适审查矩阵（2026-05-24）

基线：`bash scripts/studio-visual-debt-check.sh` — **通过**（无 raw `Colors.*`、无 shrinkWrap 热区、无 10/11px 字号）。

## 视口 × 主路由（人工 / Golden）

| 视口 | 登录 | Shell 顶栏 | 项目首页 | 脚本步 | 分镜 | 设置 Hub |
|------|------|------------|----------|--------|------|----------|
| 390×844 | 单列 Hero 简化 | 堆叠顶栏 | `isPhone` 单列 | 未专用手机 IA | 易横向挤 | Tab 堆叠 |
| 860×900 | 窄栏 | `compactTopChrome` | stacked header | 单栏 | spinner 居中 | padding 收紧 |
| 1280×900 | 标准 | stacked / 单行过渡 | 网格 2–3 列 | 双栏 ≥1040 | 标准三栏 | 黄金图对齐 |
| 1440×960 | 宽分栏 ≥1120 | 集成顶栏 (Web) | split overview ≥1360 | 双栏 | 标准 | desktop_layouts |

Golden 目录：`frontend/test/goldens/desktop_layouts/`、`frontend/test/goldens/ui_gallery/`。

## 登记问题（修复跟踪）

| ID | 维度 | 严重度 | 状态 |
|----|------|--------|------|
| UX-01 | 颜色：StudioTokens vs StudioColors 侧栏色差 | P0 | 已修复：`StudioColors` 与 tokens 同色值 |
| UX-02 | 断点：Shell/登录 magic number | P0 | 已修复：`layout_breakpoints.dart` 常量 + Shell/登录/项目首页 |
| UX-03 | 文档：design-tokens.md hex 漂移 | P0 | 已修复：文档同步代码 |
| UX-04 | 登录：无提交 loading | P1 | 已修复：`authInFlight` + `StudioPrimaryButton` |
| UX-05 | 登录：硬编码渐变 hex | P1 | 已修复：`tokens.primary` 模式切换 |
| UX-06 | 企业空：banner + firstUse 重复 | P1 | 已修复：`enterpriseGuided` 仅入门步骤 |
| UX-07 | 脚本步：load error 用 emptyData | P1 | 已修复：`StudioApiErrorCallout` |
| UX-08 | 分镜：未选镜头裸 Text | P1 | 已修复：`StudioEmptyState` quiet |
| UX-09 | 搜索：isMobile 600 未复用常量 | P2 | 已修复：`kStudioHandsetMaxWidth` |
| UX-10 | 移动 Web：能力边界未文档化 | P2 | 已修复：guidelines §移动 Web |
| UX-11 | 营销站：--bg-base 与 Studio 略差 | P2 | 已修复：website CSS + nav 44px |
