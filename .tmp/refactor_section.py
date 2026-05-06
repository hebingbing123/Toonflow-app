#!/usr/bin/env python3
"""
Refactor frontend/lib/short_video_space/section.dart into 7 modules
"""

import re
from pathlib import Path
from typing import List, Tuple

def extract_lines(content: str, start: int, end: int) -> str:
    """Extract lines from content (1-indexed line numbers)"""
    lines = content.splitlines(keepends=True)
    return ''.join(lines[start-1:end])

def read_file(path: str) -> str:
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path: str, content: str):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def find_method_end(lines: List[str], start_line: int) -> int:
    """Find the end of a method by counting braces"""
    brace_count = 0
    in_method = False
    
    for i in range(start_line, len(lines)):
        line = lines[i]
        
        # Count braces
        for char in line:
            if char == '{':
                brace_count += 1
                in_method = True
            elif char == '}':
                brace_count -= 1
                
        # Method ends when braces balance
        if in_method and brace_count == 0:
            return i + 1
    
    return len(lines)

def main():
    source_file = 'frontend/lib/short_video_space/section.dart'
    content = read_file(source_file)
    lines = content.splitlines(keepends=True)
    
    # Extract imports (lines 1-7)
    imports = ''.join(lines[0:7])
    
    # Method line ranges (from grep output)
    # Project methods
    project_methods_ranges = [
        (141, 207),   # _loadProjects
        (195, 207),   # _resolveProjectIdAfterReload (nested in _loadProjects, extract separately)
        (208, 226),   # _applyProjectPreset
        (227, 241),   # _onPublishPlatformTapped
        (242, 246),   # _syncSelectedProjectContext
        (247, 256),   # _modeFromProject
        (257, 264),   # _normalizeVideoRatio
        (1826, 1893), # _createProjectFromSpace
        (1894, 1961), # _saveProjectConfig
        (1962, 1991), # _nextStepAction
    ]
    
    # Production methods
    production_methods_ranges = [
        (265, 376),   # _runBatchCandidateClips
        (1528, 1825), # _loadProjectOverview
        (1992, 2036), # _setComparedStoryboardCurrent
        (2037, 2071), # _promptReplacementVideoUrl
        (2072, 2524), # _openAssemblyClipDeskOps
        (2525, 2620), # _openAssemblyDefaultsEditor
    ]
    
    # Publish methods
    publish_methods_ranges = [
        (318, 376),   # _capturePublishSlice (nested in _runBatchCandidateClips)
        (377, 391),   # _publishTargetMaps
        (392, 414),   # _syncPublishAutomationModesFromMatrix
        (415, 436),   # _refreshPublishSlice
        (437, 491),   # _bootstrapPublishDraft
        (492, 562),   # _enqueuePublishJob
        (563, 613),   # _enqueueAllDraftJobs
        (614, 663),   # _retryFailedPublishJobs
        (1107, 1156), # _confirmSemiAutoPublish
    ]
    
    # Scheduling methods
    scheduling_methods_ranges = [
        (731, 778),   # _clearPublishSchedule
        (779, 809),   # _pickScheduleDateTime
        (810, 861),   # _scheduleFirstDraft
        (862, 907),   # _scheduleAllDraftsSameTime
        (908, 927),   # _pickScheduleTimeForDay
        (928, 1038),  # _bulkScheduleDraftsForCalendarDay
    ]
    
    # Copy methods
    copy_methods_ranges = [
        (664, 730),   # _suggestPublishCopy
        (1039, 1106), # _commitPublishPlatformCopy
    ]
    
    # Multi-select and other methods (keep in main section.dart)
    other_methods_ranges = [
        (1157, 1166), # _toggleMultiSelectMode
        (1167, 1179), # _toggleDraftSelection
        (1180, 1186), # _selectAllDrafts
        (1187, 1193), # _clearDraftSelection
        (1194, 1310), # _batchScheduleDrafts
        (1311, 1425), # _batchPublishDrafts
        (1426, 1506), # _batchArchiveDrafts
        (1507, 1520), # _compareDrafts
        (1522, 1527), # _onDeliveryModeFilterChanged
    ]
    
    print(f"Total lines in source: {len(lines)}")
    print(f"Imports: {len(imports.splitlines())} lines")
    print(f"Project methods: {len(project_methods_ranges)} methods")
    print(f"Production methods: {len(production_methods_ranges)} methods")
    print(f"Publish methods: {len(publish_methods_ranges)} methods")
    print(f"Scheduling methods: {len(scheduling_methods_ranges)} methods")
    print(f"Copy methods: {len(copy_methods_ranges)} methods")
    print(f"Other methods: {len(other_methods_ranges)} methods")
    
    # Note: Due to the complexity of nested methods and the build() method,
    # manual extraction is recommended for accuracy

if __name__ == '__main__':
    main()
