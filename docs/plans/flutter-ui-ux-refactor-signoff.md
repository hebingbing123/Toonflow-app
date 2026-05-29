# Flutter UI/UX 架构重构 — 验收与遗留

日期：2026-05-29（第二十六轮 — 清单收官）

## 第二十六轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 18 | `.frag` 毛玻璃：`shaders/studio_glass_blur.frag` + `STUDIO_GLASS_SHADER` + `studio_glass_shader.dart` |
| 11.2 | 短视频批量**发布**乐观 UI；本地**项目置顶**（`StudioPinnedProjectsPrefs`） |
| 28 | `studio_ops_dashboard.sh` → 静态 `docs/ops/studio-ops-dashboard.html` |
| 22.1 | `flutter_coverage_report.sh --write-baseline` / `--gate-min` + `docs/metrics/flutter-coverage-baseline.json` |
| 27.4 | `gen_flutter_dartdoc.sh` → `docs/api/flutter-design-system` |
| 29.2/29.3 | [`flutter-ui-ux-manual-a11y-matrix.md`](flutter-ui-ux-manual-a11y-matrix.md) 手工验收表 |
| 测试 | `studio_glass_shader_test` 等 ✅ |

## 第二十五轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 11.2 | API 密钥 revoke/activate/delete；工作区切换当前项；内容合规 claim/resolve/批量操作 |
| 真源 | `studio_optimistic_api_key.dart`、`content_compliance/optimistic_queue.dart` |
| 测试 | `studio_optimistic_api_key_test`、`optimistic_queue_test` ✅ |

## 第二十四轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 契约修复 | 发布批量 `archived`/`enqueued`/`failed` 与 OpenAPI 对齐（修复 `archived_count` 等错误字段） |
| 后端 | `batch_archive_drafts` 返回逐条 `failed`；PG 契约测试 batch-archive + 合规模板删除 |
| 前端 | 批量归档部分失败回滚；批量排期乐观 UI；`studio_optimistic_publish_draft.dart` |
| 测试 | `publish_batch_models_test` + 既有 optimistic 套件 ✅ |

## 第二十三轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 11.2 | 团队工作区归档/恢复；短视频发布草稿批量归档；通知合规模板删除（个人 + 工作区共享） |
| 真源 | `studio_optimistic_workspace.dart`、`optimistic_templates.dart` |
| 测试 | `studio_optimistic_workspace_test` + 既有 optimistic 套件共 8 项 ✅ |

## 第二十二轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 11.2 | 通知 `markAllRead`；作业 `cancelQueuedJob` / `retryFailedJob`；任务中心工作台 cancel/retry |
| 真源 | `studio_optimistic_job.dart`、`studioNotificationsMarkAllRead` |
| 测试 | `studio_optimistic_job_test` 等 5 项 ✅ |

## 第二十一轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 17.x | `StudioSparklineChart` / `StudioBarChart`；用量面板 + 平台状态趋势 |
| 11.2 | `studioRunOptimisticMutation` + 通知 `markRead` 乐观回滚 |
| 20.3 | `StudioTransferQueue` + 作业托盘 Sheet |
| 28 | `scripts/studio_ops_health_check.sh` + 降级端点 sparkline |
| 22.1 | `scripts/flutter_coverage_report.sh`（KPI 基线，非 80% 门禁） |
| 27.1 | [`flutter-ui-ux-adr-index.md`](flutter-ui-ux-adr-index.md) |
| 测试 | sparkline + optimistic 单元测试 ✅ |

## 第二十轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 8.2 | `state/immutable_state_template.dart` |
| 9.3 | `DeferredBenchmarkSection`（deferred import） |
| 9.4 | `platform/studio_isolate_json.dart` |
| 11.2 | `StudioOfflineCache` + 作业队列离线回退 |
| 19.3 | `flutter_local_notifications` / `StudioDesktopNotifications` |
| 20.1b | `desktop_drop` + `studio_native_file_drop.dart` |
| 26.3 / 29.1 | `scripts/flutter_perf_smoke.sh`、`flutter_startup_smoke.sh` |
| 30 | [`flutter-ui-ux-refactor-release-notes.md`](flutter-ui-ux-refactor-release-notes.md) |
| 验证 | `flutter analyze` 改动文件 ✅；**全量测试待合并前** |

## 第十九轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 24.3 | Help Hub 文档 Tab：`StudioKeyboardShortcutsPanel` + `buildStudioProductKeyboardShortcuts` |
| 27.3 | [`flutter-ui-ux-developer-guide.md`](flutter-ui-ux-developer-guide.md) |
| 3.4 | visual-debt 校验 jobs/task/quality 使用 `StudioAsyncDataView` |
| 清单 | Kiro `tasks.md` 可执行项全部 `[x]`；⬜ 见下表 |
| 门禁 | `yarn refactor:agent --full`（收官） |

