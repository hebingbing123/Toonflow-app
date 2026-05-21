#!/usr/bin/env python3
"""Replace legacy 10/14/18 EdgeInsets literals with StudioLayoutSpacing tokens."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "frontend" / "lib"
SKIP = {
    "design_system/studio_typography.dart",
    "design_system/components/studio_primary_button.dart",
}

REPLACEMENTS: list[tuple[str, str]] = [
    (r"EdgeInsets\.all\(10\)", "EdgeInsets.all(StudioLayoutSpacing.inlineGap)"),
    (r"EdgeInsets\.all\(14\)", "EdgeInsets.all(StudioLayoutSpacing.stackMedium)"),
    (r"EdgeInsets\.all\(18\)", "EdgeInsets.all(StudioLayoutSpacing.insetComfortable)"),
    (r"EdgeInsets\.only\(bottom: 10\)", "EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap)"),
    (r"EdgeInsets\.only\(bottom: 14\)", "EdgeInsets.only(bottom: StudioLayoutSpacing.stackMedium)"),
    (r"EdgeInsets\.only\(left: 8, bottom: 10\)", "EdgeInsets.only(left: StudioSpacing.xs, bottom: StudioLayoutSpacing.inlineGap)"),
    (r"EdgeInsets\.symmetric\(horizontal: 10, vertical: 8\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: StudioSpacing.xs)"),
    (r"EdgeInsets\.symmetric\(horizontal: 10, vertical: 6\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: 6)"),
    (r"EdgeInsets\.symmetric\(horizontal: 10, vertical: 5\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: 5)"),
    (r"EdgeInsets\.symmetric\(horizontal: 10, vertical: 9\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.inlineGap, vertical: 9)"),
    (r"EdgeInsets\.symmetric\(horizontal: 12, vertical: 10\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.inlineGap)"),
    (r"EdgeInsets\.symmetric\(horizontal: 16, vertical: 14\)", "EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioLayoutSpacing.stackMedium)"),
    (r"EdgeInsets\.symmetric\(horizontal: 16, vertical: 10\)", "EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioLayoutSpacing.inlineGap)"),
    (r"EdgeInsets\.symmetric\(horizontal: 14, vertical: 2\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.stackMedium, vertical: 2)"),
    (r"EdgeInsets\.symmetric\(horizontal: 12, vertical: 14\)", "EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.stackMedium)"),
    (r"padding: EdgeInsets\.all\(comfortable \? 18 : 16\)", "padding: EdgeInsets.all(comfortable ? StudioLayoutSpacing.insetComfortable : StudioSpacing.sm)"),
    (r"padding: EdgeInsets\.all\(compact \? 14 : 16\)", "padding: EdgeInsets.all(compact ? StudioLayoutSpacing.stackMedium : StudioSpacing.sm)"),
    (r"padding: EdgeInsets\.all\(compact \? 10 : 12\)", "padding: EdgeInsets.all(compact ? StudioLayoutSpacing.inlineGap : StudioLayoutSpacing.insetDense)"),
    (r"margin: const EdgeInsets\.only\(bottom: 10\)", "margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap)"),
    (r"padding: const EdgeInsets\.only\(bottom: 10\)", "padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap)"),
    (r"padding: EdgeInsets\.only\(right: compact \? 10 : 12\)", "padding: EdgeInsets.only(right: compact ? StudioLayoutSpacing.inlineGap : StudioLayoutSpacing.insetDense)"),
]

TOKENS_IMPORT = "import '../design_system/tokens.dart';\n"
TOKENS_IMPORT_ALT = [
    "import '../../design_system/tokens.dart';\n",
    "import '../../../design_system/tokens.dart';\n",
    "import '../../../../design_system/tokens.dart';\n",
]


def needs_tokens_import(text: str) -> bool:
    if "StudioLayoutSpacing" not in text and "StudioSpacing.xs" not in text:
        return False
    return "tokens.dart" not in text


def add_import(text: str, path: Path) -> str:
    rel = path.relative_to(ROOT)
    depth = len(rel.parts) - 1
    imp = f"import {'../' * depth}design_system/tokens.dart';\n"
    if imp.strip() in text or "design_system/tokens.dart" in text:
        return text
    # After last import
    lines = text.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i + 1
    lines.insert(last_import, imp)
    return "".join(lines)


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        rel = path.relative_to(ROOT).as_posix()
        if rel in SKIP or rel.startswith("design_system/") and "tokens.dart" in rel:
            continue
        text = path.read_text(encoding="utf-8")
        orig = text
        for pattern, repl in REPLACEMENTS:
            text = re.sub(pattern, repl, text)
        if text != orig:
            if needs_tokens_import(text):
                text = add_import(text, path)
            path.write_text(text, encoding="utf-8")
            changed += 1
            print(rel)
    print(f"updated {changed} files")


if __name__ == "__main__":
    main()
