#!/usr/bin/env python3
"""
Refactor view.dart to use extracted widget components.
Replaces inline widget code with calls to extracted widgets.
"""

import re

def refactor_view_dart():
    with open('frontend/lib/short_video_space/view.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace the production panel section (current project overview + assets + assembly + export check)
    # Find the start: "const SizedBox(height: 16),\n        _Panel(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,\n            children: [\n              Text('当前项目概览'"
    # Find the end: just before "if (publishPanelUi.visible) ...[" 
    
    production_panel_pattern = r"(        const SizedBox\(height: 16\),\n        _Panel\(\n          child: Column\(\n            crossAxisAlignment: CrossAxisAlignment\.start,\n            children: \[\n              Text\('当前项目概览'.*?)\n        if \(publishPanelUi\.visible\)"
    
    production_panel_replacement = r"""        const SizedBox(height: 16),
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
        if (publishPanelUi.visible)"""
    
    content = re.sub(production_panel_pattern, production_panel_replacement, content, flags=re.DOTALL)
    
    # Replace the publish panel section (drafts + calendar + jobs + audit)
    # This is complex, so let's do it in parts
    
    # First, replace the main publish drafts panel
    publish_drafts_pattern = r"(        if \(publishPanelUi\.visible\) \.\.\.\[\n          const SizedBox\(height: 16\),\n          _Panel\(\n            child: Column\(\n              crossAxisAlignment: CrossAxisAlignment\.start,\n              children: \[\n                Text\('发布准备'.*?)\n                const SizedBox\(height: 8\),\n                Text\(\n                  publishPanelUi\.detail,\n                  style: theme\.textTheme\.bodySmall\?\.copyWith\(color: outline\),\n                \),\n              \],\n            \),\n          \),\n        \],"
    
    publish_drafts_replacement = r"""        _PublishDraftsPanel(publishPanelUi: publishPanelUi),
        _PublishCalendarPanel(publishPanelUi: publishPanelUi),
        _PublishJobsPanel(publishPanelUi: publishPanelUi),
        _PublishAuditPanel(publishPanelUi: publishPanelUi),"""
    
    content = re.sub(publish_drafts_pattern, publish_drafts_replacement, content, flags=re.DOTALL)
    
    # Replace candidate panels
    candidate_pattern = r"(        if \(candidateCardUi\.visible\) \.\.\.\[.*?if \(candidateComparePanelUi\.visible\) \.\.\.\[.*?\],\n        \],)"
    
    candidate_replacement = r"""        _CandidateComparePanel(
          candidateCardUi: candidateCardUi,
          candidateComparePanelUi: candidateComparePanelUi,
          onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
        ),"""
    
    content = re.sub(candidate_pattern, candidate_replacement, content, flags=re.DOTALL)
    
    with open('frontend/lib/short_video_space/view.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Refactoring complete!")

if __name__ == '__main__':
    refactor_view_dart()
