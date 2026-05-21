# Frontend UX Comfort Polish Plan (2026-05-21)

## Background

This pass focuses on the Flutter product shell and the projects home because they amplify the same comfort issues across web, desktop, and narrow-window layouts:

- weak visual hierarchy on dense dark surfaces
- large areas of low-information empty space
- CTA buttons that are visible but not quite decisive
- empty states that explain too little and guide too weakly
- project cards that feel roomy but not especially actionable
- small-width layouts that technically adapt but do not feel intentionally composed

Sources reviewed during this pass:

- `frontend/build/e2e_gallery/regular_01_login_default.png`
- `frontend/build/e2e_gallery/regular_02_projects_default.png`
- `frontend/build/e2e_gallery/regular_08_more_menu.png`
- `frontend/build/e2e_gallery/regular_09_tasks_default.png`
- `frontend/build/e2e_gallery/regular_20_help_hub_webhooks.png`
- `docs/plans/ui-e2e-screenshot-audit-2026-05-19.md`
- `frontend/lib/design_system/**`
- `frontend/lib/project_studio/projects_studio_home.dart`
- `frontend/lib/project_studio/projects_grid_view.dart`

## Audit Findings

### 1. Visual hierarchy

- Page sections often sit on similar-value dark fills, so primary content and secondary chrome read too similarly.
- Headers do not always create a clear “where am I / what do I do next” sequence.
- Empty states float inside large panels without enough framing, causing the center of the page to feel under-designed.

### 2. Spacing and layout rhythm

- Large project cards and empty panes leave a lot of dead space before they convey useful status.
- Section spacing is broadly consistent, but key pages still feel top-heavy and sparse in the middle.
- Split layouts on wide screens use space, but not always to strengthen scanning or prioritization.

### 3. Font sizing and readability

- Typography tokens are generally sane, but some panel combinations produce weak contrast between title, intro, and metadata.
- Secondary text can feel too faint in oversized surfaces, especially when paired with long empty-state copy.

### 4. Color consistency

- The palette is directionally coherent, but several surfaces differ only slightly in value, so hierarchy depends too much on borders.
- Important actions and progress affordances need more consistent emphasis than the surrounding dark panels.

### 5. Clickability and interaction confidence

- Buttons are present, but some high-value actions need stronger physicality and clearer grouping.
- Project cards currently split attention between card tap, selection, and the inline “进入工作室” action.
- Some menus and utility panes feel more like raw containers than polished tools.

### 6. Empty states

- Empty states communicate state, but not enough next-step momentum.
- First-run project setup is functionally present, yet visually separated into disconnected blocks.

### 7. Multi-end / responsive behavior

- The shell already has width-based adaptation, but several components still feel “stacked because they had to” rather than intentionally recomposed.
- This pass should prefer broad component-level fixes over route-specific patching.

## Implementation Plan

### Phase 1: Shared component polish

- Strengthen `StudioPrimaryButton` affordance and state readability.
- Recompose `StudioEmptyState` into a more intentional surface with better CTA grouping.
- Improve `StudioGettingStartedSteps` so onboarding guidance feels like part of the same composition.

### Phase 2: Projects home vertical slice

- Tighten the projects-home header and section rhythm.
- Make empty projects state feel like a guided first-run workspace instead of a placeholder.
- Improve project cards so title, status, progress, and primary action scan faster.
- Tune recent-project chips for stronger hierarchy and better use of wide layouts.

### Phase 3: Validation

- Run targeted Flutter tests and relevant front-end gate checks.
- Update affected goldens only where the new composition is intentional.
- Run repo-required refactor gate before commit.

### Phase 4: Task center vertical slice（2026-05-21 续）

- 产品壳任务中心：标题区 + 操作条收入 `studioInsetPanelDecoration`（与项目首页节奏一致）。
- 主 CTA「打开任务工作台」改用 `StudioPrimaryButton`；空列表 `StudioEmptyState.emptyData` 带刷新 CTA（工作台入口保留在标题操作条，避免 pane 内双主 CTA 溢出）。
- 加载态用 `StudioSkeleton` 替代裸 `CircularProgressIndicator`；任务行改为可扫读的 inset 卡片。
- `studioPresentation` 首帧自动 `onLoadTaskApi`（已有逻辑，补 widget 测试）。

### Phase 5: Shell「更多」菜单（2026-05-21 续）

- 菜单面板改用 `studioInsetPanelDecoration` + 轻阴影；内容区 `SingleChildScrollView` 避免裁切。
- 目的地按 **制片与任务** / **团队与平台** 分组（`ProductShellMoreMenuGrouping`）；窄屏快捷项（通知/设置/帮助）置顶。
- 关闭钮 `studioUtilityIconButtonStyle`；行级圆角/间距 token 化。
- E2E：`closeMoreMenuIfOpen` 支持 `close_rounded` + `ModalBarrier`；`openMoreMenu` 等待分组标题。

### Phase 6: 项目卡交互（优先，产品真源）

