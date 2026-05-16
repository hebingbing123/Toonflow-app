"""Shared helpers: read `(path, method) -> operationId` from committed `openapi_spec/generated/*.rs`.

Used by `inject_utoipa_routes.py` / `inject_production_utoipa.py` so they do not depend on
`openapi_paths_index.yaml` (removed from the merge pipeline).
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_GEN_DIR = ROOT / "backend" / "src" / "openapi_spec" / "generated"
_STUB_BLOCK = re.compile(
    r"#\[utoipa::path\(\s*(get|post|put|patch|delete)\s*,\s*path\s*=\s*\"([^\"]+)\""
    r"[\s\S]*?operation_id\s*=\s*\"([^\"]+)\"",
    re.MULTILINE,
)


def operation_index_map() -> dict[tuple[str, str], str]:
    """Map (OpenAPI path string, lower-case HTTP method) -> operationId."""
    out: dict[tuple[str, str], str] = {}
    for f in sorted(_GEN_DIR.glob("*.rs")):
        if f.name == "mod.rs":
            continue
        text = f.read_text(encoding="utf-8")
        for m in _STUB_BLOCK.finditer(text):
            method, path, oid = m.group(1), m.group(2), m.group(3)
            out[(path, method)] = oid
    return out
