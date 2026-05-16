#!/usr/bin/env python3
"""
Create proper test module structure
"""

# Read the split test files
with open('backend/src/production/workbench/video/generate/tests_part1.rs', 'r') as f:
    part1 = f.read()

with open('backend/src/production/workbench/video/generate/tests_part2.rs', 'r') as f:
    part2 = f.read()

with open('backend/src/production/workbench/video/generate/tests_part3.rs', 'r') as f:
    part3 = f.read()

# Extract the common header (imports and helper functions)
# The header is everything before the first #[test]
import re

def extract_header_and_tests(content):
    """Extract header (before first test) and test content"""
    match = re.search(r'    #\[test\]', content)
    if match:
        header_end = match.start()
        header = content[:header_end]
        tests = content[header_end:]
        return header, tests
    return content, ""

header1, tests1 = extract_header_and_tests(part1)
header2, tests2 = extract_header_and_tests(part2)
header3, tests3 = extract_header_and_tests(part3)

# Use the first header as the common header (they should all be the same)
common_header = header1

# Create module files
# Part 1: negative prompt building and review tests
mod1_content = common_header + tests1

# Part 2: style note and memory tests  
mod2_content = common_header + tests2

# Part 3: merge and budget tests
mod3_content = common_header + tests3

# Write the module files
with open('backend/src/production/workbench/video/generate/tests/negative_prompt_tests.rs', 'w') as f:
    f.write(mod1_content)

with open('backend/src/production/workbench/video/generate/tests/style_memory_tests.rs', 'w') as f:
    f.write(mod2_content)

with open('backend/src/production/workbench/video/generate/tests/merge_budget_tests.rs', 'w') as f:
    f.write(mod3_content)

# Create mod.rs for the tests module
mod_rs_content = """#[cfg(test)]
mod negative_prompt_tests;

#[cfg(test)]
mod style_memory_tests;

#[cfg(test)]
mod merge_budget_tests;
"""

with open('backend/src/production/workbench/video/generate/tests/mod.rs', 'w') as f:
    f.write(mod_rs_content)

print("Created test modules:")
print(f"  negative_prompt_tests.rs: {len(mod1_content.splitlines())} lines")
print(f"  style_memory_tests.rs: {len(mod2_content.splitlines())} lines")
print(f"  merge_budget_tests.rs: {len(mod3_content.splitlines())} lines")
print(f"  mod.rs: {len(mod_rs_content.splitlines())} lines")
