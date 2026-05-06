#!/usr/bin/env python3
"""Complete refactoring of view.dart to use extracted widgets."""

def main():
    with open('frontend/lib/short_video_space/view.dart', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Read the file and find key markers
    content = ''.join(lines)
    
    # Find and replace production panel (lines ~645-985)
    # Marker: starts with "const SizedBox(height: 16),\n        _Panel(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Text('当前项目概览'"
    # Ends before: "if (publishPanelUi.visible) ...[" 
    
    production_start_marker = "        const SizedBox(height: 16),\n        _Panel(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Text('当前项目概览', style: theme.textTheme.titleSmall),"
    production_end_marker = "        if (publishPanelUi.visible) ...["
    
    production_replacement = """        const SizedBox(height: 16),
        _ProductionPanel(
          spaceOverviewSummary: spaceOverviewSummary,
          overviewMetrics: overviewMetrics,
          qualitySummaryLine: qualitySummaryLine,
          badCaseMetrics: badCaseMetrics,
          recentTaskLines: recentTaskLines,
          assetsOverviewPanelUi: assetsOverviewPanelUi,
          assemblyPanelUi: assemblyPanelUi,
          exportCheckPanelUi: exportCheckPanelUi,
          onOpenProductionForAssemblyExport: onOpenProductionForAssemblyExport,
          onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
          onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
        ),
        if (publishPanelUi.visible) ...["""
    
    start_idx = content.find(production_start_marker)
    end_idx = content.find(production_end_marker, start_idx)
    
    if start_idx != -1 and end_idx != -1:
        content = content[:start_idx] + production_replacement + content[end_idx + len(production_end_marker):]
        print(f"✓ Replaced production panel section")
    else:
        print(f"✗ Could not find production panel section (start={start_idx}, end={end_idx})")
    
    # Find and replace publish panel section
    # This section contains drafts, calendar, jobs, and audit - all inline
    # We need to replace the entire _Panel widget with calls to 4 extracted widgets
    
    publish_start_marker = "        if (publishPanelUi.visible) ...[\n          const SizedBox(height: 16),\n          _Panel(\n            child: Column(\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                Text('发布准备', style: theme.textTheme.titleSmall),"
    publish_end_marker = "        if (candidateCardUi.visible) ...["
    
    publish_replacement = """        _PublishDraftsPanel(publishPanelUi: publishPanelUi),
        _PublishCalendarPanel(publishPanelUi: publishPanelUi),
        _PublishJobsPanel(publishPanelUi: publishPanelUi),
        _PublishAuditPanel(publishPanelUi: publishPanelUi),
        if (candidateCardUi.visible) ...["""
    
    start_idx = content.find(publish_start_marker)
    end_idx = content.find(publish_end_marker, start_idx)
    
    if start_idx != -1 and end_idx != -1:
        content = content[:start_idx] + publish_replacement + content[end_idx + len(publish_end_marker):]
        print(f"✓ Replaced publish panel section")
    else:
        print(f"✗ Could not find publish panel section (start={start_idx}, end={end_idx})")
    
    # Find and replace candidate panels section
    candidate_start_marker = "        if (candidateCardUi.visible) ...[\n          const SizedBox(height: 16),\n          _Panel(\n            child: Column(\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                Text('候选资产确认', style: theme.textTheme.titleSmall),"
    candidate_end_marker = "        const SizedBox(height: 16),\n        _Panel(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Text('模式准备度', style: theme.textTheme.titleSmall),"
    
    candidate_replacement = """        _CandidateComparePanel(
          candidateCardUi: candidateCardUi,
          candidateComparePanelUi: candidateComparePanelUi,
          onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
        ),
        const SizedBox(height: 16),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('模式准备度', style: theme.textTheme.titleSmall),"""
    
    start_idx = content.find(candidate_start_marker)
    end_idx = content.find(candidate_end_marker, start_idx)
    
    if start_idx != -1 and end_idx != -1:
        content = content[:start_idx] + candidate_replacement + content[end_idx + len(candidate_end_marker):]
        print(f"✓ Replaced candidate panels section")
    else:
        print(f"✗ Could not find candidate panels section (start={start_idx}, end={end_idx})")
    
    # Write the refactored content
    with open('frontend/lib/short_video_space/view.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\n✓ Refactoring complete!")
    
    # Count lines
    line_count = len(content.split('\n'))
    print(f"  New line count: {line_count}")

if __name__ == '__main__':
    main()
