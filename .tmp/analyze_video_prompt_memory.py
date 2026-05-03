#!/usr/bin/env python3
"""
Analyze video_prompt_memory/mod.rs and categorize functions by responsibility.
"""

import re
from pathlib import Path
from collections import defaultdict

def analyze_file(filepath):
    """Analyze the file and categorize functions."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # Extract function definitions with their visibility
    functions = []
    structs = []
    enums = []
    constants = []
    
    for i, line in enumerate(lines, 1):
        # Functions
        if re.match(r'^(pub(\(crate\))?\s+)?fn\s+(\w+)', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?fn\s+(\w+)', line)
            visibility = match.group(1) or 'private'
            name = match.group(3)
            functions.append((i, visibility.strip(), name))
        
        # Structs
        if re.match(r'^(pub(\(crate\))?\s+)?struct\s+(\w+)', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?struct\s+(\w+)', line)
            visibility = match.group(1) or 'private'
            name = match.group(3)
            structs.append((i, visibility.strip(), name))
        
        # Enums
        if re.match(r'^(pub(\(crate\))?\s+)?enum\s+(\w+)', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?enum\s+(\w+)', line)
            visibility = match.group(1) or 'private'
            name = match.group(3)
            enums.append((i, visibility.strip(), name))
        
        # Constants
        if re.match(r'^const\s+(\w+)', line):
            match = re.match(r'^const\s+(\w+)', line)
            name = match.group(1)
            constants.append((i, name))
    
    # Categorize functions by responsibility
    categories = defaultdict(list)
    
    for line_no, vis, name in functions:
        # Builder functions
        if 'build_' in name:
            categories['builder'].append((line_no, vis, name))
        # Selector functions
        elif 'select_' in name:
            categories['selector'].append((line_no, vis, name))
        # Persistence functions
        elif any(x in name for x in ['persist_', 'load_', 'delete_', 'clear_']):
            categories['persistence'].append((line_no, vis, name))
        # Scoring functions
        elif 'score_' in name or 'priority' in name:
            categories['scoring'].append((line_no, vis, name))
        # Compaction functions
        elif 'compact_' in name or 'merge_' in name:
            categories['compaction'].append((line_no, vis, name))
        # Parsing functions
        elif 'parse_' in name or 'extract_' in name:
            categories['parsing'].append((line_no, vis, name))
        # Validation functions
        elif any(x in name for x in ['_is_', '_has_', '_matches_', '_looks_', '_needs_']):
            categories['validation'].append((line_no, vis, name))
        # Utility functions
        elif any(x in name for x in ['normalize_', 'clip_', 'strip_', 'trim_', 'rebuild_']):
            categories['utils'].append((line_no, vis, name))
        # Focus/tag functions
        elif any(x in name for x in ['_focus_', '_tag_', '_anchor_', '_mask_']):
            categories['focus'].append((line_no, vis, name))
        # Style memory functions
        elif 'style' in name and 'memory' in name:
            categories['style_memory'].append((line_no, vis, name))
        # Role memory functions
        elif 'role' in name and ('memory' in name or 'subject' in name):
            categories['role_memory'].append((line_no, vis, name))
        # Delivery memory functions
        elif 'delivery' in name:
            categories['delivery_memory'].append((line_no, vis, name))
        # Observation memory functions
        elif 'observation' in name:
            categories['observation'].append((line_no, vis, name))
        # Optimization functions
        elif 'optim' in name:
            categories['optimizer'].append((line_no, vis, name))
        else:
            categories['uncategorized'].append((line_no, vis, name))
    
    return {
        'functions': functions,
        'structs': structs,
        'enums': enums,
        'constants': constants,
        'categories': categories,
        'total_lines': len(lines)
    }

def main():
    filepath = Path('backend/src/production/workbench/video_prompt_memory/mod.rs')
    result = analyze_file(filepath)
    
    print(f"Total lines: {result['total_lines']}")
    print(f"\nTotal functions: {len(result['functions'])}")
    print(f"Total structs: {len(result['structs'])}")
    print(f"Total enums: {len(result['enums'])}")
    print(f"Total constants: {len(result['constants'])}")
    
    print("\n=== Structs ===")
    for line_no, vis, name in result['structs']:
        print(f"  {line_no:5d}: {vis:20s} {name}")
    
    print("\n=== Enums ===")
    for line_no, vis, name in result['enums']:
        print(f"  {line_no:5d}: {vis:20s} {name}")
    
    print("\n=== Function Categories ===")
    for category, funcs in sorted(result['categories'].items()):
        print(f"\n{category.upper()} ({len(funcs)} functions):")
        for line_no, vis, name in funcs[:10]:  # Show first 10
            print(f"  {line_no:5d}: {vis:20s} {name}")
        if len(funcs) > 10:
            print(f"  ... and {len(funcs) - 10} more")
    
    print("\n=== Public API Summary ===")
    public_funcs = [(l, v, n) for l, v, n in result['functions'] if 'pub' in v]
    print(f"Public functions: {len(public_funcs)}")
    for line_no, vis, name in public_funcs:
        print(f"  {line_no:5d}: {vis:20s} {name}")

if __name__ == '__main__':
    main()
