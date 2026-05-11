import '../l10n/app_localizations.dart';
import '../rust_api.dart';

const String kInviteTokenAutofillHint = '已从链接自动填入邀请 token，可直接点击“接受邀请”。';
const String kOnlyPersonalWorkspaceTitle = '当前只有 Personal 工作区';
const String kOnlyPersonalWorkspaceBody =
    '若要开始团队协作，可先创建一个 enterprise 空间，再去成员管理里发邀请。创建后就能把项目、任务和 Agent 上下文切到同一个团队范围。';

String buildEnterpriseProjectsEmptyStateBody(
  AppLocalizations l10n,
  String? workspaceName,
) {
  final trimmedName = workspaceName?.trim();
  final displayName = trimmedName != null && trimmedName.isNotEmpty
      ? trimmedName
      : l10n.projectsEnterpriseEmptyUnnamedFallback;
  return l10n.projectsEnterpriseEmptyBody(displayName);
}

String buildWorkspaceRowSemanticsLabel(
  WorkspaceListItem row, {
  required bool isCurrent,
}) {
  final archivedText = row.workspace.archivedAt != null ? '，已归档' : '';
  final currentText = isCurrent ? '，当前工作区' : '';
  return '${row.workspace.name}，${row.workspace.workspaceType} 空间，你的角色是 ${row.role}$archivedText$currentText';
}

String buildWorkspaceActionTooltip({
  required String actionLabel,
  required String workspaceName,
}) {
  return '$actionLabel $workspaceName';
}
