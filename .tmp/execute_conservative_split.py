#!/usr/bin/env python3
"""
Execute conservative split of video/generate.rs based on the detailed plan
"""

from pathlib import Path

def read_lines(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_lines(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def extract_lines(all_lines, start, end):
    """Extract lines from start (1-indexed) to end (1-indexed, inclusive)"""
    return all_lines[start-1:end]

def main():
    source = Path('backend/src/production/workbench/video/generate.rs')
    target_dir = Path('backend/src/production/workbench/video/generate')
    
    print(f"Reading {source}...")
    all_lines = read_lines(source)
    print(f"Total lines: {len(all_lines)}")
    
    # Common imports for submodules
    submodule_header = [
        "use axum::{extract::{Json, State}, http::HeaderMap, Json as JsonResponse};\n",
        "use serde::Serialize;\n",
        "use sqlx::PgPool;\n",
        "use std::collections::{BTreeSet, HashMap};\n",
        "use uuid::Uuid;\n",
        "\n",
        "use super::*;\n",
        "use crate::error::ApiError;\n",
        "use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_GENERATE};\n",
        "use crate::production::types::GenerateVideoUploadItem;\n",
        "use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;\n",
        "use crate::production::workbench::meta::generate::constraints::{\n",
        "    derive_recent_quality_constraint_pressure, RecentQualitySignalRow,\n",
        "    VideoPromptConstraintPressure,\n",
        "};\n",
        "use crate::production::workbench::video_prompt_memory::{\n",
        "    clip_prompt_fragment, compact_video_style_prompt_note, extract_key_value,\n",
        "    normalize_prompt_text, optimize_scoped_video_memory, parse_structured_storyboard_description,\n",
        "    select_prioritized_video_style_note, select_project_video_style_memory_notes_for_storyboard,\n",
        "    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias,\n",
        "    select_script_video_style_memory_notes_for_storyboard,\n",
        "    select_selected_video_memory_notes_for_storyboard,\n",
        "    select_subject_role_video_style_memory_notes_for_storyboard, selected_memory_subject_aliases,\n",
        "    split_prompt_note_fragments, storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,\n",
        "    StructuredStoryboardDescription, VideoPromptMemorySelectionBias,\n",
        "};\n",
        "use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};\n",
        "use crate::scope::http::require_owned_numeric_script_scope;\n",
        "use crate::state::AppState;\n",
        "\n",
    ]
    
    # 1. Create mod.rs
    print("Creating mod.rs...")
    mod_lines = []
    mod_lines.extend(extract_lines(all_lines, 1, 343))  # Imports, types, handler
    mod_lines.append("\n// Module declarations\n")
    mod_lines.append("mod memory_integration;\n")
    mod_lines.append("mod negative_prompt_core;\n")
    mod_lines.append("mod scene_diagnostics;\n")
    mod_lines.append("mod quality_control;\n")
    mod_lines.append("mod fragment_operations;\n")
    mod_lines.append("mod utils;\n")
    mod_lines.append("\n// Re-exports\n")
    mod_lines.append("pub(crate) use negative_prompt_core::{\n")
    mod_lines.append("    load_auto_negative_prompt,\n")
    mod_lines.append("    load_auto_negative_prompts,\n")
    mod_lines.append("    load_auto_negative_prompt_details,\n")
    mod_lines.append("    load_storyboard_negative_prompt_runtime,\n")
    mod_lines.append("};\n")
    mod_lines.append("pub(crate) use quality_control::{\n")
    mod_lines.append("    map_bad_case_category_with_comments,\n")
    mod_lines.append("    infer_negative_fragments_from_comments,\n")
    mod_lines.append("};\n")
    write_lines(target_dir / 'mod.rs', mod_lines)
    print(f"  mod.rs: {len(mod_lines)} lines")
    
    # 2. Create memory_integration.rs
    print("Creating memory_integration.rs...")
    memory_lines = []
    memory_lines.extend(submodule_header)
    memory_lines.extend(extract_lines(all_lines, 344, 1046))
    write_lines(target_dir / 'memory_integration.rs', memory_lines)
    print(f"  memory_integration.rs: {len(memory_lines)} lines")
    
    # 3. Create negative_prompt_core.rs (LARGE - keep together)
    print("Creating negative_prompt_core.rs...")
    core_lines = []
    core_lines.extend(submodule_header)
    # Part 1: 1047-2561
    core_lines.extend(extract_lines(all_lines, 1047, 2561))
    write_lines(target_dir / 'negative_prompt_core.rs', core_lines)
    print(f"  negative_prompt_core.rs: {len(core_lines)} lines")
    
    # 4. Create scene_diagnostics.rs
    print("Creating scene_diagnostics.rs...")
    scene_lines = []
    scene_lines.extend(submodule_header)
    scene_lines.extend(extract_lines(all_lines, 1571, 1881))
    write_lines(target_dir / 'scene_diagnostics.rs', scene_lines)
    print(f"  scene_diagnostics.rs: {len(scene_lines)} lines")
    
    # 5. Create quality_control.rs
    print("Creating quality_control.rs...")
    quality_lines = []
    quality_lines.extend(submodule_header)
    quality_lines.extend(extract_lines(all_lines, 2562, 3026))
    write_lines(target_dir / 'quality_control.rs', quality_lines)
    print(f"  quality_control.rs: {len(quality_lines)} lines")
    
    # 6. Create fragment_operations.rs
    print("Creating fragment_operations.rs...")
    fragment_lines = []
    fragment_lines.extend(submodule_header)
    fragment_lines.extend(extract_lines(all_lines, 3027, 3883))
    write_lines(target_dir / 'fragment_operations.rs', fragment_lines)
    print(f"  fragment_operations.rs: {len(fragment_lines)} lines")
    
    # 7. Create utils.rs (includes tests)
    print("Creating utils.rs...")
    utils_lines = []
    utils_lines.extend(submodule_header)
    utils_lines.extend(extract_lines(all_lines, 3884, len(all_lines)))
    write_lines(target_dir / 'utils.rs', utils_lines)
    print(f"  utils.rs: {len(utils_lines)} lines")
    
    print("\nSplit complete!")
    print("\nFile sizes:")
    for file in ['mod.rs', 'memory_integration.rs', 'negative_prompt_core.rs', 
                 'scene_diagnostics.rs', 'quality_control.rs', 'fragment_operations.rs', 'utils.rs']:
        path = target_dir / file
        if path.exists():
            lines = len(read_lines(path))
            print(f"  {file}: {lines} lines")

if __name__ == '__main__':
    main()
