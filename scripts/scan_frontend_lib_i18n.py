#!/usr/bin/env python3
"""
Scan frontend/lib/**/*.dart for likely user-facing string literals.

Pass 1 — simple literals: Text('...') / title: '...' with NO `$` (no interpolation).
Pass 2 — mixed strings: lines with Text(/SelectableText( containing `$` but raw
         English word runs outside `${...}` and without `l10n.` on the line.

Writes: .tmp/frontend_lib_i18n_scan.md
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
LIB = REPO / "frontend" / "lib"
OUT = REPO / ".tmp" / "frontend_lib_i18n_scan.md"

SKIP_NAMES = {
    "app_localizations.dart",
    "app_localizations_en.dart",
    "app_localizations_zh.dart",
}

# Simple single-quoted Dart string (no $ interpolation in source)
SIMPLE_SQ = r"'(?:[^'\\]|\\.)*'"
SIMPLE_DQ = r'"(?:[^"\\]|\\.)*"'
SIMPLE_STR = rf"(?:{SIMPLE_SQ}|{SIMPLE_DQ})"

PARAM_SIMPLE = re.compile(
    rf"(?<!\$)\b(title|label|hint(?:Text)?|tooltip|message|subtitle|semanticLabel|"
    rf"helper(?:Text)?|error(?:Text)?|counter(?:Text)?|placeholder)\s*:\s*({SIMPLE_STR})",
    re.MULTILINE,
)

TEXT_SIMPLE = re.compile(
    rf"(?<![A-Za-z0-9_])(Text|SelectableText|CupertinoButton|ListTile)\s*\(\s*"
    rf"(?:const\s+)?(?:Key\s*\([^)]*\)\s*,\s*)?({SIMPLE_STR})",
    re.MULTILINE,
)


def unquote(s: str) -> str:
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        inner = s[1:-1]
        return (
            inner.replace("\\'", "'")
            .replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\\\", "\\")
        )
    return s


def has_letters(s: str) -> bool:
    return bool(re.search(r"[A-Za-z\u4e00-\u9fff]", s))


def looks_like_api_or_tech(s: str) -> bool:
    t = s.strip()
    if not t:
        return True
    if t.startswith(("http://", "https://", "package:", "assets/", "/api/")):
        return True
    if re.match(r"^(GET|POST|PUT|PATCH|DELETE|HEAD)\s+", t):
        return True
    if re.fullmatch(r"[\d\s.,:/+\-–—x×]+", t, flags=re.I):
        return True
    if re.fullmatch(r"[\d.]+", t, flags=re.I):
        return True
    if t in {".", ",", ":", ";", "?", "!", "%", "…", "/", "-", "—"}:
        return True
    if re.fullmatch(r"[a-z][a-z0-9_]{1,40}", t) and "_" in t:
        return True
    return False


def raw_english_outside_interpolation(s: str) -> bool:
    """ASCII word runs outside ${...} and outside $id."""
    if "l10n." in s or "AppLocalizations.of" in s:
        return False
    rest = s
    while "${" in rest:
        i = rest.index("${")
        before = rest[:i]
        j = rest.find("}", i)
        if j < 0:
            rest = before
            break
        rest = before + rest[j + 1 :]
    rest = re.sub(r"\$[a-zA-Z_][a-zA-Z0-9_]*", " ", rest)
    return bool(re.search(r"[A-Za-z]{4,}", rest))


@dataclass(frozen=True)
class Hit:
    tier: str
    category: str
    line: int
    snippet: str
    value: str


def should_skip_path(path: Path) -> bool:
    rel = path.relative_to(LIB)
    if rel.parts and rel.parts[0] == "l10n" and path.name in SKIP_NAMES:
        return True
    return False


def scan_file(path: Path) -> list[Hit]:
    if should_skip_path(path):
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    hits: list[Hit] = []

    def line_no(pos: int) -> int:
        return text[:pos].count("\n") + 1

    def add(tier: str, cat: str, pos: int, raw: str) -> None:
        val = unquote(raw)
        if "$" in val:
            return
        if len(val) < 2:
            return
        if not has_letters(val):
            return
        if looks_like_api_or_tech(val):
            return
        ln = line_no(pos)
        line_text = lines[ln - 1] if 0 < ln <= len(lines) else ""
        if "ignore:" in line_text:
            return
        hits.append(Hit(tier, cat, ln, line_text.strip()[:220], val[:400]))

    for m in PARAM_SIMPLE.finditer(text):
        raw = m.group(2)  # whole '...' or "..."
        add("1_simple", "param_string", m.start(), raw)

    for m in TEXT_SIMPLE.finditer(text):
        raw = m.group(2)
        add("1_simple", "text_widget", m.start(), raw)

# Tier 2: suspicious glue / dev English in UI lines (not exhaustive).
TIER2_SUBSTRINGS = re.compile(
    r"(?i)(invite\s+token|please\s+enter|unexpected\s+response|emotion:|"
    r"\bscope=|\benv:|\bHTTP\s|\bPASS\b|\bFAIL\b|vendors:|agent-deploy:)",
    re.MULTILINE,
)


def tier2_line_suspicious(line: str) -> bool:
    if "Text(" not in line and "SelectableText(" not in line:
        return False
    if "$" not in line:
        return False
    if "l10n." in line or "AppLocalizations" in line:
        return False
    if not TIER2_SUBSTRINGS.search(line):
        return False
    return raw_english_outside_interpolation(line)

    seen: set[tuple] = set()
    out: list[Hit] = []
    for h in hits:
        k = (h.tier, h.category, h.line, h.value)
        if k in seen:
            continue
        seen.add(k)
        out.append(h)
    out.sort(key=lambda x: (x.tier, str(path), x.line))
    return out


def main() -> int:
    if not LIB.is_dir():
        print(f"Missing {LIB}", file=sys.stderr)
        return 1

    by_tier_dir: dict[tuple[str, str], list[tuple[str, Hit]]] = defaultdict(list)
    counts: dict[str, int] = defaultdict(int)

    for path in sorted(LIB.rglob("*.dart")):
        hs = scan_file(path)
        if not hs:
            continue
        rel = str(path.relative_to(LIB))
        top = Path(rel).parts[0] if rel else "."
        for h in hs:
            by_tier_dir[(h.tier, top)].append((rel, h))
            counts[h.tier] += 1

    OUT.parent.mkdir(parents=True, exist_ok=True)
    o: list[str] = []
    o.append("# frontend/lib i18n 扫描报告\n\n")
    o.append(
        "生成：`scripts/scan_frontend_lib_i18n.py` → `.tmp/frontend_lib_i18n_scan.md`\n\n"
    )
    o.append("## 分批处理说明\n\n")
    o.append(
        "- **批次 1（Tier 1）**：无插值的简单字面量 `Text('...')`、`title: '...'` 等；"
        "优先替换为 `AppLocalizations` / 现有 l10n 方法。\n"
    )
    o.append(
        "- **批次 2（Tier 2）**：含 `${}` / `$var` 但行内仍有裸英文词且未使用 `l10n.`；"
        "多为拼接胶水文案，应改为占位符字符串或拆成多条 l10n。\n"
    )
    o.append(
        "- **可忽略**：纯数字、HTTP 方法前缀、短 snake_case 字段名、`rust_api` 请求体 key 等。\n\n"
    )

    total = sum(counts.values())
    o.append(f"- 扫描根：`{LIB}`\n")
    o.append(
        f"- 命中总数：**{total}**（Tier1: {counts['1_simple']}, Tier2: {counts['2_mixed']}）\n\n"
    )

    for tier, title in (
        ("1_simple", "## Tier 1 — 简单字面量（建议优先批量入库）\n\n"),
        ("2_mixed", "## Tier 2 — 插值行内裸英文（需人工拆句）\n\n"),
    ):
        o.append(title)
        tier_dirs = {k[1]: v for k, v in by_tier_dir.items() if k[0] == tier}
        if not tier_dirs:
            o.append("_（无）_\n\n")
            continue
        for top in sorted(tier_dirs, key=lambda t: (-len(tier_dirs[t]), t)):
            entries = tier_dirs[top]
            o.append(f"### `{top}/`（{len(entries)} 条）\n\n")
            by_file: dict[str, list[Hit]] = defaultdict(list)
            for rel, h in entries:
                by_file[rel].append(h)
            for rel in sorted(by_file):
                o.append(f"- **{rel}**\n")
                for h in sorted(by_file[rel], key=lambda x: x.line):
                    disp = h.value.replace("\n", " ")
                    o.append(
                        f"  - L{h.line} [{h.category}] `{disp[:140]}"
                        + ("…`" if len(disp) > 140 else "`")
                        + "\n"
                    )
            o.append("\n")

    o.append("## 建议的批量处理流程（脚本化）\n\n")
    o.append("1. 对 Tier 1：按顶层目录开 PR（例如先 `project_editor/`，再 `shell/`）。\n")
    o.append("2. 每个 key：`app_en.arb` + `app_zh.arb` 同步新增，`flutter gen-l10n`。\n")
    o.append("3. 对 Tier 2：逐条改为 `l10n.xxx(a: ..., b: ...)` 或复用已有带占位符的条目。\n")
    o.append("4. CI 可选：在 PR 中附加本扫描报告 diff，避免回潮。\n")

    OUT.write_text("".join(o), encoding="utf-8")
    print(f"Wrote {OUT} (total {total})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
