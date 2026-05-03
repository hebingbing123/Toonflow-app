#!/usr/bin/env python3
"""
Intelligently split backend/src/production/workbench/video/generate.rs
into 8 modules based on function analysis.
"""

import re
from pathlib import Path
from collections import defaultdict

def read_file(path):
    """Read the source file."""
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def extract_top_level_items(content):
    """Extract top-level items (imports, constants, structs, enums, functions)."""
    items = []
    lines = content.split('\n')
    
    current_item = []
    in_item = False
    brace_depth = 0
    paren_depth = 0
    item_type = None
    item_name = None
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Track if we're starting a new item
        if not in_item:
            # Check for use statements
            if line.strip().startswith('use '):
                current_item = [line]
                in_item = True
                item_type = 'import'
                item_name = 'imports'
                if line.strip().endswith(';'):
                    items.append({
                        'type': item_type,
                        'name': item_name,
                        'content': '\n'.join(current_item),
                        'start_line': i + 1
                    })
                    current_item = []
                    in_item = False
            
            # Check for constants
            elif line.strip().startswith('const '):
                match = re.search(r'const\s+(\w+)', line)
                if match:
                    items.append({
                        'type': 'const',
                        'name': match.group(1),
                        'content': line,
                        'start_line': i + 1
                    })
            
            # Check for struct/enum
            elif re.search(r'^\s*(#\[.*\]\s*)*(pub(\(.*\))?\s+)?(struct|enum)\s+(\w+)', line):
                match = re.search(r'(struct|enum)\s+(\w+)', line)
                if match:
                    item_type = match.group(1)
                    item_name = match.group(2)
                    current_item = [line]
                    in_item = True
                    brace_depth = line.count('{') - line.count('}')
                    if brace_depth == 0 and ';' in line:
                        items.append({
                            'type': item_type,
                            'name': item_name,
                            'content': '\n'.join(current_item),
                            'start_line': i + 1
                        })
                        current_item = []
                        in_item = False
            
            # Check for function
            elif re.search(r'^\s*(#\[.*\]\s*)*(pub(\(.*\))?\s+)?(async\s+)?fn\s+(\w+)', line):
                match = re.search(r'fn\s+(\w+)', line)
                if match:
                    item_type = 'function'
                    item_name = match.group(1)
                    current_item = [line]
                    in_item = True
                    brace_depth = line.count('{') - line.count('}')
                    paren_depth = line.count('(') - line.count(')')
            
            # Check for impl block
            elif re.search(r'^\s*impl\s+', line):
                match = re.search(r'impl\s+(\w+)', line)
                if match:
                    item_type = 'impl'
                    item_name = match.group(1)
                    current_item = [line]
                    in_item = True
                    brace_depth = line.count('{') - line.count('}')
        
        else:
            # We're inside an item, accumulate lines
            current_item.append(line)
            
            if item_type == 'import':
                if line.strip().endswith(';') or line.strip().endswith('};'):
                    items.append({
                        'type': item_type,
                        'name': item_name,
                        'content': '\n'.join(current_item),
                        'start_line': i + 1 - len(current_item) + 1
                    })
                    current_item = []
                    in_item = False
            else:
                brace_depth += line.count('{') - line.count('}')
                paren_depth += line.count('(') - line.count(')')
                
                if brace_depth == 0 and paren_depth == 0:
                    items.append({
                        'type': item_type,
                        'name': item_name,
                        'content': '\n'.join(current_item),
                        'start_line': i + 1 - len(current_item) + 1
                    })
                    current_item = []
                    in_item = False
        
        i += 1
    
    return items

