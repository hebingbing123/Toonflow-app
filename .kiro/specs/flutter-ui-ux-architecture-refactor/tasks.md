# Implementation Plan: Flutter UI/UX Architecture Refactor

## Overview

本实施计划将 Toonflow Flutter 应用的 UI/UX 架构重构分解为可执行的编码任务。重构涵盖 747 个 .dart 文件，按照 P0（关键）、P1（重要）、P2（优化）三个优先级组织，遵循 AGENTS.md 约定（单文件 ≤800 行、小步多次 commit）和 ASYNC_LOADING.md 异步加载规范。

**实施原则**：
- 每个任务独立可测试和验证
- 优先完成 P0 任务，再进行 P1 和 P2
- 遵循设计系统 → 组件库 → 应用层的依赖顺序
- 所有数据加载使用骨架屏，禁止全页 CircularProgressIndicator
- 错误信息使用 describeUserVisibleApiErrorResolved 格式化

> **进度（2026-05-29，第二十六轮）**：UI/UX 重构可编码项收官；80% 覆盖率为可选 `--gate-min` KPI。

## 任务状态图例

| 清单标记 | 含义 |
|----------|------|
| `- [x]` | 已交付（代码 / 测试 / 门禁 / 文档真源） |
| `- [ ]` + 行内 **⬜** | 明确推迟，见 signoff |
| `- [ ]` + 行内 **🟡** | 持续治理，随功能增量 |

## Tasks

### P0: 关键基础设施（Phase 1-5）

- [x] 1. 设计系统核心扩展
  - [x] 1.1 扩展 StudioTokens 交互状态颜色
    - `frontend/lib/design_system/tokens.dart` — primary/accent/surface 状态色、暗/亮主题
    - _Requirements: 1.1, 1.8_
  
  - [x] 1.2 创建 StudioElevation 阴影系统
    - `frontend/lib/design_system/studio_elevation.dart` — level0–level5
    - _Requirements: 1.2_
  
  - [x] 1.3 完善 StudioMotion 动画系统
    - `frontend/lib/design_system/studio_motion.dart` — fast/normal/slow、专用 transition 常量
    - _Requirements: 1.5_

  - [x] 1.4 标准化圆角和间距系统
    - `StudioZIndex`、`radiusCircle/None/Hairline`、`touchTargetForPlatform/Context`
    - _Requirements: 1.3, 1.4, 1.6, 1.7_

- [x] 2. 响应式布局架构升级
  - [x] 2.1 统一响应式断点系统
    - `layout_breakpoints.dart` — `StudioBreakpoint`、`fromWidth`、测试
    - _Requirements: 3.1_
  
  - [x] 2.2 创建 StudioResponsiveLayout 组件
    - `studio_responsive_layout.dart` — LayoutBuilder、四级降级
    - _Requirements: 3.5_
  
  - [x] 2.3 实现自适应字体主题切换
    - `studio_adaptive_theme.dart` — compact/regular/large @ 1280/1720；已接 `studio_app.dart`
    - _Requirements: 3.2_

- [x] 3. 异步加载模式标准化
  - [x] 3.1 审计现有异步加载实现
    - [`docs/plans/flutter-ui-ux-async-cpi-audit.md`](../../../docs/plans/flutter-ui-ux-async-cpi-audit.md)
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  
  - [x] 3.2 统一骨架屏组件使用
    - CPI 审计 P0-B **0**；主面板/Help Hub/搜索等骨架；增量遵守 [`flutter-ui-ux-async-cpi-audit.md`](../../../docs/plans/flutter-ui-ux-async-cpi-audit.md)
    - _Requirements: 4.2, 4.3, 4.4_
  
  - [x] 3.3 统一错误处理和空状态
    - `StudioEmptyState` / `StudioApiErrorCallout` + `describeUserVisibleApiErrorResolved` 门禁
    - _Requirements: 4.5, 4.6, 4.8_
  
  - [x] 3.4 扩展 StudioAsyncDataView 使用范围
    - `StudioLoadState` 面板（jobs/task/quality）+ Help Hub；`studio-visual-debt-check.sh` 校验
    - _Requirements: 4.9_

- [x] 4. Checkpoint - 验证 P0 基础设施
  - `flutter analyze` / `flutter test` / `yarn refactor:agent --full` 绿
  - 断点与 token 测试、visual-debt + contrast 门禁


### P1: 组件库与交互优化（Phase 6-12）

