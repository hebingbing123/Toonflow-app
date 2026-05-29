# Flutter UI/UX 18 阶段重构 — OpenFlow Studio 对照表

Composer / Agent 执行本指南前，**必须先读**：

- [`frontend/lib/design_system/UI_REFACTOR_CONTEXT.md`](../../frontend/lib/design_system/UI_REFACTOR_CONTEXT.md)
- [`frontend/lib/design_system/theme.dart`](../../frontend/lib/design_system/theme.dart) + [`tokens.dart`](../../frontend/lib/design_system/tokens.dart)
- [`docs/product/ux/studio-visual-guidelines.md`](../product/ux/studio-visual-guidelines.md)
- 本轮 E2E 审计：[`ui-e2e-runbook.md`](ui-e2e-runbook.md)、[`flutter-ui-ux-refactor-signoff.md`](flutter-ui-ux-refactor-signoff.md)

## 能否「一次全部修完」？

**不能也不应**把本表每一格都标成 ✅。原因分三类：

| 类别 | 含义 | 例子 |
|------|------|------|
| **A. 已收口** | 有门禁/组件真源，增量只需遵守 | 色板、IconButton、异步三态、防抖、PopScope |
| **B. 持续治理** | 随新功能递增，无「最后一次 PR」 | `const`、交错进场、RepaintBoundary 热点 |
| **C. 单独立项** | 需产品/架构/专项，不是 UI 扫尾 | 乐观 UI、`.frag` 着色器、图表 CustomPaint、首屏分片 |

**推荐节奏**：小步 PR + `yarn refactor:agent`；改 Shell/布局后跑 `bash scripts/run-ui-ux-audit-e2e.sh`。若人类要求「尽量一次扫完」，只承诺 **A 类剩余扫尾 + B 类高收益点**，**C 类**写入下方「明确推迟」并在计划中标 ⬜。

## 状态图例

| 标记 | 含义 |
|------|------|
| ✅ | 已有规范 + 门禁/测试，仅需遵守 |
| 🟡 | 部分落地或持续治理 |
| ⬜ | 明确推迟（需产品/专项） |

---

## 阶段 0：准备工作（全局规范注入）

| 项 | 状态 | 仓库真源 |
|----|------|----------|
| Theme / colorScheme / textTheme | ✅ | `buildStudioDarkTheme` / `buildStudioLightTheme` |
| 间距 / 圆角常量 | ✅ | `StudioSpacing`, `StudioLayoutSpacing` |
| Composer 上下文清单 | ✅ | `UI_REFACTOR_CONTEXT.md` |
| 禁止业务层硬编码色 | ✅ | `scripts/studio-visual-debt-check.sh` |

**验收**：`bash scripts/studio-visual-debt-check.sh`

---

## 第一篇章：基础排雷与视觉收敛（1–4）

### 阶段 1：视觉节奏与硬编码清剿 — ✅

### 阶段 2：交互反馈与防误触

| 项 | 状态 | 说明 |
|----|------|------|
| InkWell / Material 反馈 | 🟡 | 主题级 splash；裸 `GestureDetector` 仅 3 处登记豁免（见 visual guidelines） |
| 48dp 触摸目标 | ✅ | `studioUtilityIconButtonStyle` |
| 表单/工具栏按钮 token | ✅ | `studioForm*` 系列 |

### 阶段 3：多端响应式

| 项 | 状态 | 说明 |
|----|------|------|
| 断点常量 | ✅ | `layout_breakpoints.dart` |
| 流水线条 / Shell 堆叠 | ✅ | `kStudioPipelineInlineMinWidth` 等 |
| `maxLines` / `ellipsis` | ✅ | `StudioEllipsisTooltipText`、页头/列表扫尾 |
| 键盘上推 | ✅ | 产品壳表单 `resizeToAvoidBottomInset: true`；无 `false` 反模式 |

### 阶段 4：全局异常流与异步三态 — ✅

---

## 第二篇章：微交互与平台沉浸（5–9）

### 阶段 5：动效与共享元素

| 项 | 状态 | 说明 |
|----|------|------|
| Hero（项目卡 → 工作室） | ✅ | 标题 + 进度环；`StudioHero` + `HeroMode(isCurrent)` 避免栈内重复 tag |
| 交错进场 | 🟡 | 新增长列表按需 `studioStaggeredChildren` |
| `AnimatedSwitcher` | ✅ | `StudioMetricSwitch` / `StudioFadeSwitcher` |

### 阶段 6：PC / Web 沉浸

| 项 | 状态 | 说明 |
|----|------|------|
| Hover + 指针 | ✅ | `studio_pointer.dart` |
| 可见滚动条 | ✅ | `StudioScrollBehavior` @ `studio_app.dart` |
| Tab / Enter 焦点 | ✅ | 产品壳/设置/任务/质检/管理台/合规；**project_editor** 全表；**project_studio** 导入/爬虫/webview；script 编辑/批处理/改图；`StudioAlertDialog` 单字段 Enter；Help Hub 快捷键参考面板 |

