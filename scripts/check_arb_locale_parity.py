#!/usr/bin/env python3
"""Exit non-zero if app_en.arb and app_zh.arb have different message keys (excluding @metadata)."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def _arb_keys(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    lines = [ln for ln in text.splitlines() if not ln.strip().startswith("//")]
    data = json.loads("\n".join(lines))
    return {k for k in data if not k.startswith("@")}


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    en = root / "frontend/lib/l10n/app_en.arb"
    zh = root / "frontend/lib/l10n/app_zh.arb"
    ke = _arb_keys(en)
    kz = _arb_keys(zh)
    only_en = sorted(ke - kz)
    only_zh = sorted(kz - ke)
    if only_en or only_zh:
        print("ARB key mismatch between app_en.arb and app_zh.arb:", file=sys.stderr)
        if only_en:
            print(f"  Only in EN ({len(only_en)}):", file=sys.stderr)
            for k in only_en[:50]:
                print(f"    {k}", file=sys.stderr)
            if len(only_en) > 50:
                print(f"    ... +{len(only_en) - 50} more", file=sys.stderr)
        if only_zh:
            print(f"  Only in ZH ({len(only_zh)}):", file=sys.stderr)
            for k in only_zh[:50]:
                print(f"    {k}", file=sys.stderr)
            if len(only_zh) > 50:
                print(f"    ... +{len(only_zh) - 50} more", file=sys.stderr)
        return 1
    print("OK: app_en.arb and app_zh.arb have identical message keys.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
