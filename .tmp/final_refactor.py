#!/usr/bin/env python3
"""
Final refactoring script - splits video_prompt_memory/mod.rs into submodules.
Uses a pragmatic approach based on function name patterns and line ranges.
"""

import re
from pathlib import Path
from typing import List, Dict, Tuple
from collections import defaultdict

def read_production_code(filepath: Path) -> List[str]:
    """Read only the production code (before #[cfg(test)])."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find the test module start
    for i, line in enumerate(lines):
        if line.strip() == '#[cfg(test)]':
            return lines[:i]
    
    return lines

def extract_header(lines: List[str]) -> Tuple[List[str], int]:
    """Extract header lines (clippy allows, mod declarations, use statements)."""
    header = []
    i = 0
    
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('#![allow') or line.startswith('mod ') or \
           line.startswith('use ') or line.startswith('pub use') or \
           line.startswith('pub(crate) use') or line.startswith('#[cfg') or \
           line == '' or line.startswith('//'):
            header.append(lines[i])
            i += 1
        elif line.startswith('const '):
            break
        else:
            break
    
    return header, i

def find_function_ranges(lines: List[str], start_idx: int) -> List[Tuple[int, int, str, str]]:
    """
    Find all function ranges in the code.
    Returns list of (start_line, end_line, visibility, name).
    """
    functions = []
    i = start_idx
    
    while i < len(lines):
        line = lines[i].strip()
        
        # Match function definition
        fn_match = re.match(r'^(pub(?:\(crate\))?\s+)?(?:async\s+)?fn\s+(\w+)', line)
        if fn_match:
            vis = fn_match.group(1).strip() if fn_match.group(1) else 'private'
            name = fn_match.group(2)
            start = i
            
            # Find end of function (matching braces)
            if '{' in lines[i]:
                depth = 0
                for j in range(i, len(lines)):
                    for ch in lines[j]:
                        if ch == '{':
                            depth += 1
                        elif ch == '}':
                            depth -= 1
                            if depth == 0:
                                functions.append((start, j, vis, name))
                                i = j + 1
                                break
                    if depth == 0:
                        break
            else:
                i += 1
        else:
            i += 1
    
    return functions

def categorize_function(name: str) -> str:
    """Determine which module a function belongs to."""
    name_lower = name.lower()
    
    # Style memory
    if ('style' in name_lower and 'memory' in name_lower) or \
       ('style' in name_lower and ('note' in name_lower or 'fragment' in name_lower)):
        return 'style_memory'
    
    # Role memory
    if 'role' in name_lower and ('memory' in name_lower or 'subject' in name_lower):
        return 'role_memory'
    
    # Delivery
    if 'delivery' in name_lower:
        return 'delivery_memory'
    
    # Builder
    if name_lower.startswith('build_') and 'selected' in name_lower:
        return 'builder'
    
    # Selector
    if name_lower.startswith('select_') and 'selected' in name_lower:
        return 'selector'
    
    # Optimizer
    if 'optim' in name_lower or name_lower.startswith('plan_'):
        return 'optimizer'
    
    # Persistence
    if any(x in name_lower for x in ['persist_', 'prepare_', 'load_', 'delete_', 'clear_']):
        return 'persistence'
    
    # Scoring
    if 'score_' in name_lower or 'priority' in name_lower:
        return 'scoring'
    
    # Compaction
    if 'compact_' in name_lower or 'merge_' in name_lower:
        return 'compaction'
    
    # Parsing
    if 'parse_' in name_lower or 'extract_' in name_lower:
        return 'parsing'
    
    # Validation
    if any(x in name_lower for x in ['_is_', '_has_', '_matches_', '_looks_', '_needs_']):
        return 'validation'
    
    # Utils
    if any(x in name_lower for x in ['normalize_', 'clip_', 'strip_', 'trim_', 'rebuild_']):
        return 'utils'
    
    # Focus
    if any(x in name_lower for x in ['_focus_', '_tag_', '_anchor_', '_mask_']):
        return 'focus'
    
    return 'utils'

def generate_module_files(lines: List[str], header: List[str], target_dir: Path):
    """Generate all module files."""
    # Extract constants and types (before first function)
    header_end, _ = extract_header(lines)
    
    # Find where constants/types end and functions begin
    types_end = len(header)
    for i in range(len(header), len(lines)):
        line = lines[i].strip()
        if re.match(r'^(pub(?:\(crate\))?\s+)?fn\s+\w+', line):
            types_end = i
            break
    
    # Types module content
    types_content = ''.join(lines[len(header):types_end])
    
    # Find all functions
    functions = find_function_ranges(lines, types_end)
    
    print(f"Found {len(functions)} functions")
    
    # Categorize functions
    modules = defaultdict(list)
    for start, end, vis, name in functions:
        category = categorize_function(name)
        func_content = ''.join(lines[start:end+1])
        modules[category].append((name, vis, func_content))
    
    # Print statistics
    print("\n=== Module Statistics ===")
    for module_name in sorted(modules.keys()):
        funcs = modules[module_name]
        total_lines = sum(content.count('\n') for _, _, content in funcs)
        pub_count = sum(1 for _, vis, _ in funcs if 'pub' in vis)
        print(f"{module_name:20s}: {len(funcs):3d} functions ({pub_count:2d} public), ~{total_lines:5d} lines")
    
    # Write types.rs
    types_file = target_dir / 'types.rs'
    with open(types_file, 'w', encoding='utf-8') as f:
        f.write("// Type definitions, constants, and data structures\n\n")
        f.write("use serde::Deserialize;\n")
        f.write("use sqlx::PgPool;\n")
        f.write("use uuid::Uuid;\n\n")
        f.write("use crate::error::ApiError;\n\n")
        f.write(types_content)
    print(f"\nCreated {types_file}")
    
    # Write each module file
    for module_name, funcs in modules.items():
        module_file = target_dir / f"{module_name}.rs"
        with open(module_file, 'w', encoding='utf-8') as f:
            f.write(f"// {module_name.replace('_', ' ').title()} module\n\n")
            f.write("use super::types::*;\n")
            f.write("use crate::error::ApiError;\n")
            f.write("use sqlx::PgPool;\n")
            f.write("use uuid::Uuid;\n\n")
            
            for name, vis, content in funcs:
                f.write(content)
                f.write("\n\n")
        
        print(f"Created {module_file}")
    
    # Generate new mod.rs
    mod_file = target_dir / 'mod_new.rs'
    with open(mod_file, 'w', encoding='utf-8') as f:
        # Write header
        f.write(''.join(header))
        f.write("\n")
        
        # Declare submodules
        f.write("// Submodules\n")
        f.write("mod types;\n")
        for module_name in sorted(modules.keys()):
            f.write(f"mod {module_name};\n")
        f.write("\n")
        
        # Re-export public APIs
        f.write("// Re-export public APIs\n")
        f.write("pub(crate) use types::*;\n")
        for module_name, funcs in sorted(modules.items()):
            pub_funcs = [name for name, vis, _ in funcs if 'pub' in vis]
            if pub_funcs:
                f.write(f"pub(crate) use {module_name}::{{")
                f.write(", ".join(pub_funcs))
                f.write("};\n")
        f.write("\n")
        
        # Add test module reference
        f.write("// Tests remain in tests.rs\n")
        f.write("#[cfg(test)]\n")
        f.write("mod tests;\n")
    
    print(f"\nCreated {mod_file}")
    print("\nRefactoring complete! Review the generated files and replace mod.rs with mod_new.rs")

def main():
    source_file = Path('backend/src/production/workbench/video_prompt_memory/mod.rs')
    target_dir = source_file.parent
    
    print(f"Reading {source_file}...")
    lines = read_production_code(source_file)
    print(f"Production code: {len(lines)} lines")
    
    header, header_end = extract_header(lines)
    print(f"Header: {len(header)} lines")
    
    generate_module_files(lines, header, target_dir)

if __name__ == '__main__':
    main()
