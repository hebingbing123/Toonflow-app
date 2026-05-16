#!/usr/bin/env python3
"""
Split frontend/lib/short_video_space/section.dart into 7 modules
"""

import re
from pathlib import Path

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    source_path = Path('frontend/lib/short_video_space/section.dart')
    content = read_file(source_path)
    
    # Extract imports
    imports_match = re.search(r'^(import .*?;.*?)(?=\n\nclass)', content, re.DOTALL | re.MULTILINE)
    imports = imports_match.group(1) if imports_match else ''
    
    # Find the class definition start
    class_start = content.find('class ShortVideoSpaceSection')
    class_header_end = content.find('{', class_start)
    class_header = content[class_start:class_header_end + 1]
    
    # Find widget properties (before State class)
    state_class_start = content.find('class _ShortVideoSpaceSectionState')
    widget_section = content[class_header_end + 1:state_class_start].strip()
    
    # Extract state class header
    state_class_header_end = content.find('{', state_class_start)
    state_class_header = content[state_class_start:state_class_header_end + 1]
    
    # Find all state fields (before first method)
    first_method = content.find('bool get _isAnimated', state_class_header_end)
    state_fields = content[state_class_header_end + 1:first_method].strip()
    
    # Project methods: _loadProjects, _resolveProjectIdAfterReload, _applyProjectPreset, 
    # _onPublishPlatformTapped, _syncSelectedProjectContext, _modeFromProject, _normalizeVideoRatio
    # _createProjectFromSpace, _saveProjectConfig, _nextStepAction
    project_methods = []
    
    # Production methods: _runBatchCandidateClips, _loadProjectOverview, _setComparedStoryboardCurrent,
    # _promptReplacementVideoUrl, _openAssemblyClipDeskOps, _openAssemblyDefaultsEditor
    production_methods = []
    
    # Publish methods: _capturePublishSlice, _publishTargetMaps, _syncPublishAutomationModesFromMatrix,
    # _refreshPublishSlice, _bootstrapPublishDraft, _enqueuePublishJob, _enqueueAllDraftJobs,
    # _retryFailedPublishJobs, _confirmSemiAutoPublish
    publish_methods = []
    
    # Scheduling methods: _clearPublishSchedule, _pickScheduleDateTime, _scheduleFirstDraft,
    # _scheduleAllDraftsSameTime, _pickScheduleTimeForDay, _bulkScheduleDraftsForCalendarDay
    scheduling_methods = []
    
    # Copy methods: _suggestPublishCopy, _commitPublishPlatformCopy
    copy_methods = []
    
    # Multi-select methods: _toggleMultiSelectMode, _toggleDraftSelection, _selectAllDrafts,
    # _clearDraftSelection, _batchScheduleDrafts, _batchPublishDrafts, _batchArchiveDrafts,
    # _compareDrafts, _onDeliveryModeFilterChanged
    
    print("File analysis complete. Manual extraction required due to complexity.")
    print(f"Total lines: {len(content.splitlines())}")
    print(f"Imports section: {len(imports.splitlines())} lines")
    print(f"State fields: {len(state_fields.splitlines())} lines")

if __name__ == '__main__':
    main()
