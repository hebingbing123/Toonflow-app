#!/usr/bin/env python3
"""
Split backend/src/production/workbench/video/generate.rs into 8 modules.

Target structure:
- mod.rs (~400 lines) - module entry, re-exports
- core.rs (~800 lines) - main handler, normalization, validation
- prompt_builder.rs (~800 lines) - negative prompt building logic
- memory_integration.rs (~800 lines) - memory loading and integration
- asset_integration.rs (~700 lines) - asset and storyboard integration
- quality_control.rs (~700 lines) - quality review and scoring
- diagnostics.rs (~600 lines) - diagnostics and utilities
- utils.rs (~400 lines) - utility functions
"""

import re
from pathlib import Path
from typing import List, Tuple, Dict, Set

SOURCE_FILE = Path("backend/src/production/workbench/video/generate.rs")
TARGET_DIR = Path("backend/src/production/workbench/video/generate")

def read_source() -> str:
    """Read the source file."""
    return SOURCE_FILE.read_text()

def extract_imports(content: str) -> str:
    """Extract all use statements from the beginning of the file."""
    lines = content.split('\n')
    imports = []
    in_imports = False
    
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('use '):
            in_imports = True
            imports.append(line)
        elif in_imports and stripped.startswith('};'):
            imports.append(line)
        elif in_imports and not stripped:
            continue
        elif in_imports:
            break
    
    return '\n'.join(imports)

def extract_constants(content: str) -> str:
    """Extract constant definitions."""
    lines = content.split('\n')
    constants = []
    
    for line in lines:
        if line.strip().startswith('const '):
            constants.append(line)
    
    return '\n'.join(constants)

def split_into_sections(content: str) -> Dict[str, List[str]]:
    """Split content into logical sections based on function names and patterns."""
    lines = content.split('\n')
    
    sections = {
        'structs': [],
        'core': [],
        'prompt_builder': [],
        'memory_integration': [],
        'asset_integration': [],
        'quality_control': [],
        'diagnostics': [],
        'utils': [],
        'tests': []
    }
    
    current_section = []
    current_category = None
    in_function = False
    brace_count = 0
    
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Skip imports and constants (handled separately)
        if stripped.startswith('use ') or stripped.startswith('const '):
            i += 1
            continue
        
        # Detect struct/enum definitions
        if re.match(r'(pub(\(.*\))?\s+)?(struct|enum)\s+\w+', stripped):
            if current_section and current_category:
                sections[current_category].extend(current_section)
            current_section = [line]
            current_category = 'structs'
            in_function = True
            brace_count = line.count('{') - line.count('}')
            i += 1
            continue
        
        # Detect function definitions
        func_match = re.match(r'(pub(\(.*\))?\s+)?(async\s+)?fn\s+(\w+)', stripped)
        if func_match:
            if current_section and current_category:
                sections[current_category].extend(current_section)
            
            func_name = func_match.group(4)
            current_section = [line]
            current_category = categorize_function(func_name, stripped)
            in_function = True
            brace_count = line.count('{') - line.count('}')
            i += 1
            continue
        
        # Track braces to know when function ends
        if in_function:
            current_section.append(line)
            brace_count += line.count('{') - line.count('}')
            if brace_count == 0 and '{' in ''.join(current_section):
                in_function = False
                if current_category:
                    sections[current_category].extend(current_section)
                    sections[current_category].append('')  # Add blank line
                current_section = []
                current_category = None
        
        i += 1
    
    # Add any remaining section
    if current_section and current_category:
        sections[current_category].extend(current_section)
    
    return sections

def categorize_function(func_name: str, line: str) -> str:
    """Categorize a function based on its name and signature."""
    
    # Test functions
    if '#[test]' in line or func_name.endswith('_test'):
        return 'tests'
    
    # Core handler and main entry points
    if func_name in ['post_workbench_generate_video', 'normalize_upload_sources', 
                     'resolve_storyboard_prompt', 'ensure_track_in_scope', 
                     'ensure_storyboards_in_scope']:
        return 'core'
    
    # Prompt building functions
    if any(keyword in func_name for keyword in [
        'negative_prompt', 'negative_fragment', 'build_storyboard_negative',
        'merge_negative', 'compact_negative', 'prune_negative', 'split_negative',
        'prioritize_negative', 'score_negative', 'render_', 'parse_character',
        'parse_visual', 'canonical_negative', 'clip_negative', 'restore_specific'
    ]):
        return 'prompt_builder'
    
    # Memory integration functions
    if any(keyword in func_name for keyword in [
        'load_', 'select_', 'filter_selected', 'fetch_limit'
    ]):
        return 'memory_integration'
    
    # Asset and storyboard integration
    if any(keyword in func_name for keyword in [
        'storyboard_', 'load_project_aspect', 'compact_video_ratio',
        'infer_video_provider'
    ]):
        return 'asset_integration'
    
    # Quality control and review
    if any(keyword in func_name for keyword in [
        'quality_review', 'review_fragment', 'collect_negative_review',
        'map_bad_case', 'infer_negative_fragments', 'score_review',
        'recent_quality', 'resolve_negative_filter'
    ]):
        return 'quality_control'
    
    # Diagnostics and scene analysis
    if any(keyword in func_name for keyword in [
        '_risk', '_needs_', '_has_', '_matches_', '_conflicts',
        '_is_redundant', '_is_irrelevant', '_is_low_signal',
        'negative_prompt_scene', 'style_note_context'
    ]):
        return 'diagnostics'
    
    # Utilities
    return 'utils'