## 第十八轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 7.1 | **`StudioAlertDialog`** 单字段对话框自动 Enter→主 [FilledButton]；多字段不自动绑定 |
| 真源 | `studioResolveAlertDialogEnterSubmit` / `studioCountSingleLineTextFields` @ `studio_form_keyboard.dart` |
| 覆盖 | 全局搜索保存视图、短视频批处理时长等 `StudioAlertDialog` 无需逐处改 |
| 测试 | `studio_form_keyboard_test` + `studio_dialog_shell_test`（局部，未跑全门禁） |

## 第十七轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 10.2 | **`platform/studio_content_heuristics.dart`**：质检/分镜/Agent/爬虫/后端枚举等全部非 UI 中文令牌 |
| 门禁 | `scan_frontend_lib_i18n.py --check-tier1` 增 **CJK 字面量** 检查（仅允许 heuristics 单文件） |
| 修复 | writeback 芯片按 `status` 判色；`isBackendDefaultPersonalWorkspaceName` 走 arb |
| 测试 | `studio_content_heuristics_test` + demo/short_video 绿 |

## 第十六轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 命令面板 | `studioCommandPaletteKeywords*` + `studio_command_palette_keywords.dart`；`build_product_shell` 去硬编码双语 keywords |
| 短视频 | `shortVideoWritebackIndicatesProblem` 按 API `status` 着色；修复英文 failed 文案误判为成功态 |
| 扫描 | Tier1 增 `command_palette_keywords` 类；`--check-tier1` 仍 0 |
| 测试 | `short_video_space_support_test` writeback 断言 + 全 demo 套件此前已绿 |

## 第十五轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 导览主线 | 16 个 SOP 拍 + 2 个上线拍全部迁入 arb（`demoTourScript*` … `demoTourLaunchPublish*`） |
| 真源 | `product_demo_tour_mainline_l10n.dart` + `scripts/gen_demo_tour_mainline_arb.py`（增删 beat 时重跑） |
| `product_demo_tour_stops.dart` | **零**内联用户文案；`frontend/lib/demo/` 无残留中文 |
| 修复 | `app_en.arb` 补回 `studioGettingStartedTitle`（parity 回归） |
| 门禁 | Tier1 **0**；`test/demo/` **29** 项全绿 |

## 第十四轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 导览 | `demoTour*`：intro / 主线 shortLabel / 上线两拍 / utility 7 拍入 arb；`demo_tour_bilingual_l10n.dart` 双 locale lookup |
| 项目名 | intro 文案用 `demoStudioProjectDisplayName` 占位，与 catalog 同步 |
| 404 | 补 `studioNotFoundBackToHome`（路由页已引用、arb 缺键） |
| 扫描 | Tier1 **0**；`product_demo_tour_modes_test` / autoplay 绿 |
| 遗留 | 主线 SOP 各拍 `ProductDemoTourGuideSections` 正文仍内联 zh/en（约 108 处），下一批按 step 迁入 arb |

## 第十三轮（2026-05-29）

| 项 | 交付 |
|----|------|
| demo 数据 | `studio_demo_data` 短视频装配/时间轴/分镜 prompt、资产 hub 待锚点计数入 arb |
| demo 目录 | `product_demo_catalog` 任务分类行；`agent_workspace_demo_data` WS 助手 JSON 行 |
| 扫描 | Tier1 **0**；`studio-visual-debt-check.sh` 绿 |
| 测试 | `product_demo_mode_test` 绿 |
| 后续 | 导览正文内联 → 第十五轮完成 |

## 第十二轮（2026-05-29）

| 项 | 交付 |
|----|------|
| CI | `scan_frontend_lib_i18n.py --check-tier1` @ `studio-visual-debt-check.sh` |
| demo | `demoStudio*` 工作室首页驾驶舱 + 资产 hub 叙事入 arb |
| 文档 | [`flutter-ui-ux-l10n-conventions.md`](flutter-ui-ux-l10n-conventions.md) 补 `--check-tier1` |

## 第十一轮（2026-05-29）

| 项 | 交付 |
|----|------|
| status_page | `statusPageEndpoint*` 三端点标签入 arb |
| platform_config | `platformConfigPlanOverridesEnvLabel` |
| demo a11y | `ProductDemoCoachKeys.semanticsOverlay` |
| 扫描 | Tier1 **0**；`looks_like_api_or_tech` 补 `/path`、`env:`、kebab-case |
| 文档示例 | `studio_icon_button` dartdoc 去掉硬编码示例 |

## 第十轮（2026-05-29）

| 项 | 交付 |
|----|------|
| native_bridge | `NativeBridgeStartupSnapshot.message` 默认空；UI 继续 `native_bridge_startup_labels.dart` + 既有 arb |
| demo | `buildDemoHelpHubConfig(l10n)`、`buildDemoStudioProjectHome(l10n)`、`ProductDemoCatalog.buildDefault(l10n?)`、通知/清单/发布草稿 |
| 快捷键 | `studioCommandPaletteShortcutMac/Windows` @ onboarding coach |
| 扫描 | Tier1 **5** 条（自 62 → 5，约 92% 清除） |

