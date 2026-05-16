#!/usr/bin/env python3
"""
Perform the actual refactoring of video_prompt_memory/mod.rs.
Split the 12,497-line file into appropriate submodules.
"""

import re
from pathlib import Path
from typing import List, Dict, Tuple
from collections import defaultdict

def read_file_lines(filepath: Path) -> List[str]:
    """Read file and return lines."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_file(filepath: Path, content: str):
    """Write content to file."""
    filepath.parent.mkdir(parents=True, exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

def extract_function_or_struct(lines: List[str], start_idx: int) -> Tuple[int, str]:
    """
    Extract a complete function or struct definition starting at start_idx.
    Returns (end_idx, content).
    """
    # Find the opening brace
    brace_line = start_idx
    while brace_line < len(lines) and '{' not in lines[brace_line]:
        brace_line += 1
    
    if brace_line >= len(lines):
        # No brace found, might be a declaration
        end_idx = start_idx
        while end_idx < len(lines) and ';' not in lines[end_idx]:
            end_idx += 1
        return end_idx, ''.join(lines[start_idx:end_idx+1])
    
    # Count braces to find matching close
    depth = 0
    in_string = False
    in_char = False
    escape_next = False
    
    for i in range(brace_line, len(lines)):
        for j, char in enumerate(lines[i]):
            if escape_next:
                escape_next = False
                continue
            
            if char == '\\':
                escape_next = True
                continue
            
            if char == '"' and not in_char:
                in_string = not in_string
            elif char == "'" and not in_string:
                in_char = not in_char
            elif not in_string and not in_char:
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        return i, ''.join(lines[start_idx:i+1])
    
    return len(lines) - 1, ''.join(lines[start_idx:])

def categorize_function_name(name: str) -> str:
    """Determine which module a function belongs to based on its name."""
    name_lower = name.lower()
    
    # Style memory functions
    if ('style' in name_lower and 'memory' in name_lower) or \
       ('style' in name_lower and ('note' in name_lower or 'fragment' in name_lower)):
        return 'style_memory'
    
    # Role memory functions
    if 'role' in name_lower and ('memory' in name_lower or 'subject' in name_lower):
        return 'role_memory'
    
    # Delivery memory functions
    if 'delivery' in name_lower:
        return 'delivery_memory'
    
    # Builder functions
    if name_lower.startswith('build_') and 'selected' in name_lower:
        return 'builder'
    
    # Selector functions
    if name_lower.startswith('select_') and 'selected' in name_lower:
        return 'selector'
    
    # Optimizer functions
    if 'optim' in name_lower or name_lower.startswith('plan_'):
        return 'optimizer'
    
    # Persistence functions
    if any(x in name_lower for x in ['persist_', 'prepare_', 'load_', 'delete_', 'clear_']):
        return 'persistence'
    
    # Scoring functions
    if 'score_' in name_lower or 'priority' in name_lower:
        return 'scoring'
    
    # Compaction functions
    if 'compact_' in name_lower or 'merge_' in name_lower:
        return 'compaction'
    
    # Parsing functions
    if 'parse_' in name_lower or 'extract_' in name_lower:
        return 'parsing'
    
    # Validation functions
    if any(x in name_lower for x in ['_is_', '_has_', '_matches_', '_looks_', '_needs_', '_contains_']):
        return 'validation'
    
    # Utility functions
    if any(x in name_lower for x in ['normalize_', 'clip_', 'strip_', 'trim_', 'rebuild_']):
        return 'utils'
    
    # Focus/tag functions
    if any(x in name_lower for x in ['_focus_', '_tag_', '_anchor_', '_mask_']):
        return 'focus'
    
    # Default to utils
    return 'utils'

def main():
    source_file = Path('backend/src/production/workbench/video_prompt_memory/mod.rs')
    target_dir = Path('backend/src/production/workbench/video_prompt_memory')
    
    print(f"Reading {source_file}...")
    lines = read_file_lines(source_file)
    
    # Module contents
    modules = defaultdict(list)
    modules['types'] = []  # Constants and type definitions
    
    # Track what goes where
    i = 0
    header_lines = []
    
    # Extract header (clippy allows, existing mod declarations, use statements)
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('#![allow') or line.startswith('mod ') or \
           line.startswith('use ') or line.startswith('pub use') or \
           line.startswith('pub(crate) use') or line.startswith('#[cfg') or \
           line == '' or line.startswith('//'):
            header_lines.append(lines[i])
            i += 1
        elif line.startswith('const '):
            break
        else:
            break
    
    # Process the rest of the file
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines and comments between items
        if not line or line.startswith('//'):
            i += 1
            continue
        
        # Constants - go to types.rs
        if line.startswith('const '):
            end_idx = i
            while end_idx < len(lines) and ';' not in lines[end_idx]:
                end_idx += 1
            modules['types'].append(''.join(lines[i:end_idx+1]))
            i = end_idx + 1
            continue
        
        # Structs and enums - go to types.rs
        if re.match(r'^(pub(\(crate\))?\s+)?(struct|enum)\s+\w+', line):
            end_idx, content = extract_function_or_struct(lines, i)
            modules['types'].append(content)
            i = end_idx + 1
            continue
        
        # Functions
        if re.match(r'^(pub(\(crate\))?\s+)?(async\s+)?fn\s+(\w+)', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?(async\s+)?fn\s+(\w+)', line)
            func_name = match.group(4)
            end_idx, content = extract_function_or_struct(lines, i)
            
            # Categorize
            category = categorize_function_name(func_name)
            modules[category].append(content)
            
            i = end_idx + 1
            continue
        
        # Impl blocks - try to categorize by content
        if line.startswith('impl '):
            end_idx, content = extract_function_or_struct(lines, i)
            # Put impl blocks in utils for now
            modules['utils'].append(content)
            i = end_idx + 1
            continue
        
        i += 1
    
    # Print statistics
    print("\n=== Module Statistics ===")
    for module_name in sorted(modules.keys()):
        content = '\n'.join(modules[module_name])
        line_count = content.count('\n')
        print(f"{module_name:20s}: {len(modules[module_name]):3d} items, ~{line_count:5d} lines")
    
    # Check for oversized modules
    print("\n=== Modules exceeding 800 lines ===")
    for module_name in sorted(modules.keys()):
        content = '\n'.join(modules[module_name])
        line_count = content.count('\n')
        if line_count > 800:
            print(f"{module_name:20s}: ~{line_count:5d} lines (EXCEEDS LIMIT)")
    
    print("\nRefactoring complete! Module contents prepared.")
    print("Total modules:", len(modules))

if __name__ == '__main__':
    main()
