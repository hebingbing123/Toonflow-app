#!/usr/bin/env python3
"""
Script to help refactor video_prompt_memory/mod.rs into 16 submodules.
This script analyzes the file and generates the module structure.
"""

import re
from pathlib import Path
from typing import Dict, List, Set, Tuple

# Define the target module structure based on design.md
MODULES = {
    "types": {
        "description": "Data structures and type definitions",
        "patterns": [
            r"^(pub\(crate\)\s+)?struct\s+\w+",
            r"^(pub\(crate\)\s+)?enum\s+\w+",
            r"^const\s+\w+",
        ],
        "keywords": ["struct", "enum", "const", "Row", "Scope", "Bias", "Plan", "Result", "Candidate"],
    },
    "builder": {
        "description": "Memory building logic",
        "patterns": [r"fn\s+build_\w+"],
        "keywords": ["build_selected", "build_script", "build_project", "build_role"],
    },
    "selector": {
        "description": "Memory selection logic",
        "patterns": [r"fn\s+select_\w+"],
        "keywords": ["select_", "select_best", "select_prioritized", "select_neighbor"],
    },
    "optimizer": {
        "description": "Memory optimization logic",
        "patterns": [r"fn\s+optimize_\w+", r"fn\s+plan_\w+optimization"],
        "keywords": ["optimize", "plan_", "optimization"],
    },
    "persistence": {
        "description": "Persistence logic (load, save, delete, clear)",
        "patterns": [r"fn\s+(persist|load|delete|clear|refresh)_\w+"],
        "keywords": ["persist", "load", "delete", "clear", "refresh", "replace_"],
    },
    "scoring": {
        "description": "Scoring and sorting logic",
        "patterns": [r"fn\s+score_\w+", r"fn\s+\w+_priority"],
        "keywords": ["score_", "_priority", "rank", "weight"],
    },
    "compaction": {
        "description": "Compaction and deduplication logic",
        "patterns": [r"fn\s+compact_\w+"],
        "keywords": ["compact_", "dedupe", "merge_", "distinct_"],
    },
    "style_memory": {
        "description": "Style memory processing",
        "patterns": [r"fn\s+\w+style_memory\w+", r"fn\s+\w+style_note\w+"],
        "keywords": ["style_memory", "style_note", "video_style", "role_style"],
    },
    "role_memory": {
        "description": "Role memory processing",
        "patterns": [r"fn\s+\w+role_\w+memory", r"fn\s+\w+subject_role\w+"],
        "keywords": ["role_memory", "subject_role", "role_style", "role_video"],
    },
    "delivery_memory": {
        "description": "Delivery memory processing",
        "patterns": [r"fn\s+\w+delivery\w+"],
        "keywords": ["delivery", "voice_style", "performance_style"],
    },
    "parsing": {
        "description": "Parsing and extraction logic",
        "patterns": [r"fn\s+(parse|extract)_\w+"],
        "keywords": ["parse_", "extract_", "split_"],
    },
    "validation": {
        "description": "Validation and filtering logic",
        "patterns": [r"fn\s+\w+_is_\w+", r"fn\s+\w+_has_\w+", r"fn\s+\w+_matches\w+"],
        "keywords": ["_is_", "_has_", "_matches", "is_low_signal", "is_valid"],
    },
    "utils": {
        "description": "Utility functions",
        "patterns": [r"fn\s+(normalize|clip|remove|rebuild)_\w+"],
        "keywords": ["normalize_", "clip_", "remove_", "rebuild_", "prompt_fragments"],
    },
    "focus": {
        "description": "Focus and tag processing",
        "patterns": [r"fn\s+\w+focus\w+", r"fn\s+\w+tag\w+", r"fn\s+\w+anchor\w+"],
        "keywords": ["focus_", "_tag_", "_anchor", "bias_"],
    },
}

def analyze_file(file_path: str) -> Dict[str, List[str]]:
    """Analyze the file and categorize functions."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # Find all function definitions
    function_pattern = re.compile(r'^\s*(pub\(crate\)\s+)?(async\s+)?fn\s+(\w+)')
    
    categorized = {module: [] for module in MODULES.keys()}
    categorized["tests"] = []
    uncategorized = []
    
    for i, line in enumerate(lines):
        match = function_pattern.match(line)
        if match:
            func_name = match.group(3)
            full_line = line.strip()
            
            # Skip test functions
            if i > 0 and '#[test]' in lines[i-1]:
                categorized["tests"].append((i+1, func_name, full_line))
                continue
            
            # Try to categorize
            categorized_flag = False
            for module, config in MODULES.items():
                # Check patterns
                for pattern in config["patterns"]:
                    if re.search(pattern, full_line):
                        categorized[module].append((i+1, func_name, full_line))
                        categorized_flag = True
                        break
                
                if categorized_flag:
                    break
                
                # Check keywords
                for keyword in config["keywords"]:
                    if keyword in func_name or keyword in full_line:
                        categorized[module].append((i+1, func_name, full_line))
                        categorized_flag = True
                        break
                
                if categorized_flag:
                    break
            
            if not categorized_flag:
                uncategorized.append((i+1, func_name, full_line))
    
    return categorized, uncategorized

def print_analysis(categorized: Dict[str, List[str]], uncategorized: List[str]):
    """Print the analysis results."""
    print("=" * 80)
    print("FUNCTION CATEGORIZATION ANALYSIS")
    print("=" * 80)
    
    total_functions = 0
    for module, functions in categorized.items():
        if functions:
            print(f"\n{module.upper()} ({len(functions)} functions):")
            print("-" * 80)
            for line_num, func_name, full_line in functions[:10]:  # Show first 10
                print(f"  Line {line_num:5d}: {func_name}")
            if len(functions) > 10:
                print(f"  ... and {len(functions) - 10} more")
            total_functions += len(functions)
    
    print(f"\n{'=' * 80}")
    print(f"UNCATEGORIZED ({len(uncategorized)} functions):")
    print("-" * 80)
    for line_num, func_name, full_line in uncategorized[:20]:
        print(f"  Line {line_num:5d}: {func_name}")
    if len(uncategorized) > 20:
        print(f"  ... and {len(uncategorized) - 20} more")
    
    print(f"\n{'=' * 80}")
    print(f"TOTAL: {total_functions} categorized + {len(uncategorized)} uncategorized = {total_functions + len(uncategorized)} functions")
    print("=" * 80)

if __name__ == "__main__":
    file_path = "backend/src/production/workbench/video_prompt_memory/mod.rs"
    categorized, uncategorized = analyze_file(file_path)
    print_analysis(categorized, uncategorized)
