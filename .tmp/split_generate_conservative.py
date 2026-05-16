#!/usr/bin/env python3
"""
Conservative split of backend/src/production/workbench/video/generate.rs
Strategy: Keep tightly coupled negative prompt logic together in larger modules
Target: 7 files, most ≤800 lines, core module ≤1500 lines
"""

import re
from pathlib import Path

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def extract_imports(lines):
    """Extract all use statements from the beginning of the file"""
    imports = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('use ') or stripped.startswith('use{'):
            imports.append(line)
        elif stripped and not stripped.startswith('//') and not stripped.startswith('use'):
            break
    return imports

def find_function_ranges(lines):
    """Find line ranges for top-level functions and structs"""
    ranges = []
    current_item = None
    brace_count = 0
    in_item = False
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Skip empty lines and comments at top level
        if not in_item and (not stripped or stripped.startswith('//')):
            continue
            
        # Detect start of item (struct, enum, fn, impl)
        if not in_item:
            if any(stripped.startswith(kw) for kw in ['pub(', 'pub ', 'fn ', 'async fn', 'struct ', 'enum ', 'impl ', 'const ']):
                current_item = {'start': i, 'name': stripped[:80], 'type': 'unknown'}
                in_item = True
                brace_count = 0
                
                # Determine type
                if 'struct ' in stripped:
                    current_item['type'] = 'struct'
                elif 'enum ' in stripped:
                    current_item['type'] = 'enum'
                elif 'fn ' in stripped or 'async fn' in stripped:
                    current_item['type'] = 'fn'
                elif 'impl ' in stripped:
                    current_item['type'] = 'impl'
                elif 'const ' in stripped:
                    current_item['type'] = 'const'
        
        if in_item:
            # Count braces
            brace_count += line.count('{') - line.count('}')
            
            # Check if item is complete
            if brace_count == 0 and '{' in ''.join(lines[current_item['start']:i+1]):
                current_item['end'] = i + 1
                ranges.append(current_item)
                in_item = False
                current_item = None
            elif current_item['type'] == 'const' and ';' in line:
                current_item['end'] = i + 1
                ranges.append(current_item)
                in_item = False
                current_item = None
    
    return ranges

