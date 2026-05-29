# Flutter UI/UX — CircularProgressIndicator 审计表

基线日期：2026-05-29。真源：[ASYNC_LOADING.md](../../frontend/lib/design_system/ASYNC_LOADING.md)。

## 分类

| 类别 | 规则 | 处理 |
|------|------|------|
| **P0-C 合规** | `strokeWidth: 2`（或 `StudioControlSize.progressStroke`），高度 ≤20，在按钮/工具栏/行内操作槽 | 保留 |
| **P0-B 待改** | 面板/列表首屏全页或大块 CPI | 换 `StudioListSkeleton` / `StudioPaneLoadingSkeleton` / `StudioGridSkeleton` |
| **文档** | 仅 ASYNC_LOADING / UI_REFACTOR_CONTEXT 提及 | 忽略 |

## 扫描结果（`frontend/lib`）

| 文件 | 次数 | 分类 | 目标 |
|------|------|------|------|
| `design_system/components/studio_primary_button.dart` | 1 | P0-C | — |
| `design_system/components/studio_toolbar_button.dart` | 1 | P0-C | — |
| `design_system/components/studio_dialog_shell.dart` | 1 | P0-C | — |
| `design_system/ix/studio_job_tray.dart` | 1 | P0-C | — |
| `global_search/global_search_bar.dart` | 3 | P0-C | 搜索建议/提交（ASYNC_LOADING 豁免） |
| `notifications/section.dart` | 7 | P0-C | 已用 `StudioAsyncDataView` + `StudioListSkeleton` |
| `admin_console/section.dart` | 6 | P0-C | 已用 `StudioListSkeleton` + `StudioAsyncDataView` |
| `team_workspaces/section.dart` | 4 | P0-C | 行内刷新按钮 |
| `account/section.dart` | 3 | P0-C | 行内提交 |
| `api_keys/section.dart` | 2 | P0-C | 行内提交 |
| `projects/section.dart` | 2 | P0-C | 创建项目按钮 |
| `short_video_space/*` | 多处 | P0-C | 导出/批处理/对比行内 |
| `content_compliance/section.dart` | 1 | P0-C | 行内 |
| `platform_status/section.dart` | 1 | P0-C | 行内 |
| `project_editor/*` | 若干 | P0-C | 行内 |
| `project_studio/*` | 若干 | P0-C | 行内 |
| `settings/model_vendors/*` | 2 | P0-C | 行内 |

## P0-A/B 违规项

**无** — 2026-05-29 基线：高流量面板（notifications、admin_console）已骨架屏 + `StudioAsyncDataView`；其余均为 P0-C。

## 迁移优先级（后续 PR）

1. `short_video_space/section_production_batch_operations.dart` — 28px 区块 CPI：评估是否改为 `StudioProgressIndicator` 或保留（导出进度语义）
2. 新功能默认：`StudioAsyncDataView` + `resolveStudioPaneLoadState`

## 验证

```bash
cd frontend && flutter test test/ui/studio_async_sections_test.dart
```
