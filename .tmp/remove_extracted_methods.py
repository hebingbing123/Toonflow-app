#!/usr/bin/env python3
"""
Remove extracted methods from section.dart
"""

from pathlib import Path

# Read the original file
section_path = Path('frontend/lib/short_video_space/section.dart')
with open(section_path, 'r') as f:
    lines = f.readlines()

# Method ranges to remove (1-indexed, inclusive)
removals = [
    (265, 391),   # _runBatchCandidateClips
    (928, 1038),  # _bulkScheduleDraftsForCalendarDay
    (1194, 1310), # _batchScheduleDrafts
    (1311, 1425), # _batchPublishDrafts
    (1426, 1506), # _batchArchiveDrafts
    (1528, 1825), # _loadProjectOverview
    (2072, 2524), # _openAssemblyClipDeskOps
    (2525, 3130), # _openAssemblyDefaultsEditor
]

# Sort by start line (descending) so we can remove from bottom to top
removals.sort(reverse=True)

# Remove each range
for start, end in removals:
    # Convert to 0-indexed
    start_idx = start - 1
    end_idx = end  # end is inclusive, so we keep it as-is for slicing
    
    # Remove the lines
    del lines[start_idx:end_idx]
    print(f"Removed lines {start}-{end} ({end - start + 1} lines)")

# Write back
with open(section_path, 'w') as f:
    f.writelines(lines)

print(f"\nNew file size: {len(lines)} lines")
print(f"Target was ≤800 lines: {'✓ PASS' if len(lines) <= 800 else '✗ FAIL'}")
