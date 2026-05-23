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
| Phase 9 | Done — 项目首页：宽屏 `StudioPrimaryButton`、入门步骤标题、最近项目 chip 层级、项目卡选中浅底 |
| Phase 10 | Done — Jobs / 通知中心 Studio 壳：inset 标题区、骨架加载、任务卡 inset 行、Jobs 空态带加载 CTA |
| Phase 11 | Done — 质量评审 Studio 壳 + Help Hub 标题 inset；看板/列表 inset 分区、骨架加载、空态加载 CTA |
| Phase 12 | Done — 内容合规 inset 壳、队列骨架/空态刷新 CTA、队列项卡片；全局搜索 compact 宽度自适应 |
| Phase 13 | Done — 平台状态 / Benchmark / 团队工作区：inset 标题区、骨架加载、空态刷新、状态卡片分区 |
| Phase 14 | Done — 平台配置 / API 密钥：inset 标题区、可折叠操作条、配置层 inset 分区、列表骨架 |
| Phase 15 | Done — 账户页 inset 统一；typography 扫尾（横幅/壳层硬编码字号 → StudioTypography / 共享样式） |

与 Studio 视觉阶段 6–9 同里程碑交付；真源见 [`studio-visual-guidelines.md`](../product/ux/studio-visual-guidelines.md)。

**2026-05-21 收尾核对**：Phase 1–2 代码与黄金图已对齐；Phase 3 曾因并行落地的 `StudioToastOverlay` 关闭钮仍用 `VisualDensity.compact` 导致 `studio-visual-debt-check.sh` 失败，已修复；加载骨架栅格间距与主网格统一为 `StudioLayoutSpacing.stackMedium`。

**2026-05-23 续**：`studio_text_styles.dart` 已提供 `studioAccentBanner*` / `studioWizardStep*` 等共享样式；Phase 15 将供应商设置横幅、工作区上下文、全局搜索 palette、套餐用量等残余硬编码 `fontSize` 收口到 `StudioTypography`；`tools/ui_audit` 需 `dart run build_runner build` 后可用 quick 配置验收 high 计数。

### Phase 9: 项目首页抛光续（2026-05-23）

- 宽屏创建项目统一 `StudioPrimaryButton`（与堆叠/手机一致的主 CTA 物理感）。
- `StudioGettingStartedSteps` 增加面板标题（`studioGettingStartedTitle`），与空状态并排时更易扫读。
- 最近项目 chip：去掉与区段标题重复的「继续创作」文案；眉标 `#id` + 步骤环 + 选中浅底；与主网格选中态一致。
- 项目卡选中态：`primarySoft` 浅底，边框保持主色强调。

### Phase 10: Jobs + 通知中心（2026-05-23）

- **Jobs**（`jobs/section_view.dart`）：Studio 标题+筛选收入 inset 面板；加载 `StudioSkeleton`；空列表 `StudioEmptyState.emptyData` +「加载任务列表」；任务行 inset 卡片（保留重试/取消）。
- **通知中心**（`notifications/section.dart`）：Studio 标题区 inset + `studioPaneTitleStyle`；加载骨架列表；「全部标为已读」改为 `OutlinedButton.icon`（与筛选区 CTA 层级区分）。

### Phase 11: 质量评审 + Help Hub（2026-05-23）

- **质量评审**（`quality_reviews/section.dart` / `previews.dart`）：inset 标题+可折叠筛选；评审列表/看板分 inset 面板；加载骨架；空列表 `emptyData` +「加载评审列表」；工作台主操作用 `StudioPrimaryButton`；看板加载骨架。
- **Help Hub**（`help_hub_section.dart`）：文档 Tab 标题区收入 inset 面板 + `studioPaneTitleStyle`（与项目首页/任务中心节奏一致）。

### Phase 12: 内容合规 + 全局搜索（2026-05-23）

- **内容合规**（`content_compliance/section.dart`）：整页 inset 壳 + `studioPaneTitleStyle`；队列加载骨架；未加载/空队列 `emptyData` +「刷新」；队列条目 inset 卡片。
- **全局搜索**（`global_search_bar.dart`）：compact 模式用 `LayoutBuilder` 在 160–400px 内自适应宽度，避免顶栏窄约束溢出。

### Phase 13: 平台状态 + Benchmark + 团队工作区（2026-05-23）

- **平台状态**：inset 标题区；首屏加载骨架；状态 chip / SLI / 热点端点分 inset 面板；条目卡片化。
- **Benchmark**：inset 标题 + `studioPaneTitleStyle` / `studioSectionIntroStyle`。
- **团队工作区**：inset 标题；列表加载骨架；未加载/空列表 `emptyData` + 刷新 CTA。

### Phase 14: 平台配置 + API 密钥（2026-05-23）

- **平台配置**（`platform_config_section.dart`）：inset 标题区；操作条收入 `StudioCollapsibleFilterPanel`；首屏加载骨架；plan/workspace/user 覆盖层分 inset 面板；整页可滚动。
- **API 密钥**（`api_keys/section.dart`）：inset 标题区；创建/列表/审计面板统一 `studioInsetPanelDecoration`；列表加载 `StudioSkeleton`；整页可滚动。

### Phase 15: 账户页 + typography 扫尾（2026-05-23）

- **账户**（`account/section.dart`）：inset 标题区；导出/删除面板统一 `studioInsetPanelDecoration`（删除区保留 error 渐变）；导出列表加载骨架；整页可滚动。
- **Typography**：国内/国际供应商横幅 → `studioAccentBanner*`；`workspace_context_view` / `global_search_bar` / `plan_usage` / `creator_journey_compact_bar` 去除裸 `fontSize`；`platform_config` 分区标题 → `studioCardTitleStyle`。

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

**2026-05-21 续（第三批，含项目内）**：

- 平台状态、内容合规举报表单、Help Hub 文档、Benchmark 运维操作。
- 项目内：剧本批量工作台区/对话框、小说章节工作台卡片、小说工作台搜索、素材高级筛选对话框、项目审计日志筛选。

**2026-05-21 续（第四批）**：

- 短视频镜头筛选：`StudioCollapsibleFilterPanel` + 宽屏 `toolbarRow`（搜索/状态/质量/预设同一行）。
- 团队工作区：创建企业、接受邀请表单可折叠 + `toolbarRow`。
- 管理控制台：全局搜索条可折叠 + `toolbarRow`。
- API 密钥：创建密钥面板可折叠（subtitle 显示显示名）。
- 分镜批量工作台对话框：`StudioWorkbenchSection`（同步/提示词/模型/批量操作）+ `toolbarRow`。
- 通知合规内层：节流策略、阶段覆盖、共享审计筛选、导出历史筛选分块可折叠；审计/导出筛选宽屏 `toolbarRow`。

**接上实现（同批未提交竖切）**：

- 登录页：`contentHeight < 560` 时简化 Hero（分屏/矮窗口不把营销区挤出视口）；`product_shell_login_page_test` 覆盖。
- Harness：`StudioToastHost` 与产品壳对齐，SnackBar 桥接 toast 在 QA 入口可用。
- 质量评审：空列表仍展示运营看板预览（与有数据时一致）；widget 测试补「空列表 + 看板」。
- 设置深链：`StudioSettingsHubNavigation.consumePending` 供供应商 nudge 打开 API 与模型 Tab。
- `config.dart`：profile 构建在无 dart-define 时回退本地 Supabase CLI 默认（与 debug 一致）。