### 阶段 7：移动端系统物理

| 项 | 状态 | 说明 |
|----|------|------|
| 状态栏 / 边缘延伸 | ✅ | `StudioSystemUiSurface` + `prefersHandsetSystemChrome` |
| `PopScope` 防误退 | ✅ | `StudioDirtyPopGuard` |
| Haptics | 🟡 | 主 CTA 已有；通知刷新 `studioRefreshHaptic`；长按扩展持续治理 |

### 阶段 8：主题与本地化

| 项 | 状态 | 说明 |
|----|------|------|
| 深色层级 / 发光边框 | ✅ | `StudioTokens.dark` |
| 主题切换动画 | ✅ | `AnimatedTheme` |
| 长文案 `Wrap` | ✅ | `StudioPaneTitleMenuRow`、通知/搜索/AppBar 窄屏 |

### 阶段 9：无障碍 A11y

| 项 | 状态 | 说明 |
|----|------|------|
| `Semantics` / `Tooltip` | ✅ | `StudioIconButton` + debt check |
| 系统大字体 | 🟡 | debt check 禁 10/11px；定高组件随改动替换 `minHeight` |

---

## 第三篇章：架构与安全（10–14）

### 阶段 10：防抖与微状态锁定 — ✅

### 阶段 11：渲染性能

| 项 | 状态 | 说明 |
|----|------|------|
| `const` 构造 | 🟡 | 持续治理，非门禁 |
| `ListView.builder` | 🟡 | 嵌套 shrinkWrap 已文档豁免（通知/项目网格）；其余按 profile |
| `RepaintBoundary` | 🟡 | 托盘/toast/短视频 CPI 已包；新动画热点按需 |

### 阶段 12：排印与字重 — ✅

### 阶段 13：离线 / 乐观 UI

| 项 | 状态 | 说明 |
|----|------|------|
| 乐观点赞/收藏 | ✅ 局部 | 本地项目置顶星标（`StudioPinnedProjectsPrefs`）；无服务端收藏 API |
| 离线条 + 缓存 | ✅ | 见第二十五轮 |

### 阶段 14：分片加载与泄漏

| 项 | 状态 | 说明 |
|----|------|------|
| 首屏延迟次要块 | ✅ 局部 | Benchmark `DeferredBenchmarkSection`；其余超重页 ⬜ |
| `dispose` 审计 | 🟡 | 质量/导出等已 cancel；新 StatefulWidget 遵守规则 19 |

---

## 第四篇章：资产与跨端预览（15–18）

### 阶段 15–17

| 阶段 | 状态 | 说明 |
|------|------|------|
| 15 资产隔离 | ✅ 核心 / 🟡 分端 bitmap 流程 |
| 16 PWA/错误边界 | ✅ |
| 17 DPI | 🟡 | 新资源遵守 `1.5x/2x/3x` 目录约定 |

### 阶段 18：着色器 / HDR

| 项 | 状态 | 说明 |
|----|------|------|
| 毛玻璃性能 | ✅ | `STUDIO_GLASS=false` → `glass` / toast / demo coach 无 `BackdropFilter` |
| `.frag` 真毛玻璃 | ✅ | `STUDIO_GLASS_SHADER` + `studio_glass_blur.frag`；默认仍 `BackdropFilter` 降级 |
| 色带 / 贝塞尔图表 | ⬜ | 无产品图表需求前不做 |

---

## 明确推迟（⬜，不要假装 ✅）

（无 — 见 signoff 第二十六轮）

## 合并前门禁

```bash
bash scripts/studio-visual-debt-check.sh
yarn refactor:agent --quick   # 或提交前 --full
cd frontend && flutter test   # 全量（含 golden）；布局变更后 --update-goldens 对应文件
cd frontend && flutter test test/design_system/studio_form_keyboard_test.dart
cd frontend && flutter test test/ui/studio_async_sections_test.dart
bash scripts/run-ui-ux-audit-e2e.sh   # 改 Shell / 布局 / 登录 / 搜索后；PNG 入 test/goldens/ 需人工对照提交
```

**2026-05-28 扫尾**：golden 已按 `StudioPaneTitleMenuRow` / 窄屏头更新；`product_shell_login_page_test` 用 Key + `pumpAndSettle`；全量 `flutter test` 绿；`StudioHero` 背景路由禁用 flight；`script_editor` 三处对话框 Enter 键盘。

**2026-05-28 backlog 字面 100%**：`project_editor` 全表 Enter（含 plan workbench、novel create/edit/delete/search、asset launchers）；`studioFormButtonLabelMetrics` 浅色主按钮字色；`TextButton.icon` 高流量扫尾；E2E/golden 绿；§F C 类 roadmap；通知 `studioRefreshHaptic`。
