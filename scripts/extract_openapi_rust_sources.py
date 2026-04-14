#!/usr/bin/env python3
"""Split full OpenAPI into Rust-side helper artifacts.

Reads a full OpenAPI 3.1 YAML (default: `docs/openapi.yaml`, or pass a path):

  python3 scripts/extract_openapi_rust_sources.py path/to/full-openapi.yaml

Writes:
  - `backend/src/openapi_spec/embedded/legacy_component_schemas.json`
      Kept as `{}` (legacy component registry has been fully removed).
  - `backend/src/openapi_spec/ws_protocol_description.md`
      Description of `GET /api/v1/ws` for the upgrade handler `include_str!`.
  - `scripts/fixtures/openapi_stub_input.yaml`
      `{ paths: ... }` input for `scripts/gen_openapi_utoipa_stubs.py`.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SRC = ROOT / "docs" / "openapi.yaml"
OUT_LEGACY_SCHEMAS = (
    ROOT / "backend" / "src" / "openapi_spec" / "embedded" / "legacy_component_schemas.json"
)
OUT_STUB_INPUT = ROOT / "scripts" / "fixtures" / "openapi_stub_input.yaml"
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

    # Legacy component registry has been removed from runtime merge.
    OUT_LEGACY_SCHEMAS.parent.mkdir(parents=True, exist_ok=True)
    OUT_LEGACY_SCHEMAS.write_text("{}\n", encoding="utf-8")

    paths_index = dict(paths)
    paths_index.pop("/api/v1/ws", None)
    OUT_STUB_INPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT_STUB_INPUT.open("w", encoding="utf-8") as f:
        yaml.dump({"paths": paths_index}, f, sort_keys=False, allow_unicode=True, width=120)

    print(f"Wrote {OUT_LEGACY_SCHEMAS}")
    print(f"Wrote {OUT_STUB_INPUT}")


if __name__ == "__main__":
    main()
