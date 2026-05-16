import '../l10n/app_localizations.dart';
import '../rust_api.dart';

String inviteTokenAutofillHint(AppLocalizations l10n) =>
    l10n.teamWorkspaceInviteTokenAutofillHint;

String onlyPersonalWorkspaceTitle(AppLocalizations l10n) =>
    l10n.teamWorkspaceOnlyPersonalTitle;

String onlyPersonalWorkspaceBody(AppLocalizations l10n) =>
    l10n.teamWorkspaceOnlyPersonalBody;

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
  AppLocalizations l10n,
  WorkspaceListItem row, {
  required bool isCurrent,
}) {
  final archived = row.workspace.archivedAt != null;
  return l10n.teamWorkspaceRowSemantics(
    row.workspace.name,
    row.workspace.workspaceType,
    row.role,
    archived ? l10n.teamWorkspaceArchivedFlag : '',
    isCurrent ? l10n.teamWorkspaceCurrentFlag : '',
  );
}

String buildWorkspaceActionTooltip({
  required AppLocalizations l10n,
  required String actionLabel,
  required String workspaceName,
}) {
  return l10n.teamWorkspaceActionTooltip(actionLabel, workspaceName);
}