def create_mod_rs(sections: Dict[str, List[str]], imports: str) -> str:
    """Create the mod.rs file with module declarations and re-exports."""
    content = []
    
    # Add file header comment
    content.append("//! Video generation module")
    content.append("//!")
    content.append("//! This module handles video generation requests, including:")
    content.append("//! - Request validation and normalization")
    content.append("//! - Automatic negative prompt generation")
    content.append("//! - Memory integration and quality control")
    content.append("//! - Job enqueueing")
    content.append("")
    
    # Add imports
    content.append(imports)
    content.append("")
    
    # Add constants
    content.append("// Constants")
    content.append("const VIDEO_NEGATIVE_PROMPT_MAX_CHARS: usize = 120;")
    content.append("const VIDEO_NEGATIVE_PROMPT_LEAN_MAX_CHARS: usize = 84;")
    content.append("const VIDEO_NEGATIVE_PROMPT_LEAN_FRAGMENT_LIMIT: usize = 2;")
    content.append("const VIDEO_NEGATIVE_REVIEW_BASE_LIMIT: i64 = 8;")
    content.append("const VIDEO_NEGATIVE_REVIEW_PER_STORYBOARD_ROWS: i64 = 4;")
    content.append("const VIDEO_NEGATIVE_REVIEW_MAX_LIMIT: i64 = 24;")
    content.append("const VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT: i64 = 8;")
    content.append("const VIDEO_NEGATIVE_REJECTED_MEMORY_PER_STORYBOARD_ROWS: i64 = 2;")
    content.append("const VIDEO_NEGATIVE_REJECTED_MEMORY_MAX_LIMIT: i64 = 12;")
    content.append("const VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT: i64 = 8;")
    content.append("const VIDEO_NEGATIVE_SELECTED_MEMORY_PER_STORYBOARD_ROWS: i64 = 2;")
    content.append("const VIDEO_NEGATIVE_SELECTED_MEMORY_SUMMARY_ROWS: i64 = 2;")
    content.append("const VIDEO_NEGATIVE_SELECTED_MEMORY_MAX_LIMIT: i64 = 14;")
    content.append("")
    
    # Add module declarations
    content.append("// Submodules")
    content.append("mod core;")
    content.append("mod prompt_builder;")
    content.append("mod memory_integration;")
    content.append("mod asset_integration;")
    content.append("mod quality_control;")
    content.append("mod diagnostics;")
    content.append("mod utils;")
    content.append("")
    
    # Add structs
    content.append("// Public types")
    content.extend(sections['structs'])
    content.append("")
    
    # Add re-exports
    content.append("// Re-exports")
    content.append("pub(in crate::production) use core::post_workbench_generate_video;")
    content.append("pub(crate) use prompt_builder::{")
    content.append("    load_auto_negative_prompt,")
    content.append("    load_auto_negative_prompts,")
    content.append("    load_auto_negative_prompt_details,")
    content.append("    load_storyboard_negative_prompt_runtime,")
    content.append("    map_bad_case_category_with_comments,")
    content.append("    infer_negative_fragments_from_comments,")
    content.append("};")
    content.append("")
    
    return '\n'.join(content)

def create_submodule(name: str, sections: Dict[str, List[str]], 
                     categories: List[str], imports: str) -> str:
    """Create a submodule file."""
    content = []
    
    # Add file header
    content.append(f"//! {name.replace('_', ' ').title()} module")
    content.append("")
    
    # Add imports
    content.append(imports)
    content.append("")
    content.append("use super::*;")
    content.append("")
    
    # Add content from specified categories
    for category in categories:
        if sections[category]:
            content.extend(sections[category])
            content.append("")
    
    return '\n'.join(content)

def main():
    """Main execution."""
    print("Reading source file...")
    content = read_source()
    
    print("Extracting imports and constants...")
    imports = extract_imports(content)
    
    print("Splitting into sections...")
    sections = split_into_sections(content)
    
    print(f"Section sizes:")
    for name, lines in sections.items():
        print(f"  {name}: {len(lines)} lines")
    
    print("\nCreating target directory...")
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    
    print("Creating mod.rs...")
    mod_content = create_mod_rs(sections, imports)
    (TARGET_DIR / "mod.rs").write_text(mod_content)
    print(f"  Created mod.rs ({len(mod_content.split(chr(10)))} lines)")
    
    # Create submodules
    submodules = [
        ("core.rs", ['core']),
        ("prompt_builder.rs", ['prompt_builder']),
        ("memory_integration.rs", ['memory_integration']),
        ("asset_integration.rs", ['asset_integration']),
        ("quality_control.rs", ['quality_control']),
        ("diagnostics.rs", ['diagnostics']),
        ("utils.rs", ['utils']),
    ]
    
    for filename, categories in submodules:
        print(f"Creating {filename}...")
        submodule_content = create_submodule(filename.replace('.rs', ''), sections, categories, imports)
        (TARGET_DIR / filename).write_text(submodule_content)
        line_count = len(submodule_content.split('\n'))
        print(f"  Created {filename} ({line_count} lines)")
        if line_count > 800:
            print(f"  WARNING: {filename} exceeds 800 lines!")
    
    print("\nDone! Remember to:")
    print("1. Remove the original generate.rs file")
    print("2. Update parent mod.rs to reference generate/mod.rs")
    print("3. Run cargo fmt and cargo clippy")
    print("4. Run cargo test")

if __name__ == "__main__":
    main()