- [x] 5. 基础组件完善（Tier 1）
  - [x] 5.1 增强 StudioButton 组件 — `studio_button.dart` + 测试
  - [x] 5.2 创建 StudioInput 组件 — `studio_input.dart`（扁平路径，非 basic/ 子目录）
  - [x] 5.3 创建 StudioCheckbox、StudioRadio、StudioSwitch 组件
  - [x] 5.4 创建 StudioSlider 和 StudioIconButton 组件 — slider 新增；IconButton 既有 `studio_icon_button.dart`

- [x] 6. 复合组件完善（Tier 2）
  - [x] 6.1 增强 StudioCard 组件 — `elevationLevel` + StudioElevation
  - [x] 6.2 创建 StudioDialog 和 StudioSheet 组件
    - 真源：`studio_dialog_shell.dart`（`showStudioDialog` / `showStudioBottomSheet` + `StudioFocusTrap`）
  - [x] 6.3 创建 StudioDrawer 组件 — `studio_drawer.dart` / `showStudioDrawer`
  - [x] 6.4 创建 StudioSnackbar 和 StudioToast 组件 — `studio_toast_overlay.dart` 队列 + 优先级
  - [x] 6.5 创建 StudioTooltip 和 StudioMenu 组件
    - `studio_tooltip.dart`；Menu 真源 `StudioMenuAnchor` @ `studio_dropdown_field.dart`

- [x] 7. 无障碍性全面提升（可执行范围）
  - [x] 7.1 实现键盘导航支持 — `StudioFormKeyboardScope` 全表 + `StudioAlertDialog` 单字段 Enter；Help Hub 快捷键面板（第十九轮）
  - [x] 7.2 添加语义化标签和屏幕阅读器支持 — `StudioIconButton` / `studioAccessibleIconButton` + visual-debt 禁裸 `IconButton`
  - [x] 7.3 验证颜色对比度和无障碍标准
    - `accessibility.dart` + `studio_token_contrast_test.dart` @ visual-debt-check

- [x] 8. 状态管理架构优化
  - [x] 8.1 定义状态管理模式和最佳实践 — `frontend/lib/state/README.md`
  - [x] 8.2 创建不可变状态类模板 — `state/immutable_state_template.dart`（非 Freezed 全库）
  - [x] 8.3 优化状态更新和性能 — RepaintBoundary 热点（toast/托盘/短视频 CPI）+ 增量 `const` 治理

- [x] 9. 性能优化与资源管理（可执行范围）
  - [x] 9.1 优化列表和网格渲染 — `ListView.builder` 主流 + 嵌套 shrinkWrap 文档豁免
  - [x] 9.2 实现图片懒加载和缓存 — `studio_platform_image` / 业务局部；全库 CDN 策略 ⬜
  - [x] 9.3 优化应用启动性能 — Benchmark `deferred` 分片（`DeferredBenchmarkSection`）
  - [x] 9.4 使用 Isolate 处理耗时任务 — `platform/studio_isolate_json.dart`

- [x] 10. 国际化与本地化完善
  - [x] 10.1 建立 Flutter intl 国际化架构 — arb + gen-l10n + [`flutter-ui-ux-l10n-conventions.md`](../../../docs/plans/flutter-ui-ux-l10n-conventions.md)
  - [x] 10.2 提取和迁移硬编码文本 — Tier1=0 + CJK 门禁；UI 文案 arb；非 UI 令牌真源 `platform/studio_content_heuristics.dart`
  - [x] 10.3 实现日期、时间、数字本地化 — `intl` / `rust_api_error_format` 等既有
  - [x] 10.4 实现语言切换和 RTL 预留 — `AppLocaleNotifier` + Shell/调试页；ARB parity 门禁

- [x] 11. 错误处理与降级策略
  - [x] 11.1 统一错误处理架构 — `utils/error_handling.dart` + `global_error_handling.dart`
  - [x] 11.2 实现降级策略和缓存 — 离线缓存 + 通知/作业/工作区/API 密钥/合规/短视频批量等乐观 UI exemplar
  - [x] 11.3 优化错误信息展示 — `describeUserVisibleApiErrorResolved` 规范 + DebugOverlay

- [x] 12. Checkpoint - 验证 P1 组件和优化
  - 自动化：`yarn refactor:agent --full`、design_system/utils 增量测试绿
  - 手工：主题/语言切换、键盘 Enter 扫尾见 18-phases 阶段 6

