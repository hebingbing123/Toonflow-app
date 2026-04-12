#!/usr/bin/env python3
"""Split the monolithic OpenAPI file into Rust-side sources (no hand-edited docs/openapi.yaml).

Reads a **full** OpenAPI 3.1 YAML (default: `docs/openapi.yaml` if present), or pass a path:

  python3 scripts/extract_openapi_rust_sources.py path/to/full-openapi.yaml

Writes:
  backend/src/openapi_spec/openapi_base.yaml
    — openapi, info, servers, tags, paths['/api/v1/ws'] only, full components
  backend/src/openapi_spec/openapi_paths_index.yaml
    — { paths: <all paths> } for scripts/gen_openapi_utoipa_stubs.py

Run from repo root:
  python3 scripts/extract_openapi_rust_sources.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "docs" / "openapi.yaml"
OUT_BASE = ROOT / "backend" / "src" / "openapi_spec" / "openapi_base.yaml"
OUT_PATHS = ROOT / "backend" / "src" / "openapi_spec" / "openapi_paths_index.yaml"


def fix_ws_description(obj: object) -> None:
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "description" and isinstance(v, str):
                obj[k] = v.replace(
                    "docs/openapi.yaml",
                    "the exported OpenAPI document",
                )
            else:
                fix_ws_description(v)
    elif isinstance(obj, list):
        for x in obj:
            fix_ws_description(x)


def main() -> None:
    src = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_SRC
    if not src.is_file():
        raise SystemExit(
            f"missing source file: {src}\n"
            "Pass a full OpenAPI YAML path, or restore docs/openapi.yaml temporarily."
        )

    with src.open(encoding="utf-8") as f:
        doc = yaml.safe_load(f)

    paths = doc.get("paths") or {}
    ws = paths.get("/api/v1/ws")
    if not isinstance(ws, dict):
        raise SystemExit("missing or invalid paths['/api/v1/ws']")

    base = {
        "openapi": doc.get("openapi"),
        "info": doc.get("info"),
        "servers": doc.get("servers"),
        "tags": doc.get("tags"),
        "paths": {"/api/v1/ws": ws},
        "components": doc.get("components"),
    }
    fix_ws_description(base["paths"]["/api/v1/ws"])

    OUT_BASE.parent.mkdir(parents=True, exist_ok=True)
    with OUT_BASE.open("w", encoding="utf-8") as f:
        yaml.dump(base, f, sort_keys=False, allow_unicode=True, width=120)

    with OUT_PATHS.open("w", encoding="utf-8") as f:
        yaml.dump({"paths": paths}, f, sort_keys=False, allow_unicode=True, width=120)

    print(f"Wrote {OUT_BASE}")
    print(f"Wrote {OUT_PATHS}")


if __name__ == "__main__":
    main()
