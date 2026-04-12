#!/usr/bin/env python3
"""Split the monolithic OpenAPI file into Rust-side sources (no hand-edited docs/openapi.yaml).

Reads a **full** OpenAPI 3.1 YAML (default: `docs/openapi.yaml` if present), or pass a path:

  python3 scripts/extract_openapi_rust_sources.py path/to/full-openapi.yaml

Writes:
  backend/src/openapi_spec/embedded/legacy_component_schemas.json
    — `components.schemas` only (transitional; metadata/tags/security live in `shell.rs`).
    Long-term these schemas should move to Rust `ToSchema` + utoipa merges until this file is empty.
    After updating, run `python3 scripts/gen_legacy_utoipa_registry.py` to refresh `legacy_components/`.
  backend/src/openapi_spec/ws_protocol_description.md
    — `GET /api/v1/ws` long description (for `include_str!` on the upgrade handler)
  scripts/fixtures/openapi_stub_input.yaml
    — { paths: <all paths except /api/v1/ws> } one-off input for `scripts/gen_openapi_utoipa_stubs.py` (not merged at runtime).

Run from repo root:
  python3 scripts/extract_openapi_rust_sources.py
"""

from __future__ import annotations

import json
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

# `components.schemas` names already registered via Rust `ToSchema` + domain `OpenApi` (see `openapi_spec::combined_openapi`).
RUST_OWNED_SCHEMA_KEYS = frozenset(
    {
        "ArtStyleRow",
        "ListArtStylesResponse",
        "CreateArtStyleBody",
        "ExtractArtStylePromptBody",
        "ExtractArtStylePromptResponse",
        "PatchArtStyleBody",
    }
)

