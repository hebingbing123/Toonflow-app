#!/usr/bin/env python3
"""
Extract more methods to get below 800 lines
"""

from pathlib import Path
from collections import defaultdict

# Read the current file
section_path = Path('frontend/lib/short_video_space/section.dart')
with open(section_path, 'r') as f:
    lines = f.readlines()

# Additional methods to extract (current line numbers after first extraction)
# Target: extract ~500 more lines
additional_extractions = [
    # Project methods (218 lines)
    ('_createProjectFromSpace', 981, 1048, 'section_project.dart'),
    ('_saveProjectConfig', 1049, 1146, 'section_project.dart'),
    ('_setComparedStoryboardCurrent', 1147, 1191, 'section_production.dart'),
    
    # Publishing methods (323 lines)
    ('_bootstrapPublishDraft', 314, 368, 'section_publish.dart'),
    ('_enqueuePublishJob', 369, 439, 'section_publish.dart'),
    ('_enqueueAllDraftJobs', 440, 490, 'section_publish.dart'),
    ('_retryFailedPublishJobs', 491, 540, 'section_publish.dart'),
    ('_confirmSemiAutoPublish', 873, 922, 'section_publish.dart'),
    
    # Copy methods (66 lines)
    ('_suggestPublishCopy', 541, 607, 'section_publish_copy.dart'),
    ('_commitPublishPlatformCopy', 805, 872, 'section_publish_copy.dart'),
    
    # Scheduling methods (143 lines)
    ('_clearPublishSchedule', 608, 655, 'section_publish_scheduling.dart'),
    ('_scheduleFirstDraft', 687, 738, 'section_publish_scheduling.dart'),
    ('_scheduleAllDraftsSameTime', 739, 784, 'section_publish_scheduling.dart'),
]

# Group by module
by_module = defaultdict(list)
for method_name, start, end, module_file in additional_extractions:
    by_module[module_file].append((method_name, start, end))

# Append to existing part files or create new ones
for module_file, methods in sorted(by_module.items()):
    module_path = Path(f'frontend/lib/short_video_space/{module_file}')
    
    # Check if file exists
    if module_path.exists():
        # Read existing content
        with open(module_path, 'r') as f:
            existing_lines = f.readlines()
        
        # Remove the closing brace of the extension
        if existing_lines and existing_lines[-1].strip() == '}':
            existing_lines = existing_lines[:-1]
        
        module_content = existing_lines
    else:
        # Create new file
        module_content = [f"part of 'section.dart';\n\n"]
        module_content.append(f"// {module_file} - Extracted methods from _ShortVideoSpaceSectionState\n\n")
        module_content.append("extension on _ShortVideoSpaceSectionState {\n")
    
    # Extract each method
    for method_name, start, end in sorted(methods, key=lambda x: x[1]):
        # Convert to 0-indexed
        start_idx = start - 1
        end_idx = end
        
        # Extract method lines
        method_lines = lines[start_idx:end_idx]
        
        # Add method to extension
        module_content.extend(method_lines)
        module_content.append('\n')
    
    # Add closing brace
    module_content.append("}\n")
    
    # Write module file
    with open(module_path, 'w') as f:
        f.writelines(module_content)
    
    total_lines = sum(end - start + 1 for _, start, end in methods)
    status = "Updated" if module_path.exists() else "Created"
    print(f"{status} {module_file}: +{len(methods)} methods, +{total_lines} lines")

total_extracted = sum(end - start + 1 for _, start, end, _ in additional_extractions)
print(f"\nTotal additional extraction: {total_extracted} lines")
print(f"Expected remaining: ~{len(lines) - total_extracted} lines")
