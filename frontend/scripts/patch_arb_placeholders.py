#!/usr/bin/env python3
"""Patch placeholder l10n strings in app_en.arb / app_zh.arb."""

import re
from pathlib import Path

EN_FIXES = {
    "adminConsoleFieldAclMode": "ACL mode",
    "adminConsoleFieldArchivedAt": "Archived at",
    "adminConsoleFieldBillingProvider": "Billing provider",
    "adminConsoleFieldCreatedAt": "Created at",
    "adminConsoleFieldCurrentWorkspace": "Current workspace",
    "adminConsoleFieldEditorCount": "Editors",
    "adminConsoleFieldOperationalStatus": "Operational status",
    "adminConsoleFieldOpsNote": "Ops note",
    "adminConsoleFieldOwner": "Owner",
    "adminConsoleFieldProjectArchivedAt": "Project archived at",
    "adminConsoleFieldProjectId": "Project ID",
    "adminConsoleFieldSubscription": "Subscription",
    "adminConsoleFieldUpdatedAt": "Updated at",
    "adminConsoleFieldViewerCount": "Viewers",
    "adminConsoleFieldWorkspace": "Workspace",
    "adminConsoleFieldWorkspaceId": "Workspace ID",
    "agentWorkspaceProductionApplyStage": "Apply stage",
    "agentWorkspaceProductionApplySuggestion": "Apply suggestion",
    "agentWorkspaceProductionArgsHelper": "For non-get_flowData tools, e.g. ids:[1,2] (JSON)",
    "agentWorkspaceProductionArgsLabel": "Tool arguments (JSON)",
    "agentWorkspaceProductionArgumentTemplates": "Argument templates",
    "agentWorkspaceProductionContextDerivedRewrite": "Production execution hints derived from scriptPlan",
    "agentWorkspaceProductionContextDerivedRewriteSubtitle": "Production execution hints derived from scriptPlan",
    "agentWorkspaceProductionContextReturnList": "From {toolName}",
    "agentWorkspaceProductionContextReviewSummary": "From {toolName}",
    "agentWorkspaceProductionContextSnapshotTitle": "Context snapshot",
    "agentWorkspaceProductionContextToolText": "Tool text output",
    "agentWorkspaceProductionCurrentCandidateArgs": "Current result candidate args",
    "agentWorkspaceProductionDiagnosisTitle": "Next-step suggestions",
    "agentWorkspaceProductionDomainToolLabel": "Production domain tool",
    "agentWorkspaceProductionFlowKeyHelper": "Used as get_flowData key and writeback key",
    "agentWorkspaceProductionFlowKeyLabel": "Flow key",
    "agentWorkspaceProductionIdleHint": "Waiting to run — use guided tasks or form actions.",
    "agentWorkspaceProductionModeTextOnly": "Result: frames present",
    "agentWorkspaceProductionPromptExecutionOrder": "Order: confirm director-plan assets, then storyboard table and shots.",
    "agentWorkspaceProductionPromptFlowDown": "Order: confirm director-plan assets, then storyboard table and shots.",
    "agentWorkspaceProductionPromptHelper": "Prompt for production harness.agent.run",
    "agentWorkspaceProductionPromptLabel": "Production prompt",
    "agentWorkspaceProductionPromptPreviewTitle": "Execution prompt",
    "agentWorkspaceProductionReadTool": "Read production tool",
    "agentWorkspaceProductionResultHasImage": "Result: missing frames",
    "agentWorkspaceProductionResultSummary": "Result summary",
    "agentWorkspaceProductionRunSubAgent": "Run sub-agent",
    "agentWorkspaceProductionRunWorkflow": "Run production workflow",
    "agentWorkspaceProductionStagesTitle": "Execution stages",
    "agentWorkspaceProductionStepPullAssetsFlow": "1) Pull assets flow",
    "agentWorkspaceProductionStepPullStoryboardFlow": "3) Pull storyboard flow",
    "agentWorkspaceProductionStepRunAssetsSubAgent": "2) Run assets sub-agent",
    "agentWorkspaceProductionStepRunDirectorPlanSubAgent": "6) Run director-plan sub-agent",
    "agentWorkspaceProductionStepRunStoryboardSubAgent": "5) Run storyboard sub-agent",
    "agentWorkspaceProductionStepWritebackFlow": "4) Write back flow",
    "agentWorkspaceProductionSubAgentArgsHelper": "e.g. storyboardIds:[1,2], assetIds:[7,12] (JSON)",
    "agentWorkspaceProductionSubAgentArgsLabel": "Sub-agent arguments (JSON)",
    "agentWorkspaceProductionSubAgentToolLabel": "Production sub-agent tool",
    "agentWorkspaceProductionSummaryFlowEmpty": "Current flow is empty",
    "agentWorkspaceProductionSummaryFlowEmptyString": "Current flow is an empty string",
    "agentWorkspaceProductionUseSuggestedFlowKey": "Use this key",
    "agentWorkspaceProductionWritebackStrategy": "Writeback keys: get_flowData writes directly; asset/storyboard/director-plan tools refresh the matching flow key first.",
    "agentWorkspaceProductionWritebackToolResult": "Write back tool result",
    "agentWorkspaceScriptAdvanceStage": "Advance stage",
    "agentWorkspaceScriptApplyStage": "Apply stage",
    "agentWorkspaceScriptApplySuggestion": "Apply suggestion",
    "agentWorkspaceScriptArgsHelper": "Prefer the latest chapter result for novelId; leave blank if unsure.",
    "agentWorkspaceScriptArgsLabel": "Tool arguments",
    "agentWorkspaceScriptContextAdaptationStrategy": "From get_planData",
    "agentWorkspaceScriptContextCurrentScriptBody": "From get_script_content",
    "agentWorkspaceScriptContextDialogueConstraint": "Dialogue: avoid exposition; favor spoken conflict and emotional beats.",
    "agentWorkspaceScriptContextExecutionOrder": "Dialogue: avoid exposition; favor spoken conflict and emotional beats.",
    "agentWorkspaceScriptContextFromPlanData": "From get_planData",
    "agentWorkspaceScriptContextFromScriptContent": "From get_script_content",
    "agentWorkspaceScriptContextNoBody": "No body",
    "agentWorkspaceScriptContextNovelChapters": "From get_novel_text (first 4 shown)",
    "agentWorkspaceScriptContextNovelChaptersSubtitle": "From get_novel_text (first 4 shown)",
    "agentWorkspaceScriptContextNovelEvents": "From get_novel_events (first 6 shown)",
    "agentWorkspaceScriptContextNovelEventsSubtitle": "From get_novel_events (first 6 shown)",
    "agentWorkspaceScriptContextPlanDrafts": "Up to 4 script rows shown",
    "agentWorkspaceScriptContextPlanDraftsSubtitle": "Up to 4 script rows shown",
    "agentWorkspaceScriptContextRewriteConstraints": "Downstream hints derived from get_planData",
    "agentWorkspaceScriptContextRewriteConstraintsSubtitle": "Downstream hints derived from get_planData",
    "agentWorkspaceScriptContextSnapshotTitle": "Context snapshot",
    "agentWorkspaceScriptContextStorySkeleton": "From get_planData",
    "agentWorkspaceScriptContextUntitledChapter": "Chapter",
    "agentWorkspaceScriptContextUntitledEvent": "Untitled event",
    "agentWorkspaceScriptContextUntitledScript": "Untitled script",
    "agentWorkspaceScriptDiagnosisTitle": "Next-step suggestions",
    "agentWorkspaceScriptDomainToolLabel": "Script domain tool",
    "agentWorkspaceScriptLatestAssistantResult": "Latest assistant result",
    "agentWorkspaceScriptPromptHelper": "Prompt for script harness.agent.run",
    "agentWorkspaceScriptPromptLabel": "Script prompt",
    "agentWorkspaceScriptReadContext": "Read script context",
    "agentWorkspaceScriptRunSubAgent": "Run sub-agent",
    "agentWorkspaceScriptRunWorkflow": "Run script workflow",
    "agentWorkspaceScriptStagesTitle": "Execution stages",
    "agentWorkspaceScriptStepFetchContent": "2) Fetch script body",
    "agentWorkspaceScriptStepFetchPlanData": "1) Fetch planData",
    "agentWorkspaceScriptStepGenerateDraft": "3) Generate script draft",
    "agentWorkspaceScriptStepWriteback": "4) Write back script",
    "agentWorkspaceScriptSubAgentToolLabel": "Script sub-agent tool",
    "agentWorkspaceScriptSummaryAdaptationReady": "Adaptation strategy ready",
    "agentWorkspaceScriptSummaryPlanDataMissing": "planData missing data",
    "agentWorkspaceScriptSummaryPlanDataReturned": "planData returned",
    "agentWorkspaceScriptSummaryReviewReturned": "Review result returned",
    "agentWorkspaceScriptSummaryRewriteReady": "Rewrite constraints ready for downstream use",
    "agentWorkspaceScriptSummaryStorySkeletonReady": "Story skeleton ready",
    "agentWorkspaceScriptWritebackPlanData": "Write back plan data",
    "agentWorkspaceScriptWritebackUpdateData": "Write back update-data",
    "platformConfigToggleWorkspaceActivitySubtitle": "Show the Agent workspace Activity nav entry",
}