- 卡片主体与「进入工作室」拆分热区：主体 `onSelectProjectScope`，主按钮 `onOpenProjectStudio`。
- 未选中且支持 scope 时展示 `studioProjectCardTapToSelect` 提示。
- 稳定键：`project_select_scope_{id}` / `project_enter_studio_{id}`；widget 测试覆盖三种点击路径。

### Phase 7: E2E P0 进入工作室（依赖 Phase 6 键与断言）

- `openProjectByName` 优先点 `project_enter_studio_*`；`assertProjectStudioEntered` 断言离开项目首页并出现「剧本」。
- 全量图库在 `studio_step_script` / `storyboard_studio_step` 前调用断言，避免误拍项目网格。

## Decision

This pass will prioritize shared design-system surfaces plus the projects home instead of chasing many isolated panes. That gives the best return for hierarchy, spacing, clickability, and responsive comfort while staying aligned with the repo’s “vertical slice, maintainable modules” rule.

## Completion status (2026-05)

| Phase | Status |
|-------|--------|
| Phase 1 | Done — `StudioPrimaryButton`, `StudioEmptyState`, `StudioGettingStartedSteps` (含间距 token 扫尾) |
| Phase 2 | Done — `projects_studio_home` 标题区阴影降噪、空状态+入门步骤、最近项目 chip；`projects_grid_view` 栅格间距 token |
| Phase 3 | Done — `studio-visual-debt-check.sh`、项目/登录相关测试与黄金图；toast 关闭钮改用 `studioUtilityIconButtonStyle`（清除 `VisualDensity.compact` 门禁失败） |
| Phase 4 | Done — `task_center/section.dart` + `previews.dart`：标题区 inset、骨架加载、空态双 CTA、任务卡片层级、`StudioPrimaryButton` 主操作 |
| Phase 5 | Done — `build_product_shell.dart` 更多菜单分组/滚动/降噪；`studio_shell_navigation.dart` grouping；E2E support 关闭逻辑 |
| Phase 6 | Done — `projects_grid_view.dart` 主体/主按钮分热区 + 选择提示 + 稳定 Key |
| Phase 7 | Done — `real_product_shell_gallery_support.dart` 进入工作室键与 `assertProjectStudioEntered`；全量图库接线 |
| Phase 8 | Done — `StudioFilterRow.toolbarRow` + `StudioCollapsibleFilterPanel`；通知/任务/质量/Help Hub/内容合规/任务工作台 |

与 Studio 视觉阶段 6–9 同里程碑交付；真源见 [`studio-visual-guidelines.md`](../product/ux/studio-visual-guidelines.md)。

**2026-05-21 收尾核对**：Phase 1–2 代码与黄金图已对齐；Phase 3 曾因并行落地的 `StudioToastOverlay` 关闭钮仍用 `VisualDensity.compact` 导致 `studio-visual-debt-check.sh` 失败，已修复；加载骨架栅格间距与主网格统一为 `StudioLayoutSpacing.stackMedium`。

### Phase 8: Studio 筛选工具栏（2026-05-21 续）

- 共享：`StudioFilterRow` 增加 `toolbarRow`（宽屏单行 `Row` + `Expanded` 搜索）；`StudioCollapsibleFilterPanel`（默认收起、`ExpansionTile` 展开）。
- P0 通知中心：未读 / 类型 / 搜索 / 刷新 单行 + 可折叠；收起时 subtitle 显示当前筛选摘要。
- P1 任务（Jobs）、质量评审：Studio 壳内筛选/操作条可折叠 + `toolbarRow`。
- 高级合规与审计：保持既有 `ExpansionTile`（`initiallyExpanded: false`）。
- Harness 布局：`collapsible: false` 保持筛选常显。

**2026-05-21 续（第二批）**：

- Help Hub Webhooks：「创建」与「筛选」（刷新 + 搜索）分两块可折叠面板；列表筛选宽屏单行。
- Help Hub Billing：审计筛选表单收入可折叠「筛选」；补回查询/导出/事件列表/加载更多（此前 refactor 截断）。
- 内容合规队列：状态/分类/指标/审核人热点等筛选区默认收起，subtitle 显示当前筛选与待处理数。
- 任务工作台对话框：`StudioWorkbenchSection` 替换固定展开的筛选卡片；分页/项目 ID 行 `toolbarRow`。

**接上实现（同批未提交竖切）**：

- 登录页：`contentHeight < 560` 时简化 Hero（分屏/矮窗口不把营销区挤出视口）；`product_shell_login_page_test` 覆盖。
- Harness：`StudioToastHost` 与产品壳对齐，SnackBar 桥接 toast 在 QA 入口可用。
- 质量评审：空列表仍展示运营看板预览（与有数据时一致）；widget 测试补「空列表 + 看板」。
- 设置深链：`StudioSettingsHubNavigation.consumePending` 供供应商 nudge 打开 API 与模型 Tab。
- `config.dart`：profile 构建在无 dart-define 时回退本地 Supabase CLI 默认（与 debug 一致）。
