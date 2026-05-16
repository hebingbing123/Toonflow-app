#!/usr/bin/env python3
"""
Fix function visibility in split modules
"""

from pathlib import Path
import re

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def make_function_public(content, func_name):
    """Make a function pub(super) if it's currently private"""
    # Match: fn func_name or async fn func_name
    pattern = rf'^(async\s+)?fn\s+{re.escape(func_name)}\s*\('
    lines = content.split('\n')
    result = []
    for line in lines:
        if re.match(pattern, line.strip()):
            # Add pub(super) if not already public
            if not line.strip().startswith('pub'):
                # Handle async functions - pub must come before async
                if 'async fn ' + func_name in line:
                    line = line.replace('async fn ' + func_name, 'pub(super) async fn ' + func_name)
                else:
                    line = line.replace('fn ' + func_name, 'pub(super) fn ' + func_name)
        result.append(line)
    return '\n'.join(result)

def main():
    base_dir = Path('backend/src/production/workbench/video/generate')
    
    # Functions that need to be public
    functions_to_export = {
        'utils.rs': ['infer_video_provider'],
        'fragment_operations.rs': [
            'merge_negative_prompts',
            'merge_negative_prompt_fragment_groups',
            'merge_prioritized_negative_prompt_fragment_groups',
            'canonical_negative_fragment',
            'split_negative_prompt_fragments',
            'clip_negative_prompt',
        ],
        'negative_prompt_core.rs': [
            'storyboard_dialogue_is_empty',
            'build_storyboard_negative_prompts',
            'build_storyboard_negative_prompts_with_recent_quality',
            'build_storyboard_negative_prompt_contexts',
            'build_storyboard_negative_prompt_selection',
            'build_storyboard_observation_negative_fragments',
            'resolve_negative_filter_style_note',
            'prune_storyboard_negative_fragments',
            'compact_negative_constraint_against_storyboard_style',
            'compact_review_fragments_against_rejected_memory',
            'compact_rejected_fragments_against_review_focus',
            'filter_conflicting_review_fragments',
            'recent_quality_memory_selection_bias',
        ],
        'scene_diagnostics.rs': [
            'negative_fragment_matches_storyboard_risk',
            'compact_negative_fragment_against_storyboard_risk',
        ],
        'quality_control.rs': [
            'collect_negative_review_fragments',
            'compact_negative_review_constraints',
            'quality_review_row_matches_storyboard',
            'quality_review_storyboard_target_id',
            'recent_quality_storyboard_target_id',
        ],
        'memory_integration.rs': [
            'normalize_upload_sources',
            'resolve_storyboard_prompt',
            'filter_selected_rows_for_subject',
            'negative_review_fetch_limit',
            'rejected_negative_memory_fetch_limit',
            'selected_memory_fetch_limit',
            'ensure_track_in_scope',
            'ensure_storyboards_in_scope',
            'load_project_aspect_ratio',
            'load_auto_negative_prompt',
            'load_auto_negative_prompts',
            'load_auto_negative_prompt_details',
            'load_storyboard_negative_prompt_runtime',
            'load_negative_review_rows',
            'load_recent_quality_signal_rows',
            'load_storyboard_prompt_support_rows',
            'load_rejected_video_negative_memory_rows',
            'load_storyboard_prompt_seed_rows',
            'load_selected_video_memory_rows',
            'compact_video_ratio',
        ],
    }
    
    for filename, funcs in functions_to_export.items():
        filepath = base_dir / filename
        if not filepath.exists():
            print(f"Skipping {filename} (not found)")
            continue
            
        content = read_file(filepath)
        for func in funcs:
            content = make_function_public(content, func)
        write_file(filepath, content)
        print(f"Updated {filename}")

if __name__ == '__main__':
    main()
