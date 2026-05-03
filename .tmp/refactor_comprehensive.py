#!/usr/bin/env python3
"""
Comprehensive refactoring script for video_prompt_memory/mod.rs.
This script will:
1. Parse the entire file
2. Categorize all items (functions, structs, consts)
3. Generate submodule files
4. Create new mod.rs with re-exports
"""

import re
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass
from collections import defaultdict

@dataclass
class Item:
    """Represents a code item (function, struct, const, etc.)"""
    name: str
    visibility: str  # 'pub', 'pub(crate)', 'private'
    kind: str  # 'fn', 'struct', 'const', 'enum'
    start_line: int
    end_line: int
    content: str
    category: str = ''

def parse_rust_file(filepath: Path) -> Tuple[List[str], List[Item]]:
    """
    Parse a Rust file and extract all top-level items.
    Returns (header_lines, items).
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    items = []
    
    # Regular expressions for different item types
    fn_pattern = r'^(pub(?:\(crate\))?\s+)?(?:async\s+)?fn\s+(\w+)'
    struct_pattern = r'^(pub(?:\(crate\))?\s+)?struct\s+(\w+)'
    enum_pattern = r'^(pub(?:\(crate\))?\s+)?enum\s+(\w+)'
    const_pattern = r'^const\s+(\w+)'
    
    i = 0
    header_lines = []
    
    # Extract header
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
    
    # Parse items
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        
        # Skip empty lines and comments
        if not stripped or stripped.startswith('//'):
            i += 1
            continue
        
        # Try to match different item types
        fn_match = re.match(fn_pattern, stripped)
        struct_match = re.match(struct_pattern, stripped)
        enum_match = re.match(enum_pattern, stripped)
        const_match = re.match(const_pattern, stripped)
        
        if fn_match:
            vis = fn_match.group(1).strip() if fn_match.group(1) else 'private'
            name = fn_match.group(2)
            start = i
            end = find_item_end(lines, i, '{', '}')
            content = '\n'.join(lines[start:end+1])
            items.append(Item(name, vis, 'fn', start, end, content))
            i = end + 1
        elif struct_match:
            vis = struct_match.group(1).strip() if struct_match.group(1) else 'private'
            name = struct_match.group(2)
            start = i
            if '{' in stripped:
                end = find_item_end(lines, i, '{', '}')
            else:
                end = find_semicolon(lines, i)
            content = '\n'.join(lines[start:end+1])
            items.append(Item(name, vis, 'struct', start, end, content))
            i = end + 1
        elif enum_match:
            vis = enum_match.group(1).strip() if enum_match.group(1) else 'private'
            name = enum_match.group(2)
            start = i
            end = find_item_end(lines, i, '{', '}')
            content = '\n'.join(lines[start:end+1])
            items.append(Item(name, vis, 'enum', start, end, content))
            i = end + 1
        elif const_match:
            name = const_match.group(1)
            start = i
            end = find_semicolon(lines, i)
            content = '\n'.join(lines[start:end+1])
            items.append(Item(name, 'private', 'const', start, end, content))
            i = end + 1
        elif stripped.startswith('impl '):
            # Skip impl blocks for now
            start = i
            end = find_item_end(lines, i, '{', '}')
            i = end + 1
        else:
            i += 1
    
    return header_lines, items

def find_item_end(lines: List[str], start: int, open_char: str, close_char: str) -> int:
    """Find the end of an item by matching braces."""
    depth = 0
    in_string = False
    in_char = False
    escape = False
    
    for i in range(start, len(lines)):
        for ch in lines[i]:
            if escape:
                escape = False
                continue
            if ch == '\\':
                escape = True
                continue
            if ch == '"' and not in_char:
                in_string = not in_string
            elif ch == "'" and not in_string:
                in_char = not in_char
            elif not in_string and not in_char:
                if ch == open_char:
                    depth += 1
                elif ch == close_char:
                    depth -= 1
                    if depth == 0:
                        return i
    return len(lines) - 1

def find_semicolon(lines: List[str], start: int) -> int:
    """Find the line containing the next semicolon."""
    for i in range(start, len(lines)):
        if ';' in lines[i]:
            return i
    return start

def categorize_item(item: Item) -> str:
    """Determine which module an item belongs to."""
    if item.kind in ['struct', 'enum', 'const']:
        return 'types'
    
    name = item.name.lower()
    
    # Style memory
    if ('style' in name and 'memory' in name) or \
       ('style' in name and ('note' in name or 'fragment' in name)):
        return 'style_memory'
    
    # Role memory
    if 'role' in name and ('memory' in name or 'subject' in name):
        return 'role_memory'
    
    # Delivery
    if 'delivery' in name:
        return 'delivery_memory'
    
    # Builder
    if name.startswith('build_') and 'selected' in name:
        return 'builder'
    
    # Selector
    if name.startswith('select_') and 'selected' in name:
        return 'selector'
    
    # Optimizer
    if 'optim' in name or name.startswith('plan_'):
        return 'optimizer'
    
    # Persistence
    if any(x in name for x in ['persist_', 'prepare_', 'load_', 'delete_', 'clear_']):
        return 'persistence'
    
    # Scoring
    if 'score_' in name or 'priority' in name:
        return 'scoring'
    
    # Compaction
    if 'compact_' in name or 'merge_' in name:
        return 'compaction'
    
    # Parsing
    if 'parse_' in name or 'extract_' in name:
        return 'parsing'
    
    # Validation
    if any(x in name for x in ['_is_', '_has_', '_matches_', '_looks_', '_needs_']):
        return 'validation'
    
    # Utils
    if any(x in name for x in ['normalize_', 'clip_', 'strip_', 'trim_', 'rebuild_']):
        return 'utils'
    
    # Focus
    if any(x in name for x in ['_focus_', '_tag_', '_anchor_', '_mask_']):
        return 'focus'
    
    return 'utils'

def main():
    source_file = Path('backend/src/production/workbench/video_prompt_memory/mod.rs')
    
    print(f"Parsing {source_file}...")
    header_lines, items = parse_rust_file(source_file)
    
    print(f"Found {len(items)} items")
    
    # Categorize items
    modules = defaultdict(list)
    for item in items:
        category = categorize_item(item)
        item.category = category
        modules[category].append(item)
    
    # Print statistics
    print("\n=== Module Statistics ===")
    for module_name in sorted(modules.keys()):
        items_list = modules[module_name]
        total_lines = sum(item.end_line - item.start_line + 1 for item in items_list)
        pub_count = sum(1 for item in items_list if 'pub' in item.visibility)
        print(f"{module_name:20s}: {len(items_list):3d} items ({pub_count:2d} public), ~{total_lines:5d} lines")
    
    # Check oversized modules
    print("\n=== Modules exceeding 800 lines ===")
    for module_name in sorted(modules.keys()):
        items_list = modules[module_name]
        total_lines = sum(item.end_line - item.start_line + 1 for item in items_list)
        if total_lines > 800:
            print(f"{module_name:20s}: ~{total_lines:5d} lines (EXCEEDS)")
    
    # Save detailed report
    report_path = Path('.tmp/refactor_detailed_report.txt')
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("=== Detailed Refactoring Report ===\n\n")
        for module_name in sorted(modules.keys()):
            f.write(f"\n{'='*70}\n")
            f.write(f"Module: {module_name}\n")
            f.write(f"{'='*70}\n\n")
            for item in modules[module_name]:
                f.write(f"Lines {item.start_line+1:5d}-{item.end_line+1:5d}: ")
                f.write(f"{item.visibility:15s} {item.kind:8s} {item.name}\n")
    
    print(f"\nDetailed report saved to {report_path}")

if __name__ == '__main__':
    main()
