#!/usr/bin/env python3
"""Inject #[utoipa::path(...)] before each production workbench handler listed in production/mod.rs.

Uses docs/openapi.yaml for operation_id. Request/response bodies documented as serde_json::Value
(actual handlers may return axum::Response — OpenAPI still shows JSON object schema).
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "backend/src/production/mod.rs"
YAML = ROOT / "docs/openapi.yaml"
WB = ROOT / "backend/src/production/workbench"


def main() -> None:
    doc = yaml.safe_load(YAML.read_text(encoding="utf-8"))
    paths_doc = doc["paths"]

    mod_txt = MOD.read_text(encoding="utf-8")
    routes = re.findall(
        r'\.route\(\s*"([^"]+)"\s*,\s*post\((workbench::\w+::(\w+))\)\s*,?\s*\)',
        mod_txt,
        re.DOTALL,
    )
    # routes: list of (api_path, full_qual, fn_name)

    op_ids: dict[tuple[str, str], str] = {}
    for p, item in paths_doc.items():
        if not p.startswith("/api/v1/production"):
            continue
        if "post" in item:
            op_ids[(p, "post")] = item["post"]["operationId"]

    per_file: dict[Path, list[tuple[str, str, str]]] = {}
    for api_path, full, fn_name in routes:
        if not api_path.startswith("/api/v1/production"):
            continue
        parts = full.split("::")
        if len(parts) != 3 or parts[0] != "workbench":
            raise SystemExit(f"unexpected handler path {full}")
        _, submod, _ = parts
        file = WB / f"{submod}.rs"
        oid = op_ids.get((api_path, "post"))
        if not oid:
            raise SystemExit(f"no operationId for POST {api_path}")
        per_file.setdefault(file, []).append((fn_name, api_path, oid))

    block_tpl = '''#[utoipa::path(
    post,
    path = "{path}",
    operation_id = "{oid}",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
'''

    for path, entries in sorted(per_file.items()):
        text = path.read_text(encoding="utf-8")
        for fn_name, api_path, oid in sorted(entries, key=lambda x: x[0]):
            block = block_tpl.format(path=api_path, oid=oid)
            # match pub(...) async fn NAME or async fn NAME
            pat = rf"(pub\(in crate::production\) async fn {re.escape(fn_name)}|pub\(crate\) async fn {re.escape(fn_name)}|async fn {re.escape(fn_name)})"
            m = re.search(pat, text)
            if not m:
                raise SystemExit(f"{path}: cannot find fn {fn_name}")
            pos = m.start()
            if text[pos - 15 : pos].strip().endswith(")]"):
                print(f"skip fn {fn_name} in {path.name} (already annotated)")
                continue
            text = text[:pos] + block + text[pos:]

        path.write_text(text, encoding="utf-8")
        print(f"updated {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