## 第九轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 丢弃/离开确认 | `studioDiscard*` @ art_step / create_wizard / script_editor |
| 404 | `studioNotFound*` @ `studio_route_guards.dart` |
| 项目治理 | `projectMembersRemoveAclConfirmMessage`；`projectsArtStyleDeleteConfirm*` |
| 编辑器 probe | `projectEditorProbe*` @ scripts/novels/assets 探测确认 |
| 设置 | `settingsModelVendorsDeleteCredential*` |
| 短视频 / Shell | `studioDiscardPublishCopyMessage`；`skillsHarnessRevokeWasm*`；`studioSidebarProductLabel` |
| 扫描 | Tier1 **29** 条（自 62 起累计降 53%） |

## 第八轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 设计系统 i18n | `studioDesignTableEmptyLabel`、`studioDesignBreadcrumbSemanticsLabel`、`studioDesignDebugCopyErrorLabel` |
| 组件接线 | `studio_table.dart`、`studio_breadcrumb.dart`、`debug_overlay_widget.dart` |
| Shell i18n | `build_product_shell.dart` 后退/前进复用 `studioBackPreviousPane` + 新增 `studioNavigationForward` |
| 工具 | `scripts/scan_frontend_lib_i18n.py` 修复 `scan_file` 未返回命中（Tier1 现 ~57 条，见 `.tmp/frontend_lib_i18n_scan.md`） |
| 测试 | `studio_data_components_test` 空表本地化断言 |

## 第七轮（2026-05-29）

| 项 | 交付 |
|----|------|
| 设计系统 i18n | `studioDesignFileDropZoneLabel`、`studioDesignPaginationPrevious/Next`、`studioDesignTransferCancel` @ `app_en.arb` / `app_zh.arb` |
| 组件接线 | `studio_file_drop_zone.dart`、`studio_pagination.dart`、`studio_transfer_progress.dart` 默认文案走 `AppLocalizations` |
| Kiro | [`.kiro/specs/.../tasks.md`](../../.kiro/specs/flutter-ui-ux-architecture-refactor/tasks.md) 10.2 / 16.2 / 20.1–20.2 注释更新 |

## 已完成

| 区域 | 交付 |
|------|------|
| P0–P2 组件/治理 | 见第四轮 + 本轮：`StudioTooltip`、`StudioTransferProgress`、`studio_page_transitions.dart` |
| 路由动效 | 搜索/状态 fade、项目工作室 push 统一 `StudioMotion` 时长/曲线 |
| l10n 门禁 | `check_arb_locale_parity.py` 接入 `studio-visual-debt-check.sh`；[`flutter-ui-ux-l10n-conventions.md`](flutter-ui-ux-l10n-conventions.md) |
| Visual debt | 全绿（含 contrast + ARB parity） |
| 测试 | `studio_round5_components_test.dart`；`yarn refactor:agent --full` 绿 |

## 明确推迟（⬜）

无（可编码项已交付）。**80% 行覆盖率数值达标**仍为团队 KPI：`--gate-min 80` 可选启用，勿在未达标的分支强开。

## 持续治理（🟡）

- 新增 UI 文案随 PR 迁入 `.arb`；**10.2 UI 轨道已 ✅**（Tier1 + CJK 门禁）
- 非 UI 令牌仅增于 `platform/studio_content_heuristics.dart`
- `const` / 虚拟列表 / RepaintBoundary 热点

| Kiro 清单 | [`.kiro/specs/.../tasks.md`](../../.kiro/specs/flutter-ui-ux-architecture-refactor/tasks.md) 已勾选 ✅ / ⬜ / 🟡 |

## 计划完成声明

按 [`flutter-ui-ux-refactor-18-phases.md`](flutter-ui-ux-refactor-18-phases.md)：**A 类（规范+门禁）与 B 类（高收益扫尾）可执行项已交付**；C 类 ⬜ 见上表。Kiro `tasks.md` 中工程化 26–30（仪表板、80% 覆盖、全平台手工验收）为 **ops/团队流程**，不阻塞代码合并。

## 门禁

```bash
bash scripts/studio-visual-debt-check.sh
yarn refactor:agent --full
bash scripts/run-ui-ux-audit-e2e.sh   # 改 Shell / 布局后
python3 scripts/check_arb_locale_parity.py
python3 scripts/scan_frontend_lib_i18n.py --check-tier1
```

## 真源

- [18 阶段对照](flutter-ui-ux-refactor-18-phases.md)
- [Kiro tasks](.kiro/specs/flutter-ui-ux-architecture-refactor/tasks.md)