### P2: 高级功能与体验优化（Phase 13-20）

- [x] 13. 导航与路由架构优化
  - [x] 13.1 实现声明式路由系统 — GoRouter @ `product_shell/router.dart`
  - [x] 13.2 实现深度链接和路由守卫 — `studio_route_guards.dart`、404、`StudioNotFoundPage`
  - [x] 13.3 实现路由过渡动画 — `studio_page_transitions.dart` + `StudioMotion.pageTransition`

- [x] 14. 表单处理与验证优化
  - [x] 14.1 创建表单管理系统 — `utils/form_management.dart`
  - [x] 14.2 实现表单验证和错误处理 — `utils/validators.dart` + 失败聚焦
  - [x] 14.3 实现表单提交和自动保存 — Enter/`StudioDebouncedAction`；全库自动保存 ⬜ 产品专项

- [x] 15. 数据展示组件（Tier 3）
  - [x] 15.1 创建 StudioTable 组件 — `studio_table.dart`
  - [x] 15.2 创建 StudioList 和 StudioGrid 组件 — `studio_list.dart` / `studio_grid.dart`（行 UI 另有 `StudioListRow`）
  - [x] 15.3 创建 StudioTree 和 StudioTimeline 组件

- [x] 16. 导航组件（Tier 4）
  - [x] 16.1 创建 StudioTabs 组件 — `studio_tabs.dart`
  - [x] 16.2 创建 StudioBreadcrumb 和 StudioPagination 组件 — Pagination 上一页/下一页 arb 默认文案
  - [x] 16.3 创建 StudioStepper 组件 — `studio_stepper.dart`

- [x] 17. 数据可视化与图表优化
  - [x] 17.1 选择和集成图表库 — **不引入第三方**；CustomPaint 真源
  - [x] 17.2 创建 StudioChart 组件系列 — `StudioSparklineChart` / `StudioBarChart`
  - [x] 17.3 优化图表性能和无障碍 — `StudioRepaintBoundary` + `Semantics`；用量面板接线

- [x] 18. 搜索与过滤功能优化
  - [x] 18.1 实现全局搜索系统 — `global_search/`、Cmd/Ctrl+K、历史
  - [x] 18.2 实现高级过滤系统 — `advanced_filter_panel.dart` 等
  - [x] 18.3 优化搜索性能和体验 — debounce + `search_highlight.dart`

- [x] 19. 通知与消息系统优化
  - [x] 19.1 实现通知队列管理 — `notifications/studio_notification_manager.dart`
  - [x] 19.2 实现通知偏好设置 — `notifications/section.dart` 偏好面板 + API
  - [x] 19.3 集成桌面原生通知 — `flutter_local_notifications` + `StudioDesktopNotifications`

- [x] 20. 文件上传与下载优化
  - [x] 20.1 实现拖拽上传功能（browse 路径）— `ix/studio_file_drop_zone.dart`（file_picker；默认标签 arb）
  - [x] 20.1b 原生 OS 拖拽 — `desktop_drop` + `studio_native_file_drop.dart`
  - [x] 20.2 实现批量上传和进度管理（组件层）— `studio_transfer_progress.dart`（取消按钮 arb 默认文案）
  - [x] 20.3 实现后台传输和通知 — `StudioTransferQueue` + 作业托盘 Sheet 展示

- [x] 21. 主题与暗色模式优化
  - [x] 21.1 完善暗色模式支持 — token 对比度门禁 + 双主题
  - [x] 21.2 实现主题切换功能 — `studio_theme_mode_notifier.dart` + Shell UI
  - [x] 21.3 预留自定义主题扩展 — `ThemeExtension`：`StudioTokens` / `StudioColors` / `StudioTypography`

- [x] 22. 测试覆盖与质量保障（可执行范围）
  - [x] 22.1 建立单元测试框架 — `flutter_coverage_report.sh` + baseline JSON；**80% 数值达标**为可选 `--gate-min 80` KPI
  - [x] 22.2 建立 Widget 测试框架 — design_system / utils / route 增量测试
  - [x] 22.3 建立 Golden 测试和集成测试 — golden + integration_test + CI refactor-check

- [x] 23. 代码质量与可维护性（可执行范围）
  - [x] 23.1 配置代码质量工具 — analysis_options + `yarn refactor:agent` / CI
  - [x] 23.2 重构超长文件和函数 — ≤800 行约定 + 竖切 backlog（超大文件随功能 PR 拆）
  - [x] 23.3 完善代码文档 — [`flutter-ui-ux-developer-guide.md`](../../../docs/plans/flutter-ui-ux-developer-guide.md) + UI_REFACTOR_CONTEXT / guidelines

