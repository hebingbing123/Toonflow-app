#!/usr/bin/env python3
"""
Manually split the large generated files into smaller ones.
"""

from pathlib import Path

def split_prompt_builder():
    """Split prompt_builder.rs into multiple files."""
    source = Path("backend/src/production/workbench/video/generate/prompt_builder.rs")
    content = source.read_text()
    lines = content.split('\n')
    
    # Find function boundaries
    functions = []
    current_func = []
    in_func = False
    brace_depth = 0
    func_name = None
    
    for i, line in enumerate(lines):
        if not in_func and ('fn ' in line):
            # Starting a new function
            import re
            match = re.search(r'fn\s+(\w+)', line)
            if match:
                func_name = match.group(1)
                current_func = [line]
                in_func = True
                brace_depth = line.count('{') - line.count('}')
        elif in_func:
            current_func.append(line)
            brace_depth += line.count('{') - line.count('}')
            if brace_depth == 0 and '{' in '\n'.join(current_func):
                functions.append({
                    'name': func_name,
                    'content': '\n'.join(current_func)
                })
                current_func = []
                in_func = False
                func_name = None
    
    # Categorize functions
    categories = {
        'prompt_builder': [],  # High-level orchestration
        'fragment_ops': [],    # Fragment parsing, rendering, canonical forms
        'fragment_merge': [],  # Merging and compaction
        'fragment_budget': [], # Budget and prioritization
    }
    
    for func in functions:
        name = func['name']
        
        # High-level orchestration
        if name.startswith('build_storyboard_negative') or name.startswith('load_'):
            categories['prompt_builder'].append(func)
        # Fragment operations
        elif any(kw in name for kw in ['parse_', 'render_', 'canonical_', 
                                         'split_negative', 'stitch_', 'match_known']):
            categories['fragment_ops'].append(func)
        # Merging and compaction
        elif any(kw in name for kw in ['merge_', 'compact_negative_fragment',
                                         'compact_conflicting', 'compact_rushed',
                                         'compact_review_fragment', 'compact_rejected']):
            categories['fragment_merge'].append(func)
        # Budget and prioritization
        elif any(kw in name for kw in ['prioritize_', 'push_negative_fragment',
                                         'prune_negative_prompt_fragments',
                                         'restore_specific']):
            categories['fragment_budget'].append(func)
        else:
            # Default to prompt_builder
            categories['prompt_builder'].append(func)
    
    # Write files
    header = "//! Prompt Builder module\n\nuse super::*;\n\n"
    
    for category, funcs in categories.items():
        if not funcs:
            continue
        
        content = [header]
        for func in funcs:
            content.append(func['content'])
            content.append('\n')
        
        filepath = Path(f"backend/src/production/workbench/video/generate/{category}.rs")
        filepath.write_text('\n'.join(content))
        line_count = len('\n'.join(content).split('\n'))
        print(f"Created {category}.rs: {line_count} lines")

def split_utils():
    """Split utils.rs by moving some functions to other modules."""
    source = Path("backend/src/production/workbench/video/generate/utils.rs")
    content = source.read_text()
    lines = content.split('\n')
    
    # Extract functions
    functions = []
    current_func = []
    in_func = False
    brace_depth = 0
    func_name = None
    
    for i, line in enumerate(lines):
        if not in_func and ('fn ' in line):
            import re
            match = re.search(r'fn\s+(\w+)', line)
            if match:
                func_name = match.group(1)
                current_func = [line]
                in_func = True
                brace_depth = line.count('{') - line.count('}')
        elif in_func:
            current_func.append(line)
            brace_depth += line.count('{') - line.count('}')
            if brace_depth == 0 and '{' in '\n'.join(current_func):
                functions.append({
                    'name': func_name,
                    'content': '\n'.join(current_func)
                })
                current_func = []
                in_func = False
                func_name = None
    
    # Keep only true utility functions
    utils_funcs = []
    fragment_ops_funcs = []
    
    for func in functions:
        name = func['name']
        
        # Fragment operations
        if any(kw in name for kw in ['negative_fragment_', 'canonical_negative',
                                       'negative_prompt_char_budget',
                                       'negative_prompt_fragment_budget',
                                       'clip_negative_prompt']):
            fragment_ops_funcs.append(func)
        else:
            utils_funcs.append(func)
    
    # Write utils.rs
    header = "//! Utils module\n\nuse super::*;\n\n"
    content = [header]
    for func in utils_funcs:
        content.append(func['content'])
        content.append('\n')
    
    filepath = Path("backend/src/production/workbench/video/generate/utils.rs")
    filepath.write_text('\n'.join(content))
    line_count = len('\n'.join(content).split('\n'))
    print(f"Updated utils.rs: {line_count} lines")
    
    # Append to fragment_ops.rs
    if fragment_ops_funcs:
        fragment_ops_path = Path("backend/src/production/workbench/video/generate/fragment_ops.rs")
        if fragment_ops_path.exists():
            existing = fragment_ops_path.read_text()
        else:
            existing = header
        
        for func in fragment_ops_funcs:
            existing += '\n' + func['content'] + '\n'
        
        fragment_ops_path.write_text(existing)
        line_count = len(existing.split('\n'))
        print(f"Updated fragment_ops.rs: {line_count} lines")

def main():
    print("Splitting large files...")
    
    print("\n1. Splitting prompt_builder.rs...")
    split_prompt_builder()
    
    print("\n2. Splitting utils.rs...")
    split_utils()
    
    print("\nDone!")

if __name__ == "__main__":
    main()
