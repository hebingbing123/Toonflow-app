# Studio 视觉与可用性规范

实现真源：`frontend/lib/design_system/`。本页汇总产品 Shell、项目工作室与短剧空间共用的视觉层级、间距与空状态约定（对应前端视觉巡检结论）。

## 层级（同一屏最多一个强调块）

| 级别 | 内容 | 样式 |
|------|------|------|
| 一级 | 页面标题、当前任务、主 CTA | `studioPageTitleStyle` / `FilledButton` / 单块 `StudioCard(emphasized: true)` |
| 二级 | 流程节点、Tab 选中、侧栏选中 | `primarySoft` 填充 + `primary` 描边/左侧条，**不用** `signalGradient` 叠光晕 |
| 三级 | 说明、统计、次要入口 | 平面 `bgSurface` / `bgInset`，`borderSubtle`，无 `panelGlow` 阴影 |

避免同屏并列：Hero 渐变卡 + 流程条强发光 + 多个 `panelGradient` 容器。

## 颜色

- **一律**从 `StudioTokens` 取语义色（`primary`、`danger`、`success`、`warning`、`textMuted` 等）。
- **禁止**在 Shell / 工作室 UI 写死 `Color(0x…)` 或 `Colors.green.shade100` 做状态（深色主题会发灰/发飘）。
- `Theme.colorScheme.outline` / `outlineVariant` 仅用于非 Studio 主题或遗留 harness；Studio 面板改用 `studioPanelBorderColor()`（见 `studio_surfaces.dart`）。

## 间距

- 网格：`StudioSpacing`（8 / 16 / 24 / 32）。
- 页面语义：`StudioLayoutSpacing`（`pageTop`、`section`、`cardInner`、`titleSubtitle`、`actionRow`）。
- 避免游离值（10 / 14 / 18 / 20 / 28）除非布局特例并注释原因。

## 字体

- 通过 `StudioTypography` + `studio_*Style` 助手；compact 档 `meta`/`label` ≥ 12px。
- Badge / 元信息：`studioBadgeTextStyle` 或 `typography.meta`。
- 等宽仅用于 job id、JSON 折叠区（见 [`design-tokens.md`](design-tokens.md)）。

## 点击热区

- 全局主题：`MaterialTapTargetSize.padded`，`VisualDensity.standard`。
- 顶栏/侧栏图标：≥ `StudioSpacing.iconTouchTarget`（36px），收起侧栏 tile ≥ `navItemTouchTarget`（44px）。
- 密集列表行内图标（Help Hub 复制/排序/删除等）：`IconButton(style: studioUtilityIconButtonStyle(context))`。
- 不要对整页默认可点击控件使用 `shrinkWrap` + 负 `visualDensity`。

## 卡片与对话框

- 默认内容块：`StudioCard(emphasized: false)` 或 `studioInsetPanelDecoration()`。
- 单屏唯一品牌强调：`StudioCard(emphasized: true)` 或登录/主 CTA 渐变按钮。
- 对话框 / Bottom sheet：`studio_dialog_shell` 已平面化；新对话框应复用 `showStudioDialog` / `StudioDialogShell`。

## 空状态

使用 `StudioEmptyState` 三类工厂，不要临时 `Text('暂无数据')`：

| 类型 | 工厂 | 场景 |
|------|------|------|
| 首次使用 | `StudioEmptyState.firstUse` | 无项目、无镜头、需引导下一步 |
| 筛选无结果 | `StudioEmptyState.noResults` | 搜索/过滤为空 |
| 数据为空 | `StudioEmptyState.emptyData` | 加载成功但列表为空 |

可选 `weight: quiet` 或 `noResults` 以降低图标光晕。次要操作：`secondaryActionLabel` + `onSecondaryAction`。

## 导航区

- **侧栏**为次级导航：选中 `primarySoft` + 左指示条；badge 用 `tokens.danger`。
- **流程条**为一级流程时：平面 strip + chip 选中态；与侧栏不要同时强发光。
- **顶栏工具按钮**：选中 `primarySoft`，避免 `signalGradient` + 大阴影。

## PR 自检（改 UI 时扫一眼）