ZH_ADMIN_FIXES = {
    "adminConsoleFieldAclMode": "ACL 模式",
    "adminConsoleFieldArchivedAt": "归档时间",
    "adminConsoleFieldBillingProvider": "计费提供商",
    "adminConsoleFieldCreatedAt": "创建时间",
    "adminConsoleFieldCurrentWorkspace": "当前工作区",
    "adminConsoleFieldEditorCount": "编辑者数",
    "adminConsoleFieldOperationalStatus": "运营状态",
    "adminConsoleFieldOpsNote": "运维备注",
    "adminConsoleFieldOwner": "所有者",
    "adminConsoleFieldProjectArchivedAt": "项目归档时间",
    "adminConsoleFieldProjectId": "项目 ID",
    "adminConsoleFieldSubscription": "订阅",
    "adminConsoleFieldUpdatedAt": "更新时间",
    "adminConsoleFieldViewerCount": "查看者数",
    "adminConsoleFieldWorkspace": "工作区",
    "adminConsoleFieldWorkspaceId": "工作区 ID",
}


def apply_fixes(path: Path, fixes: dict[str, str]) -> int:
    text = path.read_text(encoding="utf-8")
    n = 0
    for key, val in fixes.items():
        esc = val.replace("\\", "\\\\").replace('"', '\\"')
        pat = rf'("{re.escape(key)}"\s*:\s*")([^"]*)(")'
        def repl(m: re.Match[str], *, _esc: str = esc) -> str:
            return f"{m.group(1)}{_esc}{m.group(3)}"

        new_text, c = re.subn(pat, repl, text, count=1)
        if c:
            text = new_text
            n += 1
    path.write_text(text, encoding="utf-8")
    return n


def main() -> None:
    root = Path(__file__).resolve().parents[1] / "lib" / "l10n"
    n_en = apply_fixes(root / "app_en.arb", EN_FIXES)
    n_zh = apply_fixes(root / "app_zh.arb", ZH_ADMIN_FIXES)
    print(f"patched en={n_en} zh_admin={n_zh}")


if __name__ == "__main__":
    main()
