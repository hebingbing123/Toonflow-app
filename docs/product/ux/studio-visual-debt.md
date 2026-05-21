# Studio 视觉债务基线（维护用）

与 [`studio-visual-guidelines.md`](studio-visual-guidelines.md) 配套。巡检收口完成后用于 **PR 回归对比**，不要求每次为 0。

## 建议门禁（本地 / CI 可选）

在 `frontend/` 目录执行：

```bash
# 业务代码勿用 M3 状态色（允许 tokens/theme/login 品牌层）
rg 'Colors\.(green|red|orange|blue|grey)' lib --glob '*.dart' \
  --glob '!lib/design_system/tokens.dart' \
  --glob '!lib/design_system/theme.dart' || true

# 勿缩小全局点击热区
rg 'MaterialTapTargetSize\.shrinkWrap|tapTargetSize: MaterialTapTargetSize\.shrinkWrap' lib --glob '*.dart' || true

# 紧凑字号（除 tokens 定义外）
rg 'fontSize:\s*(10|11)\b' lib --glob '*.dart' || true

# 空列表勿裸 Text（人工扫一眼命中）
rg "isEmpty\)" lib --glob '*.dart' -A2 | rg "Text\(" || true
```

## 已知可保留例外

| 项 | 说明 |
|----|------|
| `login_page.dart` 品牌渐变 / 白字 | 登录营销层，非工作台 |
| `pipeline_step_chip` + `useStudioTokens: false` | 非 Studio harness 回退 M3 |
| `ListView` + `shrinkWrap` + `NeverScrollableScrollPhysics` | 嵌套于 `SingleChildScrollView` 的列表常见模式；新代码优先 `Column` 或 sliver |
| `tokens.panelGlow` 字段 | 渐变定义用，运行时 UI 基本不引用 |

## 黄金图

更新视觉后同步：

```bash
cd frontend
flutter test test/ui/desktop_layout_widget_gallery_test.dart --update-goldens
flutter test test/ui/ui_gallery_wave1_golden_test.dart --update-goldens
flutter test test/ui/ui_gallery_wave2_golden_test.dart --update-goldens
flutter test test/ui/ui_gallery_wave3_golden_test.dart --update-goldens
flutter test test/ui/platform_status_desktop_golden_test.dart --update-goldens
flutter test test/ui/help_hub_studio_test.dart --update-goldens
```

勿提交 `test/ui/failures/` 临时 diff 图。

## Git 忽略

`frontend/.gitignore` 已忽略 `test/ui/failures/`（本地 golden diff，勿提交）。

## 2026-05 收口结论

- 业务层 `Colors.green/red/...`：**0**
- 全局 `MaterialTapTargetSize.shrinkWrap` 热区：**0**
- 主路径 `EdgeInsets` 游离 `10/14/18`：已映射 `StudioLayoutSpacing`（typography 定义层除外）
- 嵌套 `ListView.shrinkWrap`：主路径已改为 `Column` 或 bounded `ListView`；`GridView.shrinkWrap` + `NeverScrollableScrollPhysics` 仍保留（日历、项目网格等）
- 主路径 `primaryContainer` / `secondaryContainer`：已改为 `StudioTokens.primarySoft` / `accentSoft`（`pipeline_step_chip` 非 Studio 回退除外）
- 主路径空状态：**StudioEmptyState** 三类工厂
- 桌面 / ui_gallery 黄金图：已与 token、光晕、空状态对齐
- 命令面板：`studioInsetPanelDecoration` + `studioCommandPaletteNoResults*` 文案
- 工作台 IA 扩展：项目脚本建议区、Agent 脚本/生产诊断区默认 `StudioWorkbenchSection` 折叠
- 工作台 IA：`StudioWorkbenchSection` 默认可折叠；驾驶舱默认收起（测试用 `project_studio_cockpit_expand` / `studio_workbench_section_toggle`）
- 编辑器对话框：脚本/分镜单条编辑主字段置顶，工作台诊断在底部；批量脚本工作台诊断区置底
- 脚本步小说摘要区：`StudioWorkbenchSection` 默认折叠（`showTitle: false` 内层卡片）
- 次要 `ExpansionTile`（通知高级、项目基础模态默认、预览/兼容块等）默认 `initiallyExpanded: false`
- 登录 Hero：背景网格/舞台阴影略减、动画周期 24s（品牌白字保留）；`01_login` golden 已同步
- UX Comfort：项目首页标题阴影/最近 chip/栅格间距；`studio_getting_started_steps` 间距 token；`export_history_dialog` part 文件 import 修复
- 业务层 `SizedBox(10/14)` / `width: 10|14`：**0**（typography 定义层除外）
