#!/usr/bin/env python3
"""Generate utoipa path stubs from an OpenAPI YAML `paths:` document (batch OpenApi structs + merge helper).

The **committed** `backend/src/openapi_spec/generated/*.rs` is what the server merges at runtime; this script
is for **one-off regeneration** when you have a monolithic or paths-only YAML (e.g. from `docs/openapi.yaml`).

Each stub mirrors the operation's request/response shapes in utoipa using:
- `body = ref("ComponentName")` / `content = ref("...")` for `#/components/schemas/*` (from `embedded/legacy_component_schemas.json` merged at runtime)
- `serde_json::Value` for inline JSON schemas without a component ref

Run from repo root (default input: `docs/openapi.yaml` if it exists):

  python3 scripts/gen_openapi_utoipa_stubs.py
  python3 scripts/gen_openapi_utoipa_stubs.py path/to/openapi-with-paths.yaml

Output is formatted to satisfy `cargo fmt --check` in `backend/`.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OPENAPI = ROOT / "docs" / "openapi.yaml"
STUB_INPUT_FIXTURE = ROOT / "scripts" / "fixtures" / "openapi_stub_input.yaml"
OUT_DIR = ROOT / "backend" / "src" / "openapi_spec" / "generated"


def _default_openapi_yaml() -> Path:
    if DEFAULT_OPENAPI.is_file():
        return DEFAULT_OPENAPI
    if STUB_INPUT_FIXTURE.is_file():
        return STUB_INPUT_FIXTURE
    raise FileNotFoundError("no default OpenAPI YAML for stub regeneration")

# Covered by hand-written / module OpenApi aggregates (avoid duplicate stubs in merge).
SKIP_OPERATION_IDS = frozenset(
    {
        "healthRoot",
        "healthV1",
        "pingV1",
        "versionV1",
        "readyV1",
        "meV1",
        "postBillingWebhookV1",
        "listBillingWebhookEventsV1",
        "listHarnessToolsV1",
        "websocketUpgrade",
        "usageSummaryV1",
        "cancelJobV1",
        "createJobV1",
        "getJobTaskDetailCompatV1",
        "getJobV1",
        "listJobKindSummariesV1",
        "listJobKindsV1",
        "listJobStatusSummariesV1",
        "listJobsPageV1",
        "listJobsV1",
        "retryJobV1",
        "postProductionAssetsBatchGenerateImageV1",
        "postProductionAssetsDeleteDerivativeV1",
        "postProductionAssetsGetAssetsDataV1",
        "postProductionAssetsPollingImageV1",
        "postProductionAssetsUpdateUrlV1",
        "postProductionEditImageGenerateFlowImageV1",
        "postProductionEditImageGetDefaultModelV1",
        "postProductionEditImageGetFlowV1",
        "postProductionEditImageSaveFlowV1",
        "postProductionEditImageUpdateFlowV1",
        "postProductionEditImageUploadImageV1",
        "postProductionExportImageV1",
        "postProductionGetFlowDataV1",
        "postProductionGetProductionDataV1",
        "postProductionGetStoryboardDataV1",
        "postProductionSaveFlowDataV1",
        "postProductionStoryboardAddV1",
        "postProductionStoryboardBatchAddInfoV1",
        "postProductionStoryboardBatchGenerateImageV1",
        "postProductionStoryboardDownPreviewImageV1",
        "postProductionStoryboardEditInfoV1",
        "postProductionStoryboardGetDataV1",
        "postProductionStoryboardPollingImageV1",
        "postProductionStoryboardPreviewImageV1",
        "postProductionStoryboardRemoveFrameV1",
        "postProductionStoryboardUpdateUrlV1",
        "postProductionWorkbenchAddTrackV1",
        "postProductionWorkbenchDeleteTrackV1",
        "postProductionWorkbenchDeleteVideoV1",
        "postProductionWorkbenchGenerateVideoPromptV1",
        "postProductionWorkbenchGenerateVideoV1",
        "postProductionWorkbenchGetGenerateDataV1",
        "postProductionWorkbenchGetVideoListV1",
        "postProductionWorkbenchGetVideoModelDetailV1",
        "postProductionWorkbenchSelectVideoV1",
        "getSwitchAiDevToolV1",
        "putSwitchAiDevToolV1",
        "getMemoryConfigV1",
        "postMemoryConfigV1",
        "postSettingsClearAgentMemoriesV1",
        "postAboutCheckUpdateV1",
        "postAboutDownloadAppV1",
        "getSettingsVendorsSummaryV1",
        "postSettingsVendorModelTestV1",
        "postSettingsVendorsAddV1",
        "postSettingsVendorsUpdateV1",
        "postSettingsVendorsDeleteV1",
        "postSettingsVendorsEnableV1",
        "postSettingsVendorsUpdateCodeV1",
        "postSettingsVendorsCodeFromLinkV1",
        "postSettingsDangerDeleteAllDataV1",
        "postSettingsDangerClearDatabaseV1",
        "postSettingsAgentDeployListV1",
        "postSettingsAgentDeployModelV1",
        "postSettingsAgentDeploySetKeyV1",
        "storeVendorCredentialV1",
        "getVendorCredentialV1",
        "deleteVendorCredentialV1",
        "queryAgentMemoryV1",
        "clearAgentMemoryV1",
        "appendAgentMemoryV1",
        "listModelsV1",
        "getTextModelDefaultV1",
        "patchTextModelDefaultV1",
        "modelDetailV1",
        "listPromptsV1",
        "getPromptByNumericIdV1",
        "patchPromptByNumericIdV1",
        "listQualityReviewsV1",
        "createQualityReviewV1",
        "getQualityReviewV1",
        "getQualityStatsV1",
        "getQualityStagePassRateV1",
    }
)

METHODS = (
    "get",
    "post",
    "put",
    "patch",
    "delete",
    "options",
    "head",
    "trace",
)

RUST_KEYWORDS = frozenset(
    {
        "as",
        "break",
        "const",
        "continue",
        "crate",
        "else",
        "enum",
        "extern",
        "false",
        "fn",
        "for",
        "if",
        "impl",
        "in",
        "let",
        "loop",
        "match",
        "mod",
        "move",
        "mut",
        "pub",
        "ref",
        "return",
        "self",
        "Self",
        "static",
        "struct",
        "super",
        "trait",
        "true",
        "type",
        "unsafe",
        "use",
        "where",
        "while",
        "async",
        "await",
        "dyn",
    }
)

REF_PREFIX = "#/components/schemas/"


def to_snake(operation_id: str) -> str:
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", operation_id)
    s = s.replace("-", "_").lower()
    s = re.sub(r"[^a-z0-9_]", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "op"


def rust_ident(operation_id: str) -> str:
    base = to_snake(operation_id)
    if base in RUST_KEYWORDS or (base and not base[0].isalpha() and base[0] != "_"):
        base = f"_{base}"
    return f"op_{base}"


def rust_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def trim_desc(desc: str | None, max_len: int = 180) -> str | None:
    if not desc or not isinstance(desc, str):
        return None
    one = " ".join(desc.split())
    if len(one) > max_len:
        one = one[: max_len - 3] + "..."
    return one


def schema_to_rust_content(schema: Any) -> str:
    """Expression for utoipa request_body content= or response body=."""
    if isinstance(schema, dict) and isinstance(schema.get("$ref"), str):
        ref = schema["$ref"]
        if ref.startswith(REF_PREFIX):
            name = ref.removeprefix(REF_PREFIX)
            return f'ref("{name}")'
    return "serde_json::Value"


def pick_json_media(content: Any) -> tuple[str | None, Any | None]:
    if not isinstance(content, dict):
        return None, None
    for ct in ("application/json", "application/problem+json"):
        if ct in content and isinstance(content[ct], dict):
            sch = content[ct].get("schema")
            return ct, sch
    for k, v in content.items():
        if isinstance(v, dict) and "schema" in v:
            return str(k), v.get("schema")
    return None, None


def format_request_body(op: dict[str, Any]) -> list[str] | None:
    rb = op.get("requestBody")
    if not isinstance(rb, dict):
        return None
    content = rb.get("content")
    _ct, schema = pick_json_media(content)
    if schema is None and isinstance(content, dict):
        # e.g. only non-json — still document as Value
        if not content:
            return None
    desc = trim_desc(rb.get("description"))
    if schema is None:
        inner = "serde_json::Value"
    else:
        inner = schema_to_rust_content(schema)
    lines = ["request_body("]
    lines.append(f"        content = {inner},")
    lines.append('        content_type = "application/json",')
    if desc:
        lines.append(f"        description = {rust_str(desc)},")
    lines.append("    ),")
    return lines


def status_sort_key(k: str) -> tuple[int, Any]:
    if k == "default":
        return (2, 0)
    try:
        return (0, int(k))
    except ValueError:
        return (1, k)


def format_responses(op: dict[str, Any]) -> list[str]:
    resps = op.get("responses")
    if not isinstance(resps, dict) or not resps:
        return ["responses((status = 200, description = \"OK\"))"]

    parts: list[str] = []
    for code in sorted(resps.keys(), key=status_sort_key):
        entry = resps[code]
        if not isinstance(entry, dict):
            continue
        desc = trim_desc(entry.get("description")) or "Response"
        status_lit = f'"{code}"' if not code.isdigit() else code
        content = entry.get("content")
        _ct, schema = pick_json_media(content)
        if schema is not None or (
            isinstance(content, dict) and content and _ct is not None
        ):
            body = schema_to_rust_content(schema) if schema is not None else "serde_json::Value"
            parts.append(
                f"(status = {status_lit}, description = {rust_str(desc)}, "
                f"body = {body}, content_type = \"application/json\")"
            )
        elif isinstance(content, dict) and content:
            # has content types but no schema — still mark JSON bucket
            parts.append(
                f"(status = {status_lit}, description = {rust_str(desc)}, "
                "body = serde_json::Value, content_type = \"application/json\")"
            )
        else:
            parts.append(f"(status = {status_lit}, description = {rust_str(desc)})")

    if not parts:
        return ["responses((status = 200, description = \"OK\"))"]
    inner = ",\n        ".join(parts)
    return [f"responses(\n        {inner}\n    )"]


def emit_path_macro(path: str, method: str, op: dict[str, Any]) -> list[str]:
    oid = op["operationId"]
    tags = op.get("tags") or []
    tag0 = tags[0] if tags and isinstance(tags[0], str) else "api"
    summary = op.get("summary")
    sum_line = None
    if isinstance(summary, str):
        t = trim_desc(summary, 200)
        if t:
            sum_line = f"    summary = {rust_str(t)},"

    p = rust_str(path)
    oid_s = rust_str(oid)
    tag_s = rust_str(tag0)

    rb_lines = format_request_body(op)
    resp_lines = format_responses(op)

    attr_lines = [
        "#[utoipa::path(",
        f"    {method},",
        f"    path = {p},",
        f"    operation_id = {oid_s},",
        f"    tag = {tag_s},",
    ]
    if sum_line:
        attr_lines.append(sum_line)
    if rb_lines:
        attr_lines.extend(rb_lines)
    attr_lines.extend(resp_lines)
    attr_lines.append(")]")
    return attr_lines


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Regenerate openapi_spec/generated batch stubs from an OpenAPI YAML `paths:` section.",
    )
    ap.add_argument(
        "openapi_yaml",
        nargs="?",
        default=None,
        help="YAML with top-level `paths:` (monolith or paths-only). "
        f"Default: {DEFAULT_OPENAPI} if present, else {STUB_INPUT_FIXTURE} (fixture updated by extract script).",
    )
    args = ap.parse_args()
    if args.openapi_yaml:
        src = Path(args.openapi_yaml)
    else:
        try:
            src = _default_openapi_yaml()
        except FileNotFoundError:
            raise SystemExit(
                "Missing OpenAPI YAML for stub regeneration. Pass a path, add docs/openapi.yaml, "
                f"or run extract to refresh {STUB_INPUT_FIXTURE}.\n"
                "Runtime OpenAPI merges committed stubs only (no backend paths YAML)."
            ) from None
    if not src.is_file():
        raise SystemExit(f"OpenAPI YAML not found: {src}")
    with src.open(encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    paths = doc.get("paths") or {}

    ops: list[tuple[str, str, dict[str, Any]]] = []
    for path, item in paths.items():
        if not isinstance(item, dict):
            continue
        for method in METHODS:
            op = item.get(method)
            if not isinstance(op, dict):
                continue
            oid = op.get("operationId")
            if not oid or not isinstance(oid, str):
                raise SystemExit(f"missing operationId for {method.upper()} {path}")
            if oid in SKIP_OPERATION_IDS:
                continue
            ops.append((path, method, op))

    ops.sort(key=lambda t: (t[0], t[1], t[2].get("operationId", "")))

    BATCH = 28
    batches: list[list[tuple[str, str, dict[str, Any]]]] = []
    for i in range(0, len(ops), BATCH):
        batches.append(ops[i : i + BATCH])

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for bi, batch in enumerate(batches):
        lines: list[str] = []
        lines.append("//! AUTO-GENERATED by `scripts/gen_openapi_utoipa_stubs.py`. Do not edit.")
        lines.append("")
        lines.append("mod stubs {")
        for idx, (path, method, op) in enumerate(batch):
            ident = rust_ident(op["operationId"])
            macro_lines = emit_path_macro(path, method, op)
            for line in macro_lines:
                lines.append(f"    {line}")
            lines.append("    #[allow(dead_code)]")
            lines.append(f"    pub(crate) fn {ident}() {{}}")
            if idx + 1 < len(batch):
                lines.append("")
        lines.append("}")
        path_list = ",\n    ".join(
            f"stubs::{rust_ident(op['operationId'])}" for _, _, op in batch
        )
        lines.append("#[derive(utoipa::OpenApi)]")
        lines.append("#[openapi(paths(")
        lines.append(f"    {path_list}")
        lines.append("))]")
        lines.append(f"pub struct ApiDocBatch{bi:02};")

        (OUT_DIR / f"batch{bi:02}.rs").write_text("\n".join(lines) + "\n", encoding="utf-8")

    mod_lines = [
        "//! AUTO-GENERATED by `scripts/gen_openapi_utoipa_stubs.py`. Do not edit.",
        "",
        "use utoipa::OpenApi;",
    ]
    for bi in range(len(batches)):
        mod_lines.append(f"mod batch{bi:02};")
    mod_lines.append("")
    mod_lines.append(
        "/// All generated path stubs (from `scripts/gen_openapi_utoipa_stubs.py`) merged into one [`utoipa::openapi::OpenApi`]."
    )
    mod_lines.append("pub fn merged_generated_openapi() -> utoipa::openapi::OpenApi {")
    if not batches:
        mod_lines.append("    utoipa::openapi::OpenApi::default()")
    else:
        mod_lines.append("    let mut doc = batch00::ApiDocBatch00::openapi();")
        for bi in range(1, len(batches)):
            mod_lines.append(f"    doc.merge(batch{bi:02}::ApiDocBatch{bi:02}::openapi());")
        mod_lines.append("    doc")
    mod_lines.append("}")

    (OUT_DIR / "mod.rs").write_text("\n".join(mod_lines) + "\n", encoding="utf-8")

    print(f"Wrote {len(batches)} batch file(s) with {len(ops)} stubs under {OUT_DIR}")


if __name__ == "__main__":
    main()
