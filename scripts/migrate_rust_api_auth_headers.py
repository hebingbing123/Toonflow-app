#!/usr/bin/env python3
"""Replace bare Bearer headers with rustApiAuthHeaders / rustApiJsonAuthHeaders."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "frontend" / "lib" / "rust_api"
SKIP = {"core.dart", "workspace_scope.dart"}

JSON_HEADER = re.compile(
    r"headers:\s*\{\s*\n\s*'Authorization': 'Bearer \$(\w+)',\s*\n\s*'Content-Type': 'application/json',\s*\n\s*\}",
    re.MULTILINE,
)

JSON_HEADER_FINAL = re.compile(
    r"final headers = <String, String>\{\s*\n\s*'Authorization': 'Bearer \$(\w+)',\s*\n\s*'Content-Type': 'application/json',\s*\n\s*\};",
    re.MULTILINE,
)

SIMPLE_HEADER = re.compile(
    r"headers: \{'Authorization': 'Bearer \$(\w+)'\}"
)

SIMPLE_HEADER_SPACED = re.compile(
    r"headers: \{\s*'Authorization': 'Bearer \$(\w+)',\s*\}"
)


def core_import_for(path: Path) -> str:
    rel = path.parent.relative_to(ROOT)
    depth = len(rel.parts)
    prefix = "../" * depth if depth > 0 else ""
    return f"import '{prefix}core.dart';"


def ensure_core_import(text: str, path: Path) -> str:
    imp = core_import_for(path)
    if "core.dart" in text:
        return text
    lines = text.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    insert_at = last_import + 1
    lines.insert(insert_at, imp + "\n")
    return "".join(lines)


def migrate_file(path: Path) -> bool:
    if path.name in SKIP:
        return False
    original = path.read_text(encoding="utf-8")
    text = original

    text = JSON_HEADER.sub(
        lambda m: f"headers: rustApiJsonAuthHeaders({m.group(1)})", text
    )
    text = JSON_HEADER_FINAL.sub(
        lambda m: f"final headers = rustApiJsonAuthHeaders({m.group(1)});", text
    )
    text = SIMPLE_HEADER.sub(
        lambda m: f"headers: rustApiAuthHeaders({m.group(1)})", text
    )
    text = SIMPLE_HEADER_SPACED.sub(
        lambda m: f"headers: rustApiAuthHeaders({m.group(1)})", text
    )

    # Remaining inline Authorization lines inside multiline maps (spread).
    text = re.sub(
        r"(<String, String>\{\s*\n)\s*'Authorization': 'Bearer \$(\w+)',\n",
        r"\1      ...rustApiAuthHeaders(\2),\n",
        text,
    )

    if text == original:
        return False
    text = ensure_core_import(text, path)
    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for path in sorted(ROOT.rglob("*.dart")):
        if migrate_file(path):
            changed += 1
            print(f"updated {path.relative_to(ROOT.parent.parent.parent)}")
    print(f"done: {changed} files")


if __name__ == "__main__":
    main()
