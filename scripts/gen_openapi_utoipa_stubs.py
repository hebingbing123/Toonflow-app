#!/usr/bin/env python3
"""Generate utoipa path stubs from `openapi_paths_index.yaml` (batch OpenApi structs + merge helper).

Run from repo root:
  python3 scripts/gen_openapi_utoipa_stubs.py
"""

from __future__ import annotations

import re
import textwrap
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
OPENAPI = ROOT / "backend" / "src" / "openapi_spec" / "openapi_paths_index.yaml"
OUT_DIR = ROOT / "backend" / "src" / "openapi_spec" / "generated"

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
        # settings + agent memory (handler-level utoipa)
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
        # vendor catalog + prompting HTTP
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


def to_snake(operation_id: str) -> str:
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", operation_id)
    s = s.replace("-", "_").lower()
    s = re.sub(r"[^a-z0-9_]", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "op"


def rust_ident(operation_id: str) -> str:
    base = to_snake(operation_id)
    if base in RUST_KEYWORDS or not base[0].isalpha() and base[0] != "_":
        base = f"_{base}"
    return f"op_{base}"


def rust_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> None:
    with OPENAPI.open(encoding="utf-8") as f:
        doc = yaml.safe_load(f)
    paths = doc.get("paths") or {}

    ops: list[tuple[str, str, str, str | None, str | None]] = []
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
            tags = op.get("tags") or []
            tag0 = tags[0] if tags else "api"
            if not isinstance(tag0, str):
                tag0 = "api"
            summary = op.get("summary")
            sum_s = summary if isinstance(summary, str) else None
            ops.append((path, method, oid, tag0, sum_s))

    ops.sort(key=lambda t: (t[0], t[1], t[2]))

    BATCH = 28
    batches: list[list[tuple[str, str, str, str | None, str | None]]] = []
    for i in range(0, len(ops), BATCH):
        batches.append(ops[i : i + BATCH])

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for bi, batch in enumerate(batches):
        lines: list[str] = []
        lines.append("//! AUTO-GENERATED by `scripts/gen_openapi_utoipa_stubs.py`. Do not edit.")
        lines.append("")
        lines.append("mod stubs {")
        for path, method, oid, tag0, sum_s in batch:
            ident = rust_ident(oid)
            p = rust_str(path)
            oid_s = rust_str(oid)
            tag_s = rust_str(tag0)
            # Thin responses only — merge layer keeps rich YAML unless a handler supplies schemas.
            attr_lines = [
                "#[utoipa::path(",
                f"    {method},",
                f"    path = {p},",
                f"    operation_id = {oid_s},",
                f"    tag = {tag_s},",
            ]
            if sum_s:
                one_line = sum_s.replace("\n", " ").strip()
                if len(one_line) > 200:
                    one_line = one_line[:197] + "..."
                attr_lines.append(f"    summary = {rust_str(one_line)},")
            attr_lines.extend(
                [
                    "    responses((status = 200, description = \"OK\"))",
                    ")]",
                    "#[allow(dead_code)]",
                    f"    pub(crate) fn {ident}() {{}}",
                    "",
                ]
            )
            lines.extend(attr_lines)
        lines.append("}")
        lines.append("")
        path_list = ",\n        ".join(
            f"stubs::{rust_ident(oid)}" for _, _, oid, _, _ in batch
        )
        lines.append("#[derive(utoipa::OpenApi)]")
        lines.append("#[openapi(")
        lines.append("    paths(")
        lines.append(f"        {path_list}")
        lines.append("    ),")
        lines.append(")]")
        lines.append(f"pub struct ApiDocBatch{bi:02};")
        lines.append("")

        (OUT_DIR / f"batch{bi:02}.rs").write_text("\n".join(lines) + "\n", encoding="utf-8")

    mod_lines = [
        "//! AUTO-GENERATED by `scripts/gen_openapi_utoipa_stubs.py`. Do not edit.",
        "",
        "use utoipa::OpenApi;",
    ]
    for bi in range(len(batches)):
        mod_lines.append(f"mod batch{bi:02};")
    mod_lines.append("")
    mod_lines.append("/// All YAML-derived path stubs merged into one [`utoipa::openapi::OpenApi`].")
    mod_lines.append("pub fn merged_generated_openapi() -> utoipa::openapi::OpenApi {")
    if not batches:
        mod_lines.append("    utoipa::openapi::OpenApi::default()")
    else:
        mod_lines.append(f"    let mut doc = batch00::ApiDocBatch00::openapi();")
        for bi in range(1, len(batches)):
            mod_lines.append(f"    doc.merge(batch{bi:02}::ApiDocBatch{bi:02}::openapi());")
        mod_lines.append("    doc")
    mod_lines.append("}")
    mod_lines.append("")

    (OUT_DIR / "mod.rs").write_text("\n".join(mod_lines) + "\n", encoding="utf-8")

    print(f"Wrote {len(batches)} batch file(s) with {len(ops)} stubs under {OUT_DIR}")


if __name__ == "__main__":
    main()
