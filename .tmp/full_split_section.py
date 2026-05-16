#!/usr/bin/env python3
"""
Full automated split of section.dart into 7 modules
"""

import re
from pathlib import Path

def read_file(path):
    with open(path, 'r') as f:
        return f.read()

def write_file(path, content):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

def extract_method(lines, start_line, method_name):
    """Extract a complete method by counting braces"""
    brace_count = 0
    method_lines = []
    started = False
    
    for i in range(start_line - 1, len(lines)):
        line = lines[i]
        method_lines.append(line)
        
        for char in line:
            if char == '{':
                brace_count += 1
                started = True
            elif char == '}':
                brace_count -= 1
        
        if started and brace_count == 0:
            return '\n'.join(method_lines)
    
    return '\n'.join(method_lines)

def main():
    source = 'frontend/lib/short_video_space/section.dart'
    content = read_file(source)
    lines = content.splitlines()
    
    # Extract imports
    imports = '\n'.join(lines[0:7])
    
    # Extract state fields (lines 34-88)
    state_fields = '\n'.join(lines[33:88])
    
    # Method definitions with line numbers (from grep analysis)
    project_methods = {
        '_loadProjects': 141,
        '_applyProjectPreset': 208,
        '_onPublishPlatformTapped': 227,
        '_syncSelectedProjectContext': 242,
        '_modeFromProject': 247,
        '_normalizeVideoRatio': 257,
        '_createProjectFromSpace': 1826,
        '_saveProjectConfig': 1894,
        '_nextStepAction': 1962,
    }
    
    production_methods = {
        '_runBatchCandidateClips': 265,
        '_loadProjectOverview': 1528,
        '_setComparedStoryboardCurrent': 1992,
        '_promptReplacementVideoUrl': 2037,
        '_openAssemblyClipDeskOps': 2072,
        '_openAssemblyDefaultsEditor': 2525,
    }
    
    publish_methods = {
        '_capturePublishSlice': 318,  # Nested in _runBatchCandidateClips
        '_publishTargetMaps': 377,
        '_syncPublishAutomationModesFromMatrix': 392,
        '_refreshPublishSlice': 415,
        '_bootstrapPublishDraft': 437,
        '_enqueuePublishJob': 492,
        '_enqueueAllDraftJobs': 563,
        '_retryFailedPublishJobs': 614,
        '_confirmSemiAutoPublish': 1107,
    }
    
    scheduling_methods = {
        '_clearPublishSchedule': 731,
        '_pickScheduleDateTime': 779,
        '_scheduleFirstDraft': 810,
        '_scheduleAllDraftsSameTime': 862,
        '_pickScheduleTimeForDay': 908,
        '_bulkScheduleDraftsForCalendarDay': 928,
    }
    
    copy_methods = {
        '_suggestPublishCopy': 664,
        '_commitPublishPlatformCopy': 1039,
    }
    
    # Extract methods
    print("Extracting project methods...")
    project_code = []
    for name, line_num in sorted(project_methods.items(), key=lambda x: x[1]):
        method = extract_method(lines, line_num, name)
        project_code.append(method)
        print(f"  {name}: {len(method.splitlines())} lines")
    
    print("\nExtracting production methods...")
    production_code = []
    for name, line_num in sorted(production_methods.items(), key=lambda x: x[1]):
        method = extract_method(lines, line_num, name)
        production_code.append(method)
        print(f"  {name}: {len(method.splitlines())} lines")
    
    print("\nExtracting publish methods...")
    publish_code = []
    for name, line_num in sorted(publish_methods.items(), key=lambda x: x[1]):
        method = extract_method(lines, line_num, name)
        publish_code.append(method)
        print(f"  {name}: {len(method.splitlines())} lines")
    
    print("\nExtracting scheduling methods...")
    scheduling_code = []
    for name, line_num in sorted(scheduling_methods.items(), key=lambda x: x[1]):
        method = extract_method(lines, line_num, name)
        scheduling_code.append(method)
        print(f"  {name}: {len(method.splitlines())} lines")
    
    print("\nExtracting copy methods...")
    copy_code = []
    for name, line_num in sorted(copy_methods.items(), key=lambda x: x[1]):
        method = extract_method(lines, line_num, name)
        copy_code.append(method)
        print(f"  {name}: {len(method.splitlines())} lines")
    
    print(f"\nTotal extracted:")
    print(f"  Project: {sum(len(m.splitlines()) for m in project_code)} lines")
    print(f"  Production: {sum(len(m.splitlines()) for m in production_code)} lines")
    print(f"  Publish: {sum(len(m.splitlines()) for m in publish_code)} lines")
    print(f"  Scheduling: {sum(len(m.splitlines()) for m in scheduling_code)} lines")
    print(f"  Copy: {sum(len(m.splitlines()) for m in copy_code)} lines")

if __name__ == '__main__':
    main()