def categorize_item(item):
    """Categorize an item into a module."""
    name = item['name']
    item_type = item['type']
    content = item['content']
    
    # Imports and constants go to mod.rs
    if item_type in ['import', 'const']:
        return 'mod'
    
    # Structs and enums
    if item_type in ['struct', 'enum']:
        # Public response types go to mod.rs
        if 'pub(in crate::production)' in content or 'pub(crate)' in content:
            return 'mod'
        # Internal types for prompt building
        if any(kw in name for kw in ['Negative', 'Character', 'Visual', 'Prioritized']):
            return 'prompt_builder'
        return 'utils'
    
    # Functions
    if item_type == 'function':
        # Test functions
        if '#[test]' in content or '#[cfg(test)]' in content:
            return 'tests'
        
        # Main handler
        if name == 'post_workbench_generate_video':
            return 'core'
        
        # Core validation and normalization
        if name in ['normalize_upload_sources', 'resolve_storyboard_prompt', 
                    'ensure_track_in_scope', 'ensure_storyboards_in_scope']:
            return 'core'
        
        # Memory loading functions
        if name.startswith('load_') or name.endswith('_fetch_limit'):
            return 'memory_integration'
        
        # Selection and filtering (memory integration)
        if name.startswith('select_') or name.startswith('filter_'):
            return 'memory_integration'
        
        # Negative prompt BUILDING (high-level orchestration)
        if name.startswith('build_storyboard_negative'):
            return 'prompt_builder'
        
        # Negative prompt MERGING and COMPACTION
        if any(kw in name for kw in ['merge_negative', 'merge_prioritized', 
                                       'compact_negative_fragment_families',
                                       'compact_negative_constraint',
                                       'compact_conflicting',
                                       'prioritize_negative']):
            return 'prompt_builder'
        
        # Fragment PARSING and RENDERING
        if any(kw in name for kw in ['parse_character', 'parse_visual', 
                                       'render_character', 'render_visual',
                                       'render_mood']):
            return 'prompt_builder'
        
        # Fragment UTILITIES (splitting, stitching, canonical forms)
        if any(kw in name for kw in ['split_negative', 'stitch_split',
                                       'canonical_negative', 'negative_fragment_family',
                                       'negative_fragment_information_score',
                                       'negative_fragment_covers', 'negative_fragment_contains',
                                       'negative_fragment_same_family',
                                       'push_negative_fragment',
                                       'match_known_negative']):
            return 'utils'
        
        # Fragment SCORING
        if any(kw in name for kw in ['score_negative', 'score_review', 'score_contextual']):
            return 'quality_control'
        
        # PRUNING and RESTORATION
        if any(kw in name for kw in ['prune_negative', 'prune_storyboard',
                                       'restore_specific']):
            return 'prompt_builder'
        
        # COMPACTION against storyboard/review/memory
        if any(kw in name for kw in ['compact_review_fragments', 
                                       'compact_rejected_fragments',
                                       'compact_review_fragment_against',
                                       'compact_rejected_overlap',
                                       'compact_rushed_motion']):
            return 'prompt_builder'
        
        # Quality and review COLLECTION
        if any(kw in name for kw in ['collect_negative_review', 'promote_review',
                                       'map_bad_case', 'infer_negative_fragments']):
            return 'quality_control'
        
        # Quality FILTERING
        if any(kw in name for kw in ['filter_conflicting', 'review_fragment_conflicts',
                                       'review_fragment_is_irrelevant']):
            return 'quality_control'
        
        # Recent quality and pressure
        if any(kw in name for kw in ['recent_quality', 'resolve_negative_filter']):
            return 'quality_control'
        
        # Storyboard and asset functions
        if name.startswith('storyboard_') and not any(kw in name for kw in ['negative', 'prompt']):
            return 'asset_integration'
        
        if name in ['load_project_aspect_ratio', 'compact_video_ratio', 'infer_video_provider']:
            return 'asset_integration'
        
        # Diagnostics and scene analysis (all the _risk, _needs_, _has_, etc.)
        if any(kw in name for kw in ['_risk', '_needs_', '_has_', '_matches_', 
                                       '_conflicts', '_is_redundant', '_is_irrelevant',
                                       '_is_low_signal', '_is_empty',
                                       'negative_prompt_scene', 'style_note_context',
                                       'negative_fragment_targets',
                                       'negative_fragment_requires',
                                       'negative_fragment_axis',
                                       'negative_fragment_overlaps',
                                       'negative_style_fragment',
                                       'trim_negative_style',
                                       'compact_contextual',
                                       'select_contextual']):
            return 'diagnostics'
        
        # Budget and clipping
        if any(kw in name for kw in ['negative_prompt_budget', 'negative_prompt_char_budget',
                                       'negative_prompt_fragment_budget',
                                       'clip_negative', 'resolve_negative_prompt_budget']):
            return 'utils'
        
        # Storyboard target ID helpers
        if 'target_id' in name:
            return 'utils'
        
        # Everything else
        return 'utils'
    
    # Impl blocks
    if item_type == 'impl':
        return 'mod'
    
    return 'utils'

