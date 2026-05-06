#!/usr/bin/env python3
"""
Refactor section.dart using Dart's part/part of pattern.
This is the cleanest way to split a large StatefulWidget while maintaining access to private state.
"""

from pathlib import Path

# Read the original file
section_path = Path('frontend/lib/short_video_space/section.dart')
with open(section_path, 'r') as f:
    lines = f.readlines()

# Method extractions (1-indexed line numbers)
# Extract the 8 largest methods (>100 lines each)
extractions = [
    # Production methods (1484 lines total)
    ('_openAssemblyDefaultsEditor', 2525, 3130, 'section_production.dart'),
    ('_openAssemblyClipDeskOps', 2072, 2524, 'section_production.dart'),
    ('_loadProjectOverview', 1528, 1825, 'section_production.dart'),
    ('_runBatchCandidateClips', 265, 391, 'section_production.dart'),
    
    # Scheduling methods (228 lines total)
    ('_batchScheduleDrafts', 1194, 1310, 'section_publish_scheduling.dart'),
    ('_bulkScheduleDraftsForCalendarDay', 928, 1038, 'section_publish_scheduling.dart'),
    
    # Publish methods (196 lines total)
    ('_batchPublishDrafts', 1311, 1425, 'section_publish.dart'),
    ('_batchArchiveDrafts', 1426, 1506, 'section_publish.dart'),
]

# Group by module
from collections import defaultdict
by_module = defaultdict(list)
for method_name, start, end, module_file in extractions:
    by_module[module_file].append((method_name, start, end))

# Create each part file
for module_file, methods in sorted(by_module.items()):
    module_path = Path(f'frontend/lib/short_video_space/{module_file}')
    
    # Build module content
    module_content = [f"part of 'section.dart';\n\n"]
    module_content.append(f"// {module_file} - Extracted methods from _ShortVideoSpaceSectionState\n\n")
    
    # Add extension on the state class
    module_content.append("extension on _ShortVideoSpaceSectionState {\n")
    
    # Extract each method
    for method_name, start, end in sorted(methods, key=lambda x: x[1]):
        # Convert to 0-indexed
        start_idx = start - 1
        end_idx = end
        
        # Extract method lines
        method_lines = lines[start_idx:end_idx]
        
        # Add method to extension (keep indentation)
        module_content.extend(method_lines)
        module_content.append('\n')
    
    module_content.append("}\n")
    
    # Write module file
    with open(module_path, 'w') as f:
        f.writelines(module_content)
    
    total_lines = sum(end - start + 1 for _, start, end in methods)
    print(f"Created {module_file}: {len(methods)} methods, {total_lines} lines")

print(f"\nTotal extracted: {sum(end - start + 1 for _, start, end, _ in extractions)} lines")
print(f"\nNext: Add 'part' directives to section.dart and remove extracted methods")