# Schemas present in a monolithic `docs/openapi.yaml` but never referenced by any `$ref` in the merged
# Rust OpenAPI export (dead weight). Omit from `legacy_component_schemas.json` so they are not re-embedded
# when re-running this extractor. See `openapi_spec::embedded/legacy_component_schemas.json` (pruned 2026-04).
PRUNED_UNREFERENCED_LEGACY_SCHEMA_KEYS = frozenset(
    {
        "AboutCheckUpdateRequest",
        "AboutCheckUpdateResponse",
        "AboutDownloadAppRequest",
        "AgentDeployKeyIgnoredResponse",
        "AgentDeployListBody",
        "AgentDeployListItem",
        "AgentDeploySavedResponse",
        "AgentSetKeyBody",
        "AppendAgentMemoryBody",
        "AppendAgentMemoryResponse",
        "AssetsGenerateCancelBody",
        "BatchAddScriptDataBody",
        "BatchAddScriptResponse",
        "BatchDeleteNovelEventsBody",
        "BatchGenerateImageAssetsBody",
        "BatchPolishAssetsPromptBody",
        "ClearAgentMemoryBody",
        "ClearAgentMemoryResponse",
        "CornerScapeRequestBody",
        "CornerScapeResponse",
        "CreateAssetBody",
        "CreateAssetImageBody",
        "CreateJobBody",
        "CreateNovelBody",
        "CreateNovelEventBody",
        "CreateProjectBody",
        "CreateQualityReviewBody",
        "CreateScriptBody",
        "CreateStoryboardBody",
        "DeployAgentModelBody",
        "DownloadAppAcceptedResponse",
        "ExportScriptsBody",
        "ExtractAssetsAcceptedResponse",
        "ExtractAssetsStartBody",
        "GenerateAssetsBody",
        "GenerateNovelEventsBody",
        "GetScriptAgentPlanBody",
        "JobKindSummary",
        "JobStatusSummary",
        "JobsPageResponse",
        "LegacyAssetsAddAssetsBody",
        "LegacyAssetsBatchDeleteBody",
        "LegacyAssetsBatchGenerationDataBody",
        "LegacyAssetsBatchGenerationDataResponse",
        "LegacyAssetsDeleteBody",
        "LegacyAssetsGetAssetsApiBody",
        "LegacyAssetsGetAssetsApiResponse",
        "LegacyAssetsGetImageBody",
        "LegacyAssetsGetImageResponse",
        "LegacyAssetsGetMaterialDataBody",
        "LegacyAssetsGetMaterialDataResponse",
        "LegacyAssetsMutationResponse",
        "LegacyAssetsPollingImageAssetsBody",
        "LegacyAssetsPollingImageAssetsItem",
        "LegacyAssetsPollingPromptAssetsBody",
        "LegacyAssetsPollingPromptAssetsItem",
        "LegacyAssetsSaveAssetsBody",
        "LegacyAssetsUpdateAssetsBody",
        "LegacyAssetsUploadClipBody",
        "LegacyAssetsUploadClipResponse",
        "LegacyDirectorManualAddBody",
        "LegacyDirectorManualDeleteBody",
        "LegacyDirectorManualDeleteResponse",
        "LegacyDirectorManualEditBody",
        "LegacyDirectorManualListResponse",
        "LegacyEmptyObjectResponse",
        "LegacyGenerateNovelEventsBody",
        "LegacyGetEventsBody",
        "LegacyNovelAddNovelBody",
        "LegacyNovelBatchDeleteBody",
        "LegacyNovelDataResponse",
        "LegacyNovelDeleteNovelBody",
        "LegacyNovelEventListResponse",
        "LegacyNovelEventStateResponse",
        "LegacyNovelGetNovelBody",
        "LegacyNovelGetNovelEventStateBody",
        "LegacyNovelGetNovelResponse",
        "LegacyNovelIndexResponse",
        "LegacyNovelOkMessageResponse",
        "LegacyNovelProjectIdBody",
        "LegacyNovelUpdateNovelBody",
        "LegacyProjectAddProjectBody",
        "LegacyProjectDeleteProjectBody",
        "LegacyProjectDeleteProjectResponse",
        "LegacyProjectEditProjectBody",
        "LegacyProjectMutationMessageResponse",
        "LegacyScriptsGetScriptApiResponse",
        "LegacyTasksEmptyBody",
        "LegacyVisualManualAddBody",
        "LegacyVisualManualEditBody",
        "ListAssetImagesResponse",
        "ListAssetsResponse",
        "ListNovelsResponse",
        "MemoryConfigSavedResponse",
        "MemoryHistoryItem",
        "ModelDetailResponse",
        "ModelListEntry",
        "NovelEventCreateResponse",
        "NovelEventListResponse",
        "NovelEventOkResponse",
        "PatchAssetBody",
        "PatchAssetImageBody",
        "PatchNovelBody",
        "PatchProjectBody",
        "PatchPromptBody",
        "PatchScriptBody",
        "PatchStoryboardBody",
        "PatchTextModelDefaultBody",
        "PolishAssetsPromptBody",
        "ProductionAssetsBatchGenerateImageBody",
        "ProductionAssetsBatchGenerateImageResponse",
        "ProductionAssetsDeleteDerivativeBody",
        "ProductionAssetsDeleteDerivativeResponse",
        "ProductionAssetsGetDataBody",
        "ProductionAssetsGetDataResponse",
        "ProductionAssetsPollingImageBody",
        "ProductionAssetsPollingImageResponse",
        "ProductionAssetsUpdateUrlBody",
        "ProductionAssetsUpdateUrlResponse",
        "ProductionEditImageDefaultModelResponse",
        "ProductionEditImageGenerateFlowImageBody",
        "ProductionEditImageGenerateFlowImageResponse",
        "ProductionEditImageGetFlowResponse",
        "ProductionEditImageSaveFlowBody",
        "ProductionEditImageSaveFlowResponse",
        "ProductionEditImageUpdateFlowBody",
        "ProductionEditImageUpdateFlowResponse",
        "ProductionEditImageUploadImageBody",
        "ProductionEditImageUploadImageResponse",
        "ProductionExportImageBody",
        "ProductionFlowDataResponse",
        "ProductionGetFlowDataBody",
        "ProductionGetProductionDataResponse",
        "ProductionLegacyJsonStubBody",
        "ProductionSaveFlowDataBody",
        "ProductionStoryboardAddBody",
        "ProductionStoryboardAddResponse",
        "ProductionStoryboardBatchAddInfoBody",
        "ProductionStoryboardBatchAddInfoResponse",
        "ProductionStoryboardBatchGenerateImageBody",
        "ProductionStoryboardBatchGenerateImageResponse",
        "ProductionStoryboardDownPreviewImageResponse",
        "ProductionStoryboardEditInfoBody",
        "ProductionStoryboardEditInfoResponse",
        "ProductionStoryboardIdBody",
        "ProductionStoryboardIdsBody",
        "ProductionStoryboardListBody",
        "ProductionStoryboardPreviewImageResponse",
        "ProductionStoryboardRemoveFrameResponse",
        "ProductionStoryboardUpdateUrlBody",
        "ProductionStoryboardUpdateUrlResponse",
        "ProductionWorkbenchAddTrackBody",
        "ProductionWorkbenchAddTrackResponse",
        "ProductionWorkbenchDeleteTrackBody",
        "ProductionWorkbenchDeleteTrackResponse",
        "ProductionWorkbenchDeleteVideoBody",
        "ProductionWorkbenchDeleteVideoResponse",
        "ProductionWorkbenchGenerateVideoBody",
        "ProductionWorkbenchGenerateVideoPromptBody",
        "ProductionWorkbenchGenerateVideoPromptResponse",
        "ProductionWorkbenchGetGenerateDataBody",
        "ProductionWorkbenchGetGenerateDataResponse",
        "ProductionWorkbenchGetVideoListBody",
        "ProductionWorkbenchGetVideoListResponse",
        "ProductionWorkbenchSelectVideoBody",
        "ProductionWorkbenchSelectVideoResponse",
        "ProductionWorkbenchVideoModelDetailResponse",
        "ProjectDetailResponse",
        "ProjectStatsResponse",
        "ProjectsSummaryResponse",
        "QualityReview",
        "QualityStatsResponse",
        "QueryAgentMemoryBody",
        "RateLimitError",
        "ScriptExtractStatePollBody",
        "ScriptExtractStatePollRow",
        "ScriptsGetScriptApiNameBody",
        "SetScriptAgentPlanBody",
        "SettingsClearAgentMemoriesBody",
        "SkillContentResponse",
        "SkillContentWriteRequest",
        "SkillFileMeta",
        "SkillsSummaryResponse",
        "StagePassRateItem",
        "StoreVendorCredentialBody",
        "StoryboardRow",
        "SwitchAiDevToolPutRequest",
        "SwitchAiDevToolResponse",
        "TextModelDefaultResponse",
        "UpdateNovelEventBody",
        "UpdateScriptAgentDataBody",
        "VendorAddBody",
        "VendorCatalogSummary",
        "VendorCodeFromLinkBody",
        "VendorConfig",
        "VendorCredentialResponse",
        "VendorEnableBody",
        "VendorEnableResponse",
        "VendorIdBody",
        "VendorLinkResponse",
        "VendorModelTestBody",
        "VendorUpdateBody",
        "VendorUpdateCodeBody",
        "VendorUpdateResponse",
        "VendorsSummaryResponse",
        "VisualManualResponse",
    }
)


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

    components = doc.get("components") or {}
    schemas = components.get("schemas")
    if not isinstance(schemas, dict):
        raise SystemExit("full OpenAPI must include components.schemas (object)")

    for k in RUST_OWNED_SCHEMA_KEYS | PRUNED_UNREFERENCED_LEGACY_SCHEMA_KEYS:
        schemas.pop(k, None)

    OUT_LEGACY_SCHEMAS.parent.mkdir(parents=True, exist_ok=True)
    OUT_LEGACY_SCHEMAS.write_text(
        json.dumps(schemas, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    paths_index = dict(paths)
    paths_index.pop("/api/v1/ws", None)
    OUT_STUB_INPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT_STUB_INPUT.open("w", encoding="utf-8") as f:
        yaml.dump({"paths": paths_index}, f, sort_keys=False, allow_unicode=True, width=120)

    print(f"Wrote {OUT_LEGACY_SCHEMAS}")
    print(f"Wrote {OUT_STUB_INPUT}")


if __name__ == "__main__":
    main()