def main():
    source_file = Path('backend/src/production/workbench/video/generate.rs')
    target_dir = Path('backend/src/production/workbench/video/generate')
    
    print(f"Reading {source_file}...")
    lines = read_file(source_file)
    print(f"Total lines: {len(lines)}")
    
    # Extract imports
    imports = extract_imports(lines)
    print(f"Found {len(imports)} import lines")
    
    # Find all items
    items = find_function_ranges(lines)
    print(f"Found {len(items)} top-level items")
    
    # Categorize items by function name patterns
    categories = {
        'types': [],  # Structs, enums, constants
        'handler': [],  # Main post_workbench_generate_video
        'validation': [],  # normalize_, resolve_, ensure_, compact_video_ratio
        'memory_loading': [],  # load_*, *_fetch_limit, filter_selected_rows
        'negative_prompt_core': [],  # build_*, select_*, derive_*, resolve_negative_*
        'scene_diagnostics': [],  # negative_prompt_scene_*, *_risk, *_needs_*
        'fragment_operations': [],  # *_fragment*, split_*, stitch_*, parse_*, render_*, canonical_*
        'quality_control': [],  # *_review_*, *_quality_*, score_*, map_bad_case_*, infer_negative_fragments
        'utils': [],  # merge_*, clip_*, infer_video_provider, storyboard_*
        'tests': [],  # #[test] or #[cfg(test)]
    }
    
    for item in items:
        name_lower = item['name'].lower()
        item_type = item['type']
        
        # Categorize
        if item_type in ['struct', 'enum', 'const']:
            categories['types'].append(item)
        elif 'post_workbench_generate_video' in name_lower:
            categories['handler'].append(item)
        elif any(kw in name_lower for kw in ['normalize_', 'resolve_storyboard', 'ensure_', 'compact_video_ratio', 'load_project_aspect']):
            categories['validation'].append(item)
        elif any(kw in name_lower for kw in ['load_', 'fetch_limit', 'filter_selected_rows']):
            categories['memory_loading'].append(item)
        elif any(kw in name_lower for kw in ['negative_prompt_scene', '_risk', '_needs_', 'subject_aliases_need']):
            categories['scene_diagnostics'].append(item)
        elif any(kw in name_lower for kw in ['_fragment', 'split_negative', 'stitch_', 'parse_character', 'parse_visual', 'render_', 'canonical_negative', 'push_negative_fragment', 'match_known_negative']):
            categories['fragment_operations'].append(item)
        elif any(kw in name_lower for kw in ['_review_', '_quality_', 'score_review', 'score_negative_prompt_budget', 'map_bad_case', 'infer_negative_fragments', 'collect_negative_review']):
            categories['quality_control'].append(item)
        elif any(kw in name_lower for kw in ['build_storyboard_negative', 'select_', 'resolve_negative_filter', 'resolve_negative_prompt_budget', 'recent_quality_memory_selection', 'prune_storyboard_negative', 'compact_negative_', 'compact_review_', 'compact_rejected_', 'filter_conflicting', 'negative_filter_', 'trim_negative_', 'compact_conflicting', 'compact_rushed_motion', 'prioritize_negative_prompt', 'prune_negative_prompt_fragments']):
            categories['negative_prompt_core'].append(item)
        elif '#[test]' in item['name'] or '#[cfg(test)]' in item['name'] or '_test' in name_lower or 'fn test_' in name_lower:
            categories['tests'].append(item)
        elif any(kw in name_lower for kw in ['merge_negative', 'merge_prioritized', 'clip_negative', 'infer_video_provider', 'storyboard_', 'negative_prompt_char_budget', 'negative_prompt_fragment_budget']):
            categories['utils'].append(item)
        else:
            # Default: put in negative_prompt_core if it has "negative" in name
            if 'negative' in name_lower:
                categories['negative_prompt_core'].append(item)
            else:
                categories['utils'].append(item)
    
    # Print category sizes
    for cat, items_list in categories.items():
        total_lines = sum(item['end'] - item['start'] for item in items_list)
        print(f"{cat}: {len(items_list)} items, ~{total_lines} lines")
    
    # Conservative split strategy:
    # 1. mod.rs: imports, re-exports, handler (~200 lines)
    # 2. negative_prompt_core.rs: ALL negative prompt building logic (~1500 lines)
    # 3. fragment_operations.rs: fragment parsing, rendering, merging (~800 lines)
    # 4. scene_diagnostics.rs: scene analysis and risk assessment (~800 lines)
    # 5. memory_integration.rs: memory loading and integration (~700 lines)
    # 6. quality_control.rs: quality review logic (~800 lines)
    # 7. utils.rs: utility functions (~800 lines)
    
    # Build mod.rs
    mod_lines = []
    mod_lines.append("// Auto-generated module structure - conservative split\n")
    mod_lines.append("// Core negative prompt logic kept together to preserve tight coupling\n\n")
    mod_lines.extend(imports)
    mod_lines.append("\n")
    
    # Add module declarations
    mod_lines.append("mod negative_prompt_core;\n")
    mod_lines.append("mod fragment_operations;\n")
    mod_lines.append("mod scene_diagnostics;\n")
    mod_lines.append("mod memory_integration;\n")
    mod_lines.append("mod quality_control;\n")
    mod_lines.append("mod utils;\n\n")
    
    # Add re-exports
    mod_lines.append("// Re-export public types\n")
    mod_lines.append("pub(in crate::production) use negative_prompt_core::{\n")
    mod_lines.append("    AutoNegativePromptSelection, StoryboardNegativePromptRuntime,\n")
    mod_lines.append("    load_auto_negative_prompt, load_auto_negative_prompts,\n")
    mod_lines.append("    load_auto_negative_prompt_details, load_storyboard_negative_prompt_runtime,\n")
    mod_lines.append("};\n")
    mod_lines.append("pub(crate) use quality_control::{\n")
    mod_lines.append("    map_bad_case_category_with_comments, infer_negative_fragments_from_comments,\n")
    mod_lines.append("};\n\n")
    
    # Add types
    for item in categories['types']:
        mod_lines.extend(lines[item['start']:item['end']])
        mod_lines.append("\n")
    
    # Add handler
    for item in categories['handler']:
        mod_lines.extend(lines[item['start']:item['end']])
        mod_lines.append("\n")
    
    write_file(target_dir / 'mod.rs', mod_lines)
    print(f"Created mod.rs: {len(mod_lines)} lines")
    
    # Build other modules
    modules = {
        'negative_prompt_core.rs': categories['negative_prompt_core'],
        'fragment_operations.rs': categories['fragment_operations'],
        'scene_diagnostics.rs': categories['scene_diagnostics'],
        'memory_integration.rs': categories['memory_loading'] + categories['validation'][2:],  # Skip handler-related validation
        'quality_control.rs': categories['quality_control'],
        'utils.rs': categories['utils'] + categories['tests'],
    }
    
    for module_name, module_items in modules.items():
        module_lines = []
        module_lines.append(f"// {module_name} - Auto-generated\n\n")
        module_lines.extend(imports)
        module_lines.append("\n")
        module_lines.append("use super::*;\n\n")
        
        for item in module_items:
            module_lines.extend(lines[item['start']:item['end']])
            module_lines.append("\n")
        
        write_file(target_dir / module_name, module_lines)
        print(f"Created {module_name}: {len(module_lines)} lines")
    
    print("\nConservative split complete!")
    print("Next steps:")
    print("1. Review generated files")
    print("2. Fix any compilation errors")
    print("3. Run cargo fmt")
    print("4. Run cargo clippy")
    print("5. Run cargo test")

if __name__ == '__main__':
    main()
