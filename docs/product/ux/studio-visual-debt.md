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

## 2026-05 收口结论

- 业务层 `Colors.green/red/...`：**0**
- 全局 `shrinkWrap` 热区：**0**
- 主路径空状态：**StudioEmptyState** 三类工厂
- 桌面 / ui_gallery 黄金图：已与 token、光晕、空状态对齐
