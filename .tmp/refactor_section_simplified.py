#!/usr/bin/env python3
"""
Simplified Delegation refactoring for section.dart.
Extract only the LARGEST methods (>100 lines) to modules.
Keep the structure intact, just delegate to extracted functions.
"""

import re
from pathlib import Path
from collections import defaultdict

# Read the original file
section_file = Path('frontend/lib/short_video_space/section.dart')
with open(section_file, 'r') as f:
    content = f.read()
    lines = f.readlines()

# Methods to extract (only those >100 lines)
# Format: (method_name, start_line (1-indexed), end_line (1-indexed), target_module)
large_methods = [
    # Production methods (1354 lines total)
    ('_openAssemblyDefaultsEditor', 2525, 3130, 'production'),
    ('_openAssemblyClipDeskOps', 2072, 2524, 'production'),
    ('_loadProjectOverview', 1528, 1825, 'production'),
    ('_runBatchCandidateClips', 265, 391, 'production'),
    
    # Scheduling methods (426 lines total)
    ('_batchScheduleDrafts', 1194, 1310, 'scheduling'),
    ('_bulkScheduleDraftsForCalendarDay', 928, 1038, 'scheduling'),
    
    # Publishing methods (228 lines total)
    ('_batchPublishDrafts', 1311, 1425, 'publish'),
    ('_batchArchiveDrafts', 1426, 1506, 'publish'),
]

# Group by module
by_module = defaultdict(list)
for method_name, start, end, module in large_methods:
    by_module[module].append((method_name, start, end))

total_extracted = sum(end - start + 1 for _, start, end, _ in large_methods)
print(f"Extracting {len(large_methods)} methods ({total_extracted} lines)")
print(f"Original: {len(lines)} lines")
print(f"Target remaining: ~{len(lines) - total_extracted} lines")
print()

for module, methods in sorted(by_module.items()):
    module_lines = sum(end - start + 1 for _, start, end in methods)
    print(f"{module}: {len(methods)} methods, {module_lines} lines")