def create_module_files(items, target_dir):
    """Create the module files."""
    target_dir = Path(target_dir)
    target_dir.mkdir(parents=True, exist_ok=True)
    
    # Group items by module
    modules = defaultdict(list)
    for item in items:
        module = categorize_item(item)
        modules[module].append(item)
    
    # Common imports for all modules
    common_imports = """use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Serialize;
use sqlx::PgPool;
use std::collections::{BTreeSet, HashMap};
use uuid::Uuid;

use super::WorkbenchGenerateVideoBody;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::production::types::GenerateVideoUploadItem;
use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;
use crate::production::workbench::meta::generate::constraints::{
    derive_recent_quality_constraint_pressure, RecentQualitySignalRow,
    VideoPromptConstraintPressure,
};
use crate::production::workbench::video_prompt_memory::{
    clip_prompt_fragment, compact_video_style_prompt_note, extract_key_value,
    normalize_prompt_text, optimize_scoped_video_memory, parse_structured_storyboard_description,
    select_prioritized_video_style_note, select_project_video_style_memory_notes_for_storyboard,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias,
    select_script_video_style_memory_notes_for_storyboard,
    select_selected_video_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes_for_storyboard, selected_memory_subject_aliases,
    split_prompt_note_fragments, storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,
    StructuredStoryboardDescription, VideoPromptMemorySelectionBias,
};
use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};
use crate::scope::http::require_owned_numeric_script_scope;
use crate::state::AppState;
"""
    
    # Create mod.rs
    mod_content = []
    mod_content.append("//! Video generation module\n")
    mod_content.append(common_imports)
    mod_content.append("\n// Constants")
    for item in modules['mod']:
        if item['type'] == 'const':
            mod_content.append(item['content'])
    
    mod_content.append("\n// Module declarations")
    mod_content.append("mod core;")
    mod_content.append("mod prompt_builder;")
    mod_content.append("mod fragment_ops;")
    mod_content.append("mod fragment_merge;")
    mod_content.append("mod fragment_budget;")
    mod_content.append("mod memory_integration;")
    mod_content.append("mod asset_integration;")
    mod_content.append("mod quality_control;")
    mod_content.append("mod diagnostics;")
    mod_content.append("mod utils;")
    
    mod_content.append("\n// Public types")
    for item in modules['mod']:
        if item['type'] in ['struct', 'enum', 'impl']:
            mod_content.append("\n" + item['content'])
    
    mod_content.append("\n// Re-exports")
    mod_content.append("pub(in crate::production) use core::post_workbench_generate_video;")
    mod_content.append("pub(crate) use prompt_builder::{")
    mod_content.append("    load_auto_negative_prompt,")
    mod_content.append("    load_auto_negative_prompts,")
    mod_content.append("    load_auto_negative_prompt_details,")
    mod_content.append("    load_storyboard_negative_prompt_runtime,")
    mod_content.append("    map_bad_case_category_with_comments,")
    mod_content.append("    infer_negative_fragments_from_comments,")
    mod_content.append("};")
    
    (target_dir / "mod.rs").write_text('\n'.join(mod_content))
    
    # Create other module files
    module_list = ['core', 'prompt_builder', 'memory_integration', 'asset_integration',
                   'quality_control', 'diagnostics', 'utils']
    
    # Check if prompt_builder is too large and needs splitting
    if len(modules['prompt_builder']) > 100:  # Rough heuristic
        # Split prompt_builder into sub-categories
        prompt_builder_items = modules['prompt_builder']
        modules['fragment_ops'] = []
        modules['fragment_merge'] = []
        
        for item in prompt_builder_items:
            name = item['name']
            # Fragment operations (parsing, rendering, canonical forms)
            if any(kw in name for kw in ['parse_', 'render_', 'canonical_', 
                                           'split_negative', 'stitch_']):
                modules['fragment_ops'].append(item)
            # Merging and compaction
            elif any(kw in name for kw in ['merge_', 'compact_negative_fragment_families',
                                             'compact_conflicting', 'prioritize_negative',
                                             'compact_rushed_motion']):
                modules['fragment_merge'].append(item)
            else:
                # Keep in prompt_builder
                pass
        
        # Remove moved items from prompt_builder
        moved_names = {item['name'] for item in modules['fragment_ops'] + modules['fragment_merge']}
        modules['prompt_builder'] = [item for item in prompt_builder_items 
                                      if item['name'] not in moved_names]
        
        module_list = ['core', 'prompt_builder', 'fragment_ops', 'fragment_merge',
                       'memory_integration', 'asset_integration',
                       'quality_control', 'diagnostics', 'utils']
    
    for module_name in module_list:
        content = []
        content.append(f"//! {module_name.replace('_', ' ').title()} module\n")
        content.append("use super::*;\n")
        
        for item in modules[module_name]:
            content.append("\n" + item['content'])
        
        filename = f"{module_name}.rs"
        file_content = '\n'.join(content)
        (target_dir / filename).write_text(file_content)
        
        line_count = len(file_content.split('\n'))
        print(f"Created {filename}: {line_count} lines")
        if line_count > 800:
            print(f"  ⚠️  WARNING: {filename} exceeds 800 lines!")

def main():
    source_file = "backend/src/production/workbench/video/generate.rs"
    target_dir = "backend/src/production/workbench/video/generate"
    
    print(f"Reading {source_file}...")
    content = read_file(source_file)
    
    print("Extracting top-level items...")
    items = extract_top_level_items(content)
    print(f"Found {len(items)} items")
    
    print(f"\nCreating module files in {target_dir}...")
    create_module_files(items, target_dir)
    
    print("\nDone!")
    print("\nNext steps:")
    print("1. Review the generated files")
    print("2. Run: cargo fmt")
    print("3. Run: cargo clippy")
    print("4. Run: cargo test")

if __name__ == "__main__":
    main()
