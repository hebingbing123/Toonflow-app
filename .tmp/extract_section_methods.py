#!/usr/bin/env python3
"""
Extract large methods from section.dart to separate module files.
Option B: Simplified Delegation approach.
"""

import re
from pathlib import Path

# Read the original file
section_file = Path('frontend/lib/short_video_space/section.dart')
with open(section_file, 'r') as f:
    lines = f.readlines()

# Method extraction mappings
# Format: (method_name, start_line, end_line, target_module)
extractions = [
    # Production methods (largest first)
    ('_openAssemblyDefaultsEditor', 2525, 3130, 'section_production.dart'),
    ('_openAssemblyClipDeskOps', 2072, 2524, 'section_production.dart'),
    ('_loadProjectOverview', 1528, 1825, 'section_production.dart'),
    ('_runBatchCandidateClips', 265, 391, 'section_production.dart'),
    ('_setComparedStoryboardCurrent', 1992, 2036, 'section_production.dart'),
    ('_promptReplacementVideoUrl', 2037, 2071, 'section_production.dart'),
    
    # Scheduling methods
    ('_batchScheduleDrafts', 1194, 1310, 'section_publish_scheduling.dart'),
    ('_bulkScheduleDraftsForCalendarDay', 928, 1038, 'section_publish_scheduling.dart'),
    ('_scheduleFirstDraft', 810, 861, 'section_publish_scheduling.dart'),
    ('_scheduleAllDraftsSameTime', 862, 907, 'section_publish_scheduling.dart'),
    ('_pickScheduleTimeForDay', 908, 927, 'section_publish_scheduling.dart'),
    ('_pickScheduleDateTime', 779, 809, 'section_publish_scheduling.dart'),
    ('_clearPublishSchedule', 731, 778, 'section_publish_scheduling.dart'),
    
    # Publishing methods
    ('_batchPublishDrafts', 1311, 1425, 'section_publish.dart'),
    ('_batchArchiveDrafts', 1426, 1506, 'section_publish.dart'),
    ('_enqueuePublishJob', 492, 562, 'section_publish.dart'),
    ('_enqueueAllDraftJobs', 563, 613, 'section_publish.dart'),
    ('_retryFailedPublishJobs', 614, 663, 'section_publish.dart'),
    ('_confirmSemiAutoPublish', 1107, 1156, 'section_publish.dart'),
    ('_bootstrapPublishDraft', 437, 491, 'section_publish.dart'),
    ('_refreshPublishSlice', 415, 436, 'section_publish.dart'),
    ('_capturePublishSlice', 328, 376, 'section_publish.dart'),
    ('_publishTargetMaps', 377, 391, 'section_publish.dart'),
    ('_syncPublishAutomationModesFromMatrix', 392, 414, 'section_publish.dart'),
    
    # Copy management methods
    ('_suggestPublishCopy', 664, 730, 'section_publish_copy.dart'),
    ('_commitPublishPlatformCopy', 1039, 1106, 'section_publish_copy.dart'),
    
    # Project methods
    ('_loadProjects', 141, 195, 'section_project.dart'),
    ('_resolveProjectIdAfterReload', 196, 207, 'section_project.dart'),
    ('_applyProjectPreset', 208, 226, 'section_project.dart'),
    ('_onPublishPlatformTapped', 227, 241, 'section_project.dart'),
    ('_syncSelectedProjectContext', 242, 246, 'section_project.dart'),
    ('_modeFromProject', 247, 256, 'section_project.dart'),
    ('_normalizeVideoRatio', 257, 264, 'section_project.dart'),
    ('_createProjectFromSpace', 1826, 1893, 'section_project.dart'),
    ('_saveProjectConfig', 1894, 1991, 'section_project.dart'),
    
    # Multi-select handlers
    ('_toggleMultiSelectMode', 1157, 1166, 'section_publish.dart'),
    ('_toggleDraftSelection', 1167, 1179, 'section_publish.dart'),
    ('_selectAllDrafts', 1180, 1186, 'section_publish.dart'),
    ('_clearDraftSelection', 1187, 1193, 'section_publish.dart'),
    ('_compareDrafts', 1507, 1521, 'section_publish.dart'),
    ('_onDeliveryModeFilterChanged', 1522, 1527, 'section_publish.dart'),
]

print(f"Total lines to extract: {sum(end - start + 1 for _, start, end, _ in extractions)}")
print(f"Original file: {len(lines)} lines")
print(f"Estimated remaining: {len(lines) - sum(end - start + 1 for _, start, end, _ in extractions)} lines")