- [ ] 是否新增 `panelGradient` / 双层 `panelGlow` 阴影？
- [ ] 是否新增 `fontSize: 10/11` 或硬编码 hex 色？
- [ ] 空列表是否接入 `StudioEmptyState`？
- [ ] 图标按钮热区是否 ≥ 36px？
- [ ] 同屏是否只有一个「强调块」？

## 相关文件

| 模块 | 路径 |
|------|------|
| Token | `frontend/lib/design_system/tokens.dart` |
| 主题 | `frontend/lib/design_system/theme.dart` |
| 排版 | `frontend/lib/design_system/studio_typography.dart` |
| 文本样式 | `frontend/lib/design_system/components/studio_text_styles.dart` |
| 面板装饰 / 工具钮样式 | `frontend/lib/design_system/components/studio_surfaces.dart`（含 `studioUtilityIconButtonStyle`） |
| 空状态 | `frontend/lib/design_system/components/studio_empty_state.dart` |
| Token 色值表 | [`design-tokens.md`](design-tokens.md) |

## 巡检收尾说明（2026-05）

主路径 **P0/P1**（token 色、光晕降噪、热区、空状态、导航选中态）已在应用代码中落地。仍可能保留：

- **登录 Hero** 营销区白字/半透明（品牌层，非工作台 token 规则）
- **`pipeline_step_chip`** 在 `useStudioTokens: false` 时回退 M3 `outlineVariant` / `onSurfaceVariant`
- **`tokens.panelGlow`** 字段仍在 `tokens.dart` 供渐变定义，运行时 UI 基本不再引用
- 表单内 **单行 hint**（如工作台空下拉提示）仍可用 `studioHintStyle`，不必一律换成 `StudioEmptyState`

新增 UI 请按上文 PR 自检清单执行；可选对照 [`studio-visual-debt.md`](studio-visual-debt.md) 中的 grep 基线。黄金图目录：

- `frontend/test/design_system/goldens/` — `StudioCard` / `StudioPrimaryButton`
- `frontend/test/goldens/ui_gallery/` — wave1–3 场景（空状态、通知、搜索、步骤条等）
- `frontend/test/goldens/desktop_layouts/` — 登录、Shell chrome、设置、任务等桌面布局

2026-05 视觉巡检后已 `--update-goldens` 同步上述目录（与 token/光晕/空状态改动一致）。

## 落地进度（2026-05）

