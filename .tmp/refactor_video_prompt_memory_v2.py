#!/usr/bin/env python3
"""
Refactor video_prompt_memory/mod.rs into 16 submodules.
This script performs the actual code migration based on the design document.
"""

import re
from pathlib import Path
from typing import List, Dict, Tuple, Set
from dataclasses import dataclass, field

@dataclass
class CodeBlock:
    """Represents a block of code (function, struct, enum, const, etc.)"""
    start_line: int
    end_line: int
    name: str
    visibility: str
    kind: str  # 'fn', 'struct', 'enum', 'const', 'mod', 'use', 'impl'
    content: str
    category: str = ''

def find_matching_brace(lines: List[str], start_idx: int) -> int:
    """Find the matching closing brace for an opening brace."""
    depth = 0
    in_string = False
    escape_next = False
    
    for i in range(start_idx, len(lines)):
        line = lines[i]
        for char in line:
            if escape_next:
                escape_next = False
                continue
            if char == '\\':
                escape_next = True
                continue
            if char == '"' and not in_string:
                in_string = True
            elif char == '"' and in_string:
                in_string = False
            elif not in_string:
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        return i
    return len(lines) - 1

def extract_code_blocks(filepath: Path) -> Tuple[List[str], List[CodeBlock], List[str]]:
    """Extract all code blocks from the file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    blocks = []
    header_lines = []
    i = 0
    
    # Extract header (clippy allows, mod declarations, use statements)
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith('#![allow') or line.startswith('mod ') or line.startswith('use ') or line.startswith('pub use') or line.startswith('pub(crate) use') or line == '' or line.startswith('//'):
            header_lines.append(lines[i])
            i += 1
        elif line.startswith('const '):
            break
        else:
            break
    
    # Extract code blocks
    while i < len(lines):
        line = lines[i].strip()
        
        # Skip empty lines and comments
        if not line or line.startswith('//'):
            i += 1
            continue
        
        # Constants
        if line.startswith('const '):
            match = re.match(r'const\s+(\w+)', line)
            if match:
                name = match.group(1)
                # Find end of constant (semicolon)
                end_idx = i
                while end_idx < len(lines) and ';' not in lines[end_idx]:
                    end_idx += 1
                content = ''.join(lines[i:end_idx+1])
                blocks.append(CodeBlock(
                    start_line=i+1,
                    end_line=end_idx+1,
                    name=name,
                    visibility='private',
                    kind='const',
                    content=content
                ))
                i = end_idx + 1
                continue
        
        # Structs
        if re.match(r'^(pub(\(crate\))?\s+)?struct\s+\w+', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?struct\s+(\w+)', line)
            visibility = match.group(1).strip() if match.group(1) else 'private'
            name = match.group(3)
            
            # Find end of struct
            if '{' in lines[i]:
                end_idx = find_matching_brace(lines, i)
            else:
                # Tuple struct or unit struct
                end_idx = i
                while end_idx < len(lines) and ';' not in lines[end_idx]:
                    end_idx += 1
            
            content = ''.join(lines[i:end_idx+1])
            blocks.append(CodeBlock(
                start_line=i+1,
                end_line=end_idx+1,
                name=name,
                visibility=visibility,
                kind='struct',
                content=content
            ))
            i = end_idx + 1
            continue
        
        # Enums
        if re.match(r'^(pub(\(crate\))?\s+)?enum\s+\w+', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?enum\s+(\w+)', line)
            visibility = match.group(1).strip() if match.group(1) else 'private'
            name = match.group(3)
            end_idx = find_matching_brace(lines, i)
            content = ''.join(lines[i:end_idx+1])
            blocks.append(CodeBlock(
                start_line=i+1,
                end_line=end_idx+1,
                name=name,
                visibility=visibility,
                kind='enum',
                content=content
            ))
            i = end_idx + 1
            continue
        
        # Functions
        if re.match(r'^(pub(\(crate\))?\s+)?(async\s+)?fn\s+\w+', line):
            match = re.match(r'^(pub(\(crate\))?\s+)?(async\s+)?fn\s+(\w+)', line)
            visibility = match.group(1).strip() if match.group(1) else 'private'
            name = match.group(4)
            
            # Find end of function
            if '{' in lines[i]:
                end_idx = find_matching_brace(lines, i)
            else:
                # Function declaration without body (trait)
                end_idx = i
                while end_idx < len(lines) and ';' not in lines[end_idx]:
                    end_idx += 1
            
            content = ''.join(lines[i:end_idx+1])
            blocks.append(CodeBlock(
                start_line=i+1,
                end_line=end_idx+1,
                name=name,
                visibility=visibility,
                kind='fn',
                content=content
            ))
            i = end_idx + 1
            continue
        
        # Impl blocks
        if line.startswith('impl '):
            end_idx = find_matching_brace(lines, i)
            content = ''.join(lines[i:end_idx+1])
            blocks.append(CodeBlock(
                start_line=i+1,
                end_line=end_idx+1,
                name='impl',
                visibility='private',
                kind='impl',
                content=content
            ))
            i = end_idx + 1
            continue
        
        i += 1
    
    return lines, blocks, header_lines

def categorize_block(block: CodeBlock) -> str:
    """Categorize a code block based on its name and content."""
    name = block.name.lower()
    content = block.content.lower()
    
    # Types go to types.rs
    if block.kind in ['struct', 'enum']:
        return 'types'
    
    # Constants go to types.rs
    if block.kind == 'const':
        return 'types'
    
    # Categorize functions
    if block.kind == 'fn':
        # Builder functions
        if 'build_' in name and 'style' in name and 'memory' in name:
            return 'style_memory'
        elif 'build_' in name and 'role' in name:
            return 'role_memory'
        elif 'build_' in name and 'observation' in name:
            return 'observation'
        elif 'build_' in name and 'brief' in name:
            return 'brief'
        elif 'build_' in name and 'rejected' in name:
            return 'rejected'
        elif 'build_' in name:
            return 'builder'
        
        # Selector functions
        elif 'select_' in name and 'style' in name:
            return 'style_memory'
        elif 'select_' in name and 'role' in name:
            return 'role_memory'
        elif 'select_' in name and 'observation' in name:
            return 'observation'
        elif 'select_' in name and 'rejected' in name:
            return 'rejected'
        elif 'select_' in name:
            return 'selector'
        
        # Persistence functions
        elif any(x in name for x in ['persist_', 'load_', 'delete_', 'clear_']):
            return 'persistence'
        
        # Scoring functions
        elif 'score_' in name or 'priority' in name:
            return 'scoring'
        
        # Compaction functions
        elif 'compact_' in name or 'merge_' in name:
            return 'compaction'
        
        # Parsing functions
        elif 'parse_' in name or 'extract_' in name:
            return 'parsing'
        
        # Validation functions
        elif any(x in name for x in ['_is_', '_has_', '_matches_', '_looks_', '_needs_', '_contains_']):
            return 'validation'
        
        # Utility functions
        elif any(x in name for x in ['normalize_', 'clip_', 'strip_', 'trim_', 'rebuild_']):
            return 'utils'
        
        # Focus/tag functions
        elif any(x in name for x in ['_focus_', '_tag_', '_anchor_', '_mask_']):
            return 'focus'
        
        # Style memory functions
        elif 'style' in name and 'memory' in name:
            return 'style_memory'
        
        # Role memory functions
        elif 'role' in name and 'memory' in name:
            return 'role_memory'
        
        # Delivery memory functions
        elif 'delivery' in name:
            return 'delivery_memory'
        
        # Observation memory functions
        elif 'observation' in name:
            return 'observation'
        
        # Optimization functions
        elif 'optim' in name:
            return 'optimizer'
        
        # Prepare functions (persistence)
        elif 'prepare_' in name:
            return 'persistence'
        
        # Plan functions (optimizer)
        elif 'plan_' in name:
            return 'optimizer'
        
        # Default to utils
        else:
            return 'utils'
    
    return 'utils'

def main():
    source_file = Path('backend/src/production/workbench/video_prompt_memory/mod.rs')
    
    print(f"Analyzing {source_file}...")
    lines, blocks, header_lines = extract_code_blocks(source_file)
    
    print(f"Found {len(blocks)} code blocks")
    
    # Categorize blocks
    categories: Dict[str, List[CodeBlock]] = {}
    for block in blocks:
        category = categorize_block(block)
        block.category = category
        if category not in categories:
            categories[category] = []
        categories[category].append(block)
    
    # Print categorization summary
    print("\n=== Categorization Summary ===")
    for category, blocks_list in sorted(categories.items()):
        total_lines = sum(b.end_line - b.start_line + 1 for b in blocks_list)
        print(f"{category:20s}: {len(blocks_list):3d} blocks, ~{total_lines:5d} lines")
    
    # Check which categories are too large
    print("\n=== Categories exceeding 800 lines ===")
    for category, blocks_list in sorted(categories.items()):
        total_lines = sum(b.end_line - b.start_line + 1 for b in blocks_list)
        if total_lines > 800:
            print(f"{category:20s}: ~{total_lines:5d} lines (EXCEEDS LIMIT)")
    
    # Save categorization report
    report_path = Path('.tmp/refactor_categorization_report.txt')
    with open(report_path, 'w') as f:
        f.write("=== Categorization Report ===\n\n")
        for category in sorted(categories.keys()):
            f.write(f"\n{'='*60}\n")
            f.write(f"Category: {category.upper()}\n")
            f.write(f"{'='*60}\n\n")
            for block in categories[category]:
                f.write(f"{block.start_line:5d}-{block.end_line:5d}: {block.visibility:20s} {block.kind:10s} {block.name}\n")
    
    print(f"\nCategorization report saved to {report_path}")

if __name__ == '__main__':
    main()
