#!/usr/bin/env python3
"""
Split tests.rs into 3 test modules based on test function boundaries
"""

import re

# Read the tests file
with open('backend/src/production/workbench/video/generate/tests.rs', 'r') as f:
    content = f.read()

# Find all test function starts
test_pattern = r'(    #\[test\]\s+fn [a-z_]+\()'
matches = list(re.finditer(test_pattern, content))

print(f"Found {len(matches)} tests")
print(f"Total content length: {len(content)} chars")

# Split into 3 roughly equal parts
tests_per_file = len(matches) // 3
print(f"Target: ~{tests_per_file} tests per file")

# Find split points
split1_idx = matches[tests_per_file].start()
split2_idx = matches[tests_per_file * 2].start()

print(f"Split 1 at char {split1_idx} (test {tests_per_file})")
print(f"Split 2 at char {split2_idx} (test {tests_per_file * 2})")

# Extract the module header (everything before first test)
header_end = matches[0].start()
header = content[:header_end]

# Split the content
part1_tests = content[header_end:split1_idx]
part2_tests = content[split1_idx:split2_idx]
part3_tests = content[split2_idx:]

# Create the three test files
test1_content = header + part1_tests + "}\n"
test2_content = header + part2_tests + "}\n"
test3_content = header + part3_tests

# Write the files
with open('backend/src/production/workbench/video/generate/tests_part1.rs', 'w') as f:
    f.write(test1_content)

with open('backend/src/production/workbench/video/generate/tests_part2.rs', 'w') as f:
    f.write(test2_content)

with open('backend/src/production/workbench/video/generate/tests_part3.rs', 'w') as f:
    f.write(test3_content)

print(f"\nPart 1: {len(test1_content.splitlines())} lines ({tests_per_file} tests)")
print(f"Part 2: {len(test2_content.splitlines())} lines ({tests_per_file} tests)")
print(f"Part 3: {len(test3_content.splitlines())} lines ({len(matches) - tests_per_file * 2} tests)")
