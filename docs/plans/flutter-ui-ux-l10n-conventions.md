# Flutter l10n 键命名约定

真源：`frontend/lib/l10n/app_en.arb`、`app_zh.arb`；生成类 `AppLocalizations`。

## 键名格式

```
<feature>.<surface>.<element>.<actionOrState>
```

示例：

| 键 | 含义 |
|----|------|
| `themeSectionTitle` | 设置块标题（feature 可省略当全局壳层） |
| `projectEditorAssetClipUploadDialogTitle` | 项目编辑器 / 资产 / 上传对话框标题 |
| `rustApiClientRetryAfterSeconds` | Rust API 客户端 / 重试 / 秒数占位 |

规则：

- 使用 **camelCase**，不用 snake_case。
- 占位符用 ARB `{name}`，Dart 侧 `@rustApiClientRetryAfterSeconds` 声明 `placeholders`。
- 同一屏共用文案优先复用已有键，避免同义 duplicate。
- **禁止**在用户可见 UI 直接 `Text('…')` 写英文/中文（治理脚本见下）。

## 门禁

```bash
# en/zh 键集合必须一致
python3 scripts/check_arb_locale_parity.py

# 扫描 lib/ 内疑似硬编码（报告写入 .tmp/）
python3 scripts/scan_frontend_lib_i18n.py

# CI：Tier1 与 CJK 字面量（UI 区）必须为 0
python3 scripts/scan_frontend_lib_i18n.py --check-tier1
# 含 CJK：仅允许 frontend/lib/platform/studio_content_heuristics.dart

# 视觉 + l10n 合并入口（含 Tier1 门禁）
bash scripts/studio-visual-debt-check.sh
```

## 迁移节奏（🟡 持续治理）

1. 改 UI 时顺带提取触达字符串到 `.arb`。
2. 运行 `flutter gen-l10n`（或 `flutter pub get` 触发生成）。
3. 新键 **en + zh 同 PR** 提交。
4. 全库批量提取标 ⬜，见 [`flutter-ui-ux-refactor-signoff.md`](flutter-ui-ux-refactor-signoff.md)。

## Demo 产品导览（例外与节奏）

- [`product_demo_tour_stops.dart`](../../frontend/lib/demo/product_demo_tour_stops.dart) 使用 **zh/en 双轨** `ProductDemoTourStop`，以便导览在 `ProductDemoTour.languageCode` 切换时无需重建 stops。
- 构建时用 [`demo_tour_bilingual_l10n.dart`](../../frontend/lib/demo/demo_tour_bilingual_l10n.dart) 的 `lookupAppLocalizations(zh|en)` 从 arb 填充双轨；intro 等项目名须用 `demoStudioProjectDisplayName` 占位，勿写死季节剧名。
- Tier1 扫描 **不**统计 `titleZh:` 等导览字段；文案真源为 arb，构建时用 `demo_tour_bilingual_l10n.dart` 的 `lookupAppLocalizations(zh|en)` 填充双轨。
- 主线/上线节拍键名：`demoTour{BeatId}{Title|Position|Goal|BulletN|DemoNote|NextHint}`；Dart 映射见 `product_demo_tour_mainline_l10n.dart`。
- 命令面板搜索别名：`studioCommandPaletteKeywords*`（逗号分隔，含中英双语别名）；用 `studio_command_palette_keywords.dart` 解析，禁止 `keywords: <String>['项目']` 内联。
- 判态/着色须基于 API code（如 `shortVideoWritebackIndicatesProblem`），禁止对 `l10n` 渲染后的字符串做 `.contains('失败')`。
- 非 UI 中文/英文匹配令牌、爬虫正则、Rust 契约字面量 → [`platform/studio_content_heuristics.dart`](../../frontend/lib/platform/studio_content_heuristics.dart)（**禁止**散落 `lib/` 其它文件）。