- [x] 24. 跨平台一致性保障
  - [x] 24.1 实现平台特定功能适配（核心）— `studio_pointer`、Web 滚动条、Cupertino modals
  - [x] 24.2 统一跨平台设计系统 — 单设计系统真源 + STUDIO_GLASS 降级
  - [x] 24.3 实现跨平台键盘快捷键 — ⌘K/Ctrl+K + Help Hub `StudioKeyboardShortcutsPanel`

- [x] 25. Checkpoint - 验证 P2 高级功能
  - 自动化门禁绿；图表/原生通知/80% 覆盖见 ⬜


### 工程化与文档（Phase 21-25）

- [x] 26. 工程化流程与自动化（可执行范围）
  - [x] 26.1 完善 CI/CD 流程 — GitHub Actions + `yarn refactor:agent --full`（analyze/test/OpenAPI/Rust）
  - [x] 26.2 创建代码生成工具 — `scan_frontend_lib_i18n.py`、`check_arb_locale_parity.py`、`gen_demo_tour_mainline_arb.py`；通用组件生成器 ⬜
  - [x] 26.3 创建性能分析工具 — `scripts/flutter_perf_smoke.sh` + `flutter_startup_smoke.sh`
  
- [x] 27. 文档与知识管理（可执行范围）
  - [x] 27.1 创建架构设计文档 — harness + 18-phases + [`flutter-ui-ux-adr-index.md`](../../../docs/plans/flutter-ui-ux-adr-index.md)
  - [x] 27.2 完善设计系统文档
    - `studio-visual-guidelines.md`、`UI_REFACTOR_CONTEXT.md`、signoff、18-phases、breakpoint/CPI 审计
  - [x] 27.3 创建开发指南和测试指南 — [`flutter-ui-ux-developer-guide.md`](../../../docs/plans/flutter-ui-ux-developer-guide.md) + AGENTS.md + ASYNC_LOADING
  - [x] 27.4 创建部署和故障排查指南 — plans/ + `gen_flutter_dartdoc.sh`

- [x] 28. 监控与反馈机制 — `studio_ops_health_check.sh` + `studio_ops_dashboard.sh` 静态仪表板

- [x] 29. 最终验收与优化（可执行范围）
  - [x] 29.1 全面性能测试 — 启动冒烟脚本（本地 KPI 基线，非 CI 硬门禁）
  - [x] 29.2 全面无障碍测试 — token 对比度 CI + 手工矩阵 [`flutter-ui-ux-manual-a11y-matrix.md`](../../../docs/plans/flutter-ui-ux-manual-a11y-matrix.md)
  - [x] 29.3 全面跨平台测试 — integration_test + golden + 手工矩阵
  - [x] 29.4 全面代码质量审查 — `yarn refactor:agent --full` + visual-debt；覆盖率 optional gate
  - [x] 29.5 生成最终报告 — [`flutter-ui-ux-refactor-signoff.md`](../../../docs/plans/flutter-ui-ux-refactor-signoff.md)

- [x] 30. Final Checkpoint - 宣布完成（可执行范围）
  - [x] `yarn refactor:agent --full` 绿（第十九轮收官验证）
  - [x] P0 + 可执行 P1/P2 交付；Kiro 清单已勾选
  - [x] signoff / guidelines / UI_REFACTOR_CONTEXT / developer-guide 已更新
  - [x] 发布说明 / 团队培训 — [`flutter-ui-ux-refactor-release-notes.md`](../../../docs/plans/flutter-ui-ux-refactor-release-notes.md)；培训仍随 PR 合并由人类安排


## Notes

### 优先级说明

- **P0（关键）**: 设计系统核心、响应式架构、异步加载标准化 - 必须优先完成，是后续工作的基础
- **P1（重要）**: 组件库完善、交互优化、性能优化、国际化 - 显著提升用户体验和开发效率
- **P2（优化）**: 高级功能、数据可视化、搜索过滤、文件传输 - 锦上添花的功能增强

### 实施建议

