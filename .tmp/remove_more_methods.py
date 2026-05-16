#!/usr/bin/env python3
"""
Remove the additionally extracted methods from section.dart
"""

from pathlib import Path

# Read the current file
section_path = Path('frontend/lib/short_video_space/section.dart')
with open(section_path, 'r') as f:
    lines = f.readlines()

# Method ranges to remove (current line numbers)
removals = [
    (314, 368),   # _bootstrapPublishDraft
    (369, 439),   # _enqueuePublishJob
    (440, 490),   # _enqueueAllDraftJobs
    (491, 540),   # _retryFailedPublishJobs
    (541, 607),   # _suggestPublishCopy
    (608, 655),   # _clearPublishSchedule
    (687, 738),   # _scheduleFirstDraft
    (739, 784),   # _scheduleAllDraftsSameTime
    (805, 872),   # _commitPublishPlatformCopy
    (873, 922),   # _confirmSemiAutoPublish
    (981, 1048),  # _createProjectFromSpace
    (1049, 1146), # _saveProjectConfig
    (1147, 1191), # _setComparedStoryboardCurrent
]

# Sort by start line (descending) so we can remove from bottom to top
removals.sort(reverse=True)

# Remove each range
for start, end in removals:
    # Convert to 0-indexed
    start_idx = start - 1
    end_idx = end  # end is inclusive
    
    # Remove the lines
    del lines[start_idx:end_idx]
    print(f"Removed lines {start}-{end} ({end - start + 1} lines)")

# Write back
with open(section_path, 'w') as f:
    f.writelines(lines)

print(f"\nNew file size: {len(lines)} lines")
print(f"Target was ≤800 lines: {'✓ PASS' if len(lines) <= 800 else '✗ FAIL - need to extract ~' + str(len(lines) - 800) + ' more lines'}")
