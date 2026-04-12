#!/usr/bin/env python3
"""
Inject #[utoipa::path(...)] before handler functions based on .route("...", METHOD(handler)) in the same file.

- Parses docs/openapi.yaml for operationId per (path, method).
- For a given --rs-file, finds .route("PATH", METHOD(fn)) and METHOD1(fn1).METHOD2(fn2) chains.
- Inserts utoipa blocks before `async fn FN` (must live in the same .rs file as the router).
- Appends #[derive(OpenApi)] struct at end (--api-struct Name --tag tag).

Example:
  python3 scripts/inject_utoipa_routes.py \\
    --rs-file backend/src/harness/http.rs \\
    --api-struct HarnessOpenApi \\
    --tag harness
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def load_openapi_ops() -> dict[tuple[str, str], str]:
    doc = yaml.safe_load((ROOT / "docs/openapi.yaml").read_text(encoding="utf-8"))
    out: dict[tuple[str, str], str] = {}
    for p, item in doc.get("paths", {}).items():
        for m in ("get", "post", "put", "patch", "delete"):
            if m in item and isinstance(item[m], dict):
                oid = item[m].get("operationId")
                if oid:
                    out[(p, m)] = oid
    return out


def _split_method_handlers(blob: str) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    i = 0
    while i < len(blob):
        mm = re.match(r"(get|post|put|patch|delete)\(", blob[i:])
        if not mm:
            break
        i += mm.end()
        depth = 1
        start = i
        while i < len(blob) and depth:
            c = blob[i]
            if c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
            i += 1
        inner = blob[start : i - 1].strip()
        out.append((mm.group(1), inner))
        if i < len(blob) and blob[i] == ".":
            i += 1
    return out


def _route_method_blob(rs: str, start_paren: int) -> str:
    """Given index of `(` after `.route`, return comma-separated methods blob."""
    depth = 0
    i = start_paren
    while i < len(rs):
        c = rs[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                inner = rs[start_paren + 1 : i]
                comma = inner.find(",")
                if comma < 0:
                    raise ValueError("bad .route(")
                return inner[comma + 1 :].strip().rstrip(",").strip()
        i += 1
    raise ValueError("unclosed .route(")


def parse_routes(rs: str) -> list[tuple[str, str, str]]:
    """Return list of (http_method, api_path, bare_handler_name)."""
    found: list[tuple[str, str, str]] = []
    for m in re.finditer(r"\.route\(\s*", rs):
        start = m.end() - 1  # position of '('
        q = rs.find('"', m.end())
        if q < 0:
            continue
        q2 = rs.find('"', q + 1)
        api_path = rs[q + 1 : q2]
        try:
            methods_blob = _route_method_blob(rs, start)
        except ValueError:
            continue
        for meth, inner in _split_method_handlers(methods_blob):
            h = inner.strip()
            if "::" in h:
                raise SystemExit(
                    f"handler must be bare name in same file, got {h} for {api_path}"
                )
            found.append((meth, api_path, h))
    return found


BLOCK_GET = '''#[utoipa::path(
    {meth},
    path = "{path}",
    operation_id = "{oid}",
    tag = "{tag}",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
'''

BLOCK_WRITE = '''#[utoipa::path(
    {meth},
    path = "{path}",
    operation_id = "{oid}",
    tag = "{tag}",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
'''


def inject_file(path: Path, ops: dict[tuple[str, str], str], tag: str, api_struct: str) -> None:
    text = path.read_text(encoding="utf-8")
    if "utoipa::path" in text and api_struct in text:
        print(f"skip {path}: already injected")
        return

    routes = parse_routes(text)
    if not routes:
        raise SystemExit(f"no routes in {path}")

    handlers_ordered: list[str] = []
    to_apply: list[tuple[int, str, str]] = []
    for meth, api_path, h in routes:
        oid = ops.get((api_path, meth))
        if not oid:
            raise SystemExit(f"no operationId for {meth.upper()} {api_path} in openapi.yaml")
        block_tpl = BLOCK_GET if meth == "get" else BLOCK_WRITE
        block = block_tpl.format(meth=meth, path=api_path, oid=oid, tag=tag)
        pat = rf"(async fn {re.escape(h)}\b|pub\(crate\) async fn {re.escape(h)}\b|pub\(super\) async fn {re.escape(h)}\b|pub async fn {re.escape(h)}\b)"
        m = re.search(pat, text)
        if not m:
            raise SystemExit(f"{path}: cannot find async fn {h}")
        # skip if already has utoipa immediately before this fn
        before = text[max(0, m.start() - 600) : m.start()]
        if "utoipa::path" in before:
            print(f"skip {h} (already annotated)")
        else:
            to_apply.append((m.start(), block, h))
        if h not in handlers_ordered:
            handlers_ordered.append(h)

    for pos, block, _h in sorted(to_apply, key=lambda x: x[0], reverse=True):
        text = text[:pos] + block + text[pos:]

    tail = f"""

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        {", ".join(handlers_ordered)},
    ),
    components(schemas(crate::error::ErrorBody)),
    tags((name = "{tag}", description = "{tag}"))
)]
pub struct {api_struct};
"""
    if api_struct not in text:
        text = text.rstrip() + tail + "\n"

    path.write_text(text, encoding="utf-8")
    print(f"updated {path.relative_to(ROOT)} ({len(handlers_ordered)} handlers)")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rs-file", required=True)
    ap.add_argument("--api-struct", required=True)
    ap.add_argument("--tag", required=True)
    args = ap.parse_args()

    ops = load_openapi_ops()
    inject_file(ROOT / args.rs_file, ops, args.tag, args.api_struct)


if __name__ == "__main__":
    main()
