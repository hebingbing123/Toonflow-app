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

## Decision

This pass will prioritize shared design-system surfaces plus the projects home instead of chasing many isolated panes. That gives the best return for hierarchy, spacing, clickability, and responsive comfort while staying aligned with the repo’s “vertical slice, maintainable modules” rule.

## Completion status (2026-05)

| Phase | Status |
|-------|--------|
| Phase 1 | Done — `StudioPrimaryButton`, `StudioEmptyState`, `StudioGettingStartedSteps` (含间距 token 扫尾) |
| Phase 2 | Done — `projects_studio_home` 标题区阴影降噪、空状态+入门步骤、最近项目 chip；`projects_grid_view` 栅格间距 token |
| Phase 3 | Done — `studio-visual-debt-check.sh`、项目/登录相关测试与黄金图 |

与 Studio 视觉阶段 6–9 同里程碑交付；真源见 [`studio-visual-guidelines.md`](../product/ux/studio-visual-guidelines.md)。
