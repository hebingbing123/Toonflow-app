#!/usr/bin/env python3
"""
Re-split negative_prompt files to get builder under 800 lines.
Move budget tier and some helper functions to analysis.
"""

# Read current files
with open('backend/src/production/workbench/video/generate/negative_prompt_builder.rs', 'r') as f:
    builder_lines = f.readlines()

with open('backend/src/production/workbench/video/generate/negative_prompt_analysis.rs', 'r') as f:
    analysis_lines = f.readlines()

print(f"Current builder lines: {len(builder_lines)}")
print(f"Current analysis lines: {len(analysis_lines)}")

# Find the line where resolve_negative_prompt_budget_tier starts
# This is around line 361 in the builder
split_point = None
for i, line in enumerate(builder_lines):
    if line.strip().startswith('fn resolve_negative_prompt_budget_tier('):
        split_point = i
        print(f"Found resolve_negative_prompt_budget_tier at line {i+1}")
        break

if split_point is None:
    print("Could not find split point!")
    exit(1)

# Split: keep lines 0 to split_point-1 in builder, move rest to analysis
new_builder_lines = builder_lines[:split_point]
moved_lines = builder_lines[split_point:]

print(f"New builder will have {len(new_builder_lines)} lines")
print(f"Moving {len(moved_lines)} lines to analysis")

# The analysis file already has imports, so we need to insert the moved content after imports
# Find where the imports end in analysis (after the last 'use' statement)
import_end = 0
for i, line in enumerate(analysis_lines):
    if line.strip().startswith('use ') or line.strip().startswith('use super::') or line.strip().startswith('use crate::'):
        import_end = i + 1

print(f"Analysis imports end at line {import_end}")

# Insert moved content after imports
new_analysis_lines = analysis_lines[:import_end] + ['\n'] + moved_lines + ['\n'] + analysis_lines[import_end:]

print(f"New analysis will have {len(new_analysis_lines)} lines")

# Write the files
with open('backend/src/production/workbench/video/generate/negative_prompt_builder.rs', 'w') as f:
    f.writelines(new_builder_lines)

with open('backend/src/production/workbench/video/generate/negative_prompt_analysis.rs', 'w') as f:
    f.writelines(new_analysis_lines)

print("Re-split complete!")
