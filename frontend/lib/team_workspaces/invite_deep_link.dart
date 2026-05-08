const String kWorkspaceInviteDeepLinkPath = '/join-workspace';

class WorkspaceInvitePrefill {
  const WorkspaceInvitePrefill({
    required this.token,
    required this.tokenFromUri,
    required this.shouldAutoOpenTeamWorkspace,
  });

  final String? token;
  final bool tokenFromUri;
  final bool shouldAutoOpenTeamWorkspace;
}

String? extractWorkspaceInviteTokenFromQuery(Uri uri) {
  final candidates = <String?>[
    uri.queryParameters['invite_token'],
    uri.queryParameters['inviteToken'],
    uri.queryParameters['token'],
  ];
  for (final value in candidates) {
    final token = value?.trim();
    if (token != null && token.isNotEmpty) {
      return token;
    }
  }
  return null;
}

String? extractWorkspaceInviteTokenFromPath(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2 || segments.first != 'join-workspace') {
    return null;
  }
  final token = segments[1].trim();
  if (token.isEmpty) {
    return null;
  }
  return token;
}

bool isWorkspaceInviteDeepLinkRoute(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  return segments.isNotEmpty && segments.first == 'join-workspace';
}

WorkspaceInvitePrefill resolveWorkspaceInvitePrefill({
  required String? initialInviteToken,
  required Uri uriBase,
}) {
  final manual = initialInviteToken?.trim();
  if (manual != null && manual.isNotEmpty) {
    return WorkspaceInvitePrefill(
      token: manual,
      tokenFromUri: false,
      shouldAutoOpenTeamWorkspace: false,
    );
  }

  final tokenFromPath = extractWorkspaceInviteTokenFromPath(uriBase);
  final tokenFromQuery = extractWorkspaceInviteTokenFromQuery(uriBase);
  final token = tokenFromPath ?? tokenFromQuery;
  return WorkspaceInvitePrefill(
    token: token,
    tokenFromUri: token != null,
    shouldAutoOpenTeamWorkspace:
        isWorkspaceInviteDeepLinkRoute(uriBase) || tokenFromQuery != null,
  );
}

Uri removeWorkspaceInviteTokenFromUri(Uri uri) {
  final qp = Map<String, String>.from(uri.queryParameters);
  qp.remove('invite_token');
  qp.remove('inviteToken');
  qp.remove('token');
  final cleaned = uri.replace(queryParameters: qp.isEmpty ? null : qp);
  if (!isWorkspaceInviteDeepLinkRoute(uri)) {
    return cleaned;
  }
  return cleaned.replace(path: '/', queryParameters: qp.isEmpty ? null : qp);
}

bool shouldShowInviteTokenHint({
  required bool tokenAutoFilledFromUri,
  required String tokenText,
}) {
  return tokenAutoFilledFromUri && tokenText.trim().isNotEmpty;
}
