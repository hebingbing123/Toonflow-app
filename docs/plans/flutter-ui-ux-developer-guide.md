# Flutter Studio UI/UX — 开发者指南

面向在本仓库改 `frontend/lib/` 的工程师与 Agent。真源链：

| 主题 | 文档 / 代码 |
|------|-------------|
| 重构阶段与 A/B/C 分类 | [`flutter-ui-ux-refactor-18-phases.md`](flutter-ui-ux-refactor-18-phases.md) |
| 验收与 ⬜ 推迟项 | [`flutter-ui-ux-refactor-signoff.md`](flutter-ui-ux-refactor-signoff.md) |
| Kiro 任务清单 | [`.kiro/specs/flutter-ui-ux-architecture-refactor/tasks.md`](../.kiro/specs/flutter-ui-ux-architecture-refactor/tasks.md) |
| 改 UI 前必读 | [`frontend/lib/design_system/UI_REFACTOR_CONTEXT.md`](../../frontend/lib/design_system/UI_REFACTOR_CONTEXT.md) |
| 异步三态 | [`frontend/lib/design_system/ASYNC_LOADING.md`](../../frontend/lib/design_system/ASYNC_LOADING.md) |
| CPI 审计 | [`flutter-ui-ux-async-cpi-audit.md`](flutter-ui-ux-async-cpi-audit.md) |
| i18n | [`flutter-ui-ux-l10n-conventions.md`](flutter-ui-ux-l10n-conventions.md) |
| 视觉规范 | [`docs/product/ux/studio-visual-guidelines.md`](../product/ux/studio-visual-guidelines.md) |

## 新增面板 / 列表

1. 首屏加载：`StudioAsyncDataView` + `resolveStudioPaneLoadState`（有 `StudioLoadState` 时）或 `loading:` + 骨架占位。
2. 禁止整页大块 `CircularProgressIndicator`；行内/按钮内 `strokeWidth: 2` 的 CPI 合法。
3. 失败：`StudioEmptyState.loadFailed` / `StudioApiErrorCallout`；文案 `describeUserVisibleApiErrorResolved`。
4. 用户可见字符串进 `app_en.arb` / `app_zh.arb`；非 UI 匹配令牌进 `platform/studio_content_heuristics.dart`。

## 表单与键盘

- 多字段表单：`StudioFormKeyboardScope(onEnterSubmit: …)` + `FocusTraversalGroup`（scope 内置）。
- `StudioAlertDialog`：仅 **一个** 单行 `TextField` 时 Enter 自动触发尾部 `FilledButton`；多字段勿依赖自动绑定。
- 产品级快捷键：Help Hub → 文档 Tab 顶部 `StudioKeyboardShortcutsPanel`；模块内另做（如短视频）。

## 按钮与图标

- 主/次/危险：`studioFormPrimaryButtonStyle` 等（见 `studio_surfaces.dart`）。
- 图标：`StudioIconButton` / `studioAccessibleIconButton`（禁止业务层裸 `IconButton`）。

## 合并前门禁

```bash
bash scripts/studio-visual-debt-check.sh
yarn refactor:agent --full    # 清单收官或 PR 合并前
```

改 Shell / 顶栏 / 登录 / 搜索布局后：`bash scripts/run-ui-ux-audit-e2e.sh`。

## 明确不在本指南范围（⬜）

图表库、乐观 UI 全产品清单、`.frag` 毛玻璃、80% 覆盖率 KPI、ops 监控仪表板 — 见 signoff / release-notes。