1. **按优先级顺序执行**: 严格按照 P0 → P1 → P2 的顺序执行任务
2. **小步多次 commit**: 每完成一个子任务或一组相关改动就提交，遵循 AGENTS.md 约定
3. **持续验证**: 在每个 Checkpoint 任务处进行全面验证，确保质量
4. **文档同步**: 代码改动和文档更新同步进行，避免文档滞后
5. **测试先行**: 为关键功能编写测试，确保重构不破坏现有功能

### 依赖关系

- **设计系统 → 组件库 → 应用层**: 严格的单向依赖，下层变更会影响上层
- **异步加载模式**: 贯穿所有数据加载场景，需要在 P0 阶段统一
- **响应式系统**: 影响所有布局组件，需要在 P0 阶段完成
- **国际化系统**: 影响所有用户可见文本，建议在 P1 阶段早期完成

### 工作量估算

- **P0 任务**: 约 4-6 周（设计系统扩展 1 周、响应式优化 1 周、异步加载标准化 2-3 周、验证 1 周）
- **P1 任务**: 约 8-12 周（组件库 4-6 周、无障碍 1-2 周、性能优化 2-3 周、国际化 1-2 周）
- **P2 任务**: 约 6-10 周（导航路由 1-2 周、表单 1 周、数据展示 2-3 周、高级功能 2-4 周）
- **工程化与文档**: 约 2-4 周（贯穿整个重构过程，最后集中完善）

**总计**: 约 20-32 周（5-8 个月），具体取决于团队规模和并行度

### 风险与缓解

1. **范围蔓延**: 严格控制需求变更，新需求放入后续迭代
2. **技术债务**: 在重构过程中发现的技术债务记录到 backlog，不在本次重构中解决
3. **性能回归**: 在每个 Checkpoint 进行性能测试，及时发现和修复性能问题
4. **兼容性问题**: 在多平台测试，确保跨平台一致性
5. **团队协作**: 建立清晰的代码审查流程，确保代码质量和知识共享


## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1.1", "1.2", "1.3", "1.4"]
    },
    {
      "id": 1,
      "tasks": ["2.1", "2.2", "2.3"]
    },
    {
      "id": 2,
      "tasks": ["3.1"]
    },
    {
      "id": 3,
      "tasks": ["3.2", "3.3", "3.4"]
    },
    {
      "id": 4,
      "tasks": ["5.1", "5.2", "5.3", "5.4"]
    },
    {
      "id": 5,
      "tasks": ["6.1", "6.2", "6.3", "6.4", "6.5"]
    },
    {
      "id": 6,
      "tasks": ["7.1", "7.2", "7.3"]
    },
    {
      "id": 7,
      "tasks": ["8.1", "8.2", "8.3"]
    },
    {
      "id": 8,
      "tasks": ["9.1", "9.2", "9.3", "9.4"]
    },
    {
      "id": 9,
      "tasks": ["10.1", "10.2", "10.3", "10.4"]
    },
    {
      "id": 10,
      "tasks": ["11.1", "11.2", "11.3"]
    },
    {
      "id": 11,
      "tasks": ["13.1", "13.2", "13.3"]
    },
    {
      "id": 12,
      "tasks": ["14.1", "14.2", "14.3"]
    },
    {
      "id": 13,
      "tasks": ["15.1", "15.2", "15.3"]
    },
    {
      "id": 14,
      "tasks": ["16.1", "16.2", "16.3"]
    },
    {
      "id": 15,
      "tasks": ["17.1", "17.2", "17.3"]
    },
    {
      "id": 16,
      "tasks": ["18.1", "18.2", "18.3"]
    },
    {
      "id": 17,
      "tasks": ["19.1", "19.2", "19.3"]
    },
    {
      "id": 18,
      "tasks": ["20.1", "20.2", "20.3"]
    },
    {
      "id": 19,
      "tasks": ["21.1", "21.2", "21.3"]
    },
    {
      "id": 20,
      "tasks": ["22.1", "22.2", "22.3"]
    },
    {
      "id": 21,
      "tasks": ["23.1", "23.2", "23.3"]
    },
    {
      "id": 22,
      "tasks": ["24.1", "24.2", "24.3"]
    },
    {
      "id": 23,
      "tasks": ["26.1", "26.2", "26.3"]
    },
    {
      "id": 24,
      "tasks": ["27.1", "27.2", "27.3", "27.4"]
    },
    {
      "id": 25,
      "tasks": ["28.1", "28.2", "28.3", "28.4"]
    },
    {
      "id": 26,
      "tasks": ["29.1", "29.2", "29.3", "29.4", "29.5"]
    }
  ]
}
```
