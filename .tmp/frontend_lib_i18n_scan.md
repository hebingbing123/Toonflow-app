# frontend/lib i18n 扫描报告

生成：`scripts/scan_frontend_lib_i18n.py` → `.tmp/frontend_lib_i18n_scan.md`

## 分批处理说明

- **批次 1（Tier 1）**：无插值的简单字面量 `Text('...')`、`title: '...'` 等；优先替换为 `AppLocalizations` / 现有 l10n 方法。
- **批次 2（Tier 2）**：含 `${}` / `$var` 但行内仍有裸英文词且未使用 `l10n.`；多为拼接胶水文案，应改为占位符字符串或拆成多条 l10n。
- **可忽略**：纯数字、HTTP 方法前缀、短 snake_case 字段名、`rust_api` 请求体 key 等。

- 扫描根：`/Users/clive/Documents/source/cousor/Toonflow-app/frontend/lib`
- 命中总数：**0**（Tier1: 0, Tier2: 0）

## Tier 1 — 简单字面量（建议优先批量入库）

_（无）_

## Tier 2 — 插值行内裸英文（需人工拆句）

_（无）_

## 建议的批量处理流程（脚本化）

1. 对 Tier 1：按顶层目录开 PR（例如先 `project_editor/`，再 `shell/`）。
2. 每个 key：`app_en.arb` + `app_zh.arb` 同步新增，`flutter gen-l10n`。
3. 对 Tier 2：逐条改为 `l10n.xxx(a: ..., b: ...)` 或复用已有带占位符的条目。
4. CI 可选：在 PR 中附加本扫描报告 diff，避免回潮。
