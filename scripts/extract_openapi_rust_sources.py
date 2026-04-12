#!/usr/bin/env python3
"""Split the monolithic OpenAPI file into Rust-side sources (no hand-edited docs/openapi.yaml).

Reads a **full** OpenAPI 3.1 YAML (default: `docs/openapi.yaml` if present), or pass a path:

  python3 scripts/extract_openapi_rust_sources.py path/to/full-openapi.yaml

Writes:
  backend/src/openapi_spec/openapi_base.yaml
    — openapi, info, servers, tags, **paths: {}** (HTTP paths come from utoipa merge), full components
  backend/src/openapi_spec/ws_protocol_description.md
    — `GET /api/v1/ws` long description (for `include_str!` on the upgrade handler)
  backend/src/openapi_spec/openapi_paths_index.yaml
    — { paths: <all paths except /api/v1/ws> } for scripts/gen_openapi_utoipa_stubs.py

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
OUT_WS_MD = ROOT / "backend" / "src" / "openapi_spec" / "ws_protocol_description.md"


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

    desc = ws.get("get", {}).get("description")
    if isinstance(desc, str):
        desc = desc.replace("docs/openapi.yaml", "the exported OpenAPI document")
        OUT_WS_MD.write_text(desc, encoding="utf-8")
        print(f"Wrote {OUT_WS_MD}")

    base = {
        "openapi": doc.get("openapi"),
        "info": doc.get("info"),
        "servers": doc.get("servers"),
        "tags": doc.get("tags"),
        "paths": {},
        "components": doc.get("components"),
    }

    OUT_BASE.parent.mkdir(parents=True, exist_ok=True)
    with OUT_BASE.open("w", encoding="utf-8") as f:
        yaml.dump(base, f, sort_keys=False, allow_unicode=True, width=120)

    paths_index = dict(paths)
    paths_index.pop("/api/v1/ws", None)
    with OUT_PATHS.open("w", encoding="utf-8") as f:
        yaml.dump({"paths": paths_index}, f, sort_keys=False, allow_unicode=True, width=120)

    print(f"Wrote {OUT_BASE}")
    print(f"Wrote {OUT_PATHS}")


if __name__ == "__main__":
    main()