| 项 | 状态 |
|----|------|
| `StudioCard` 默认平面化 | `emphasized` 默认 `false`；设置引导横幅显式 `emphasized: true` |
| 局部 shrinkWrap 热区清理 | 驾驶舱、Shell 更多菜单、模型路由条、账户删除确认等改为 `padded` |
| 语义色收口（批次 1） | 版本对比、平台状态、搜索历史/骨架、短剧导出预检警告色 |
| 间距 token（批次 1） | 侧栏、登录 chip、设置 Hub 模块卡 |
| 阶段 2：Shell 流程条降噪 | 标题徽章、chip 轨道边框与间距 token 化 |
| 阶段 2：语义色横幅 | `studio_freshness_banner`、`panel_versioning`、Help Hub / 平台配置错误文案 |
| 阶段 2：空状态 | benchmark 实验/复核队列、team workspaces、项目成员面板 |
| 阶段 2：短剧生产面板间距 | `view_production_panel` 区块间距与 `SizedBox` 收口 |
| 阶段 2：设置/登录 | Settings Hub 标题区间距；登录 Hero 阴影减弱 |
| 全局按钮 / IconButton 热区 | 已接入 `theme.dart`（`padded` + `iconTouchTarget`） |
| `outline*` → `studio_surfaces` | Studio Shell、工作室、短剧、分镜、设置、账户等主路径已完成 |
| 流程条 / 侧栏降噪 | 平面 strip + `primarySoft` 选中；设置 Hub 模块图标去掉 `panelGlow` 描边 |
| 诊断 /  recessed 面板 | 分镜、批量、脚本/项目工作台诊断卡统一 `studioRecessedPanelDecoration` |
| 空状态模板 | 搜索、通知、合规、任务、项目脚本、分镜列表、视频候选等已接 `StudioEmptyState` |
| 遗留 harness | `pipeline_step_chip` 在非 Studio token 模式仍回退 M3 `outlineVariant`（ intentional ） |
| 项目网格 / 驾驶舱 | 选中卡去掉 `panelGlow` 阴影；未选中 CTA 平面 `primarySoft`；驾驶舱 metric 用 `textPrimary`/`textSecondary` |
| Agent 工作台 | 卡片内边距统一 `StudioLayoutSpacing.cardInner - 4`；活动面板空 WS 事件接 `StudioEmptyState` |
| 项目工作室页 / 资产 Hub | `project_studio_page` 子组件去掉 `Colors.white` / `onSurfaceVariant`，改用 `textPrimary` / `textSecondary` |
| Help Hub | Webhooks/Docs/Billing 面板内边距 token 化；新建 webhook 提示与列表高亮改为 `studioInsetPanelDecoration` / `primarySoft`；Tab 区固定高度修复无界布局 |
| 项目工作室子面板 | `cockpit` / `art_step` / `novel_inline` / 网格 CTA 文案改用 `textPrimary`/`textSecondary` |
| 短剧导出历史 | 列表聚焦行 `primarySoft` + `primary` 左边条，替代 `secondaryContainer` |
| 审片包 / 小说抓取 | `studio_review_pack_*`、`novel_crawl_*`、`art_step_panel` 副文案统一 `textSecondary`；平台提示条 `primarySoft` |
| 全局搜索 | 搜索栏聚焦阴影降噪；图标/按钮用 `textMuted`/`primary`；结果卡与筛选面板去掉 `onSurfaceVariant` |
| 设置 Hub 壳 | 模块 Tab / 进度点 / 副标题改用 `textPrimary`/`textSecondary`/`textMuted` |
| 设计系统基座 | `studioMutedTextColor` 直读 token；空状态/主按钮/卡片/Shell 背景光晕降噪 |
| 短剧空间 | 版本对比/管理、预览器、导出与配音对话框、`view_project_selector` 去掉 `onSurfaceVariant` |
| 运营模块批量收口 | 合规、项目成员/审计、API Keys、通知、账户、管理台、质量评审、任务中心、设置供应商/用量、Shell 上下文等统一 `textSecondary` |
| 全局主题 / 登录表单 | M3 菜单/弹层阴影改为中性黑（非 `panelGlow`）；登录卡副文案 `textSecondary`；App Bar 选中图标 `primary` |
| 流程 chip / 空状态补漏 | `PipelineStepChip` 增加 hover（`primarySoft` + 描边）；API Keys / 管理台搜索组接入 `StudioEmptyState.emptyData` |
| 空状态 / 热区（批次 2） | 短剧时间轴修订、团队工作区弹层、工作室 scope 缺失、管理台子列表；`StudioApiErrorCallout` 关闭/重试按钮 ≥ 36px |
| 空状态（批次 3） | 通知（非 studio 路径统一）、合规审计弹窗、短剧角色/操作历史、审片包列表、Skills 版本历史 |
| 热区 / Golden | Agent 抽屉关闭钮 ≥ 36px；`ui_gallery` wave1–3 + `desktop_layouts` 黄金图已更新；`platform_status` golden 补 `SharedPreferences` mock |
| Help Hub 工具钮 | `studioUtilityIconButtonStyle()`（`studio_surfaces.dart`）；Docs/Webhooks 列表与对话框 `IconButton` 统一 36px 热区 |
| 阶段 4：登录降噪 | 表单卡/轨道光点/提交按钮阴影减弱；表单 padding token 化 |
| 阶段 4：短剧时间轴 | 配音轨空列表 `StudioEmptyState`；波形条色 `tokens.primary` |
| 黄金图回归 | 全量 `desktop_layouts` + `ui_gallery` wave1–3 + `platform_status` / `help_hub` 已同步 |
| 阶段 5：空状态补漏 | 版本管理、时间轴、Help 有效链接、账户导出、审计、资产角标、管理台 ACL、团队邀请筛选、脚本预览 |
| 阶段 5：空状态图标 | `StudioEmptyState` 强调态改为 `primary` 平面圆（去掉 `signalGradient`） |
| 维护文档 | [`studio-visual-debt.md`](studio-visual-debt.md) 基线 grep 与黄金图命令 |
