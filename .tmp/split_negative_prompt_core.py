#!/usr/bin/env python3
"""
Split negative_prompt_core.rs into two files:
- negative_prompt_builder.rs (context building, selection, scene analysis)
- negative_prompt_analysis.rs (style note resolution, fragment processing)
"""

import re

# Read the original file
with open('backend/src/production/workbench/video/generate/negative_prompt_core.rs', 'r') as f:
    lines = f.readlines()

print(f"Total lines: {len(lines)}")

# Find the split point - after negative_fragment_requires_strict_continuity_budget function (around line 870)
# This function ends at line 870, so we split at line 871
split_line = 871

# Part 1: Lines 1-870 (builder logic)
builder_lines = lines[:split_line]

# Part 2: Lines 871-end (analysis logic)
analysis_lines = lines[split_line:]

print(f"Builder lines: {len(builder_lines)}")
print(f"Analysis lines: {len(analysis_lines)}")

# Create builder file
builder_content = ''.join(builder_lines)

# Create analysis file - need to add imports
analysis_imports = """use std::collections::HashMap;

use super::*;
use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
use crate::production::workbench::video_prompt_memory::{
    clip_prompt_fragment, compact_video_style_prompt_note, normalize_prompt_text,
    parse_structured_storyboard_description, select_prioritized_video_style_note,
    select_project_video_style_memory_notes_for_storyboard,
    select_script_video_style_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes_for_storyboard, split_prompt_note_fragments,
    AgentMemoryRow, StoryboardPromptSeedRow, StructuredStoryboardDescription,
};

use super::fragment_operations::negative_fragment_is_covered;
use super::fragment_parsing::{canonical_negative_fragment, negative_fragment_family};

"""

analysis_content = analysis_imports + ''.join(analysis_lines)

# Write the files
with open('backend/src/production/workbench/video/generate/negative_prompt_builder.rs', 'w') as f:
    f.write(builder_content)

with open('backend/src/production/workbench/video/generate/negative_prompt_analysis.rs', 'w') as f:
    f.write(analysis_content)

print("Split complete!")
print(f"negative_prompt_builder.rs: {len(builder_lines)} lines")
print(f"negative_prompt_analysis.rs: {len(analysis_imports.splitlines()) + len(analysis_lines)} lines")
