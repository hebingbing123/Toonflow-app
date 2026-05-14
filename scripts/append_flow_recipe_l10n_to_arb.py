#!/usr/bin/env python3
"""Merge scripts/flow_recipe_l10n_data.json into frontend/lib/l10n/app_en.arb and app_zh.arb."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "scripts" / "flow_recipe_l10n_data.json"
APP_EN = ROOT / "frontend" / "lib" / "l10n" / "app_en.arb"
APP_ZH = ROOT / "frontend" / "lib" / "l10n" / "app_zh.arb"


def load_arb(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_arb(path: Path, data: dict[str, object]) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    path.write_text(text, encoding="utf-8")


def main() -> None:
    bundle = json.loads(DATA.read_text(encoding="utf-8"))
    simple: dict[str, dict[str, str]] = bundle["simple"]
    templates: dict[str, dict[str, object]] = bundle["templates"]

    en_data = load_arb(APP_EN)
    zh_data = load_arb(APP_ZH)

    for key, langs in simple.items():
        if key in en_data:
            raise SystemExit(f"duplicate key in app_en.arb: {key}")
        en_data[key] = langs["en"]
        zh_data[key] = langs["zh"]

    for key, spec in templates.items():
        meta_key = f"@{key}"
        if key in en_data:
            raise SystemExit(f"duplicate key in app_en.arb: {key}")
        placeholders = spec["placeholders"]
        meta = {"placeholders": {p: {"type": t} for p, t in placeholders.items()}}
        en_data[meta_key] = meta
        zh_data[meta_key] = meta
        en_data[key] = spec["en"]
        zh_data[key] = spec["zh"]

    dump_arb(APP_EN, en_data)
    dump_arb(APP_ZH, zh_data)
    print(f"merged {len(simple) + len(templates)} keys into app_en.arb / app_zh.arb")


if __name__ == "__main__":
    main()
