import '../shell/navigation_controller.dart';

/// Query key for utility panes on the studio home shell (`/?pane=notifications`).
const String kStudioPaneQueryKey = 'pane';

/// Utility panes shown via top-bar icons (not platform-chain workflow).
const Set<ProductWorkspacePane> kStudioUtilityPanes = <ProductWorkspacePane>{
  ProductWorkspacePane.projects,
  ProductWorkspacePane.notifications,
  ProductWorkspacePane.account,
  ProductWorkspacePane.helpHub,
};

/// Panes whose active state is mirrored in `/?pane=…` (survives route resync).
const Set<ProductWorkspacePane> kStudioPaneUriSyncedPanes =
    <ProductWorkspacePane>{
      ...kStudioUtilityPanes,
      ProductWorkspacePane.scriptWorkspace,
      ProductWorkspacePane.productionWorkspace,
      ProductWorkspacePane.tasks,
      ProductWorkspacePane.jobs,
      ProductWorkspacePane.quality,
      ProductWorkspacePane.shortVideoSpace,
      ProductWorkspacePane.teamWorkspaces,
      ProductWorkspacePane.apiKeys,
      ProductWorkspacePane.contentCompliance,
      ProductWorkspacePane.platformStatus,
      ProductWorkspacePane.platformConfig,
    };

/// Parses the active utility pane from a studio shell URI.
ProductWorkspacePane studioPaneFromUri(Uri uri) {
  final queryPane = uri.queryParameters[kStudioPaneQueryKey]?.trim();
  if (queryPane != null && queryPane.isNotEmpty) {
    return _paneFromWireName(queryPane);
  }
  switch (uri.path) {
    case '/notifications':
      return ProductWorkspacePane.notifications;
    case '/settings':
      return ProductWorkspacePane.account;
    case '/help':
      return ProductWorkspacePane.helpHub;
    default:
      return ProductWorkspacePane.projects;
  }
}

ProductWorkspacePane _paneFromWireName(String wire) {
  switch (wire) {
    case 'notifications':
      return ProductWorkspacePane.notifications;
    case 'settings':
    case 'account':
      return ProductWorkspacePane.account;
    case 'help':
    case 'helpHub':
      return ProductWorkspacePane.helpHub;
    case 'quality':
      return ProductWorkspacePane.quality;
    case 'production':
    case 'productionWorkspace':
      return ProductWorkspacePane.productionWorkspace;
    case 'tasks':
      return ProductWorkspacePane.tasks;
    case 'jobs':
      return ProductWorkspacePane.jobs;
    case 'shortVideo':
    case 'shortVideoSpace':
      return ProductWorkspacePane.shortVideoSpace;
    case 'script':
    case 'scriptWorkspace':
      return ProductWorkspacePane.scriptWorkspace;
    case 'team':
    case 'teamWorkspaces':
      return ProductWorkspacePane.teamWorkspaces;
    case 'apiKeys':
      return ProductWorkspacePane.apiKeys;
    case 'contentCompliance':
      return ProductWorkspacePane.contentCompliance;
    case 'platformStatus':
      return ProductWorkspacePane.platformStatus;
    case 'platformConfig':
      return ProductWorkspacePane.platformConfig;
    case 'projects':
    default:
      return ProductWorkspacePane.projects;
  }
}

String _wireNameForPane(ProductWorkspacePane pane) {
  return switch (pane) {
    ProductWorkspacePane.notifications => 'notifications',
    ProductWorkspacePane.account => 'settings',
    ProductWorkspacePane.helpHub => 'help',
    ProductWorkspacePane.productionWorkspace => 'production',
    ProductWorkspacePane.quality => 'quality',
    ProductWorkspacePane.tasks => 'tasks',
    ProductWorkspacePane.jobs => 'jobs',
    ProductWorkspacePane.shortVideoSpace => 'shortVideo',
    ProductWorkspacePane.scriptWorkspace => 'script',
    ProductWorkspacePane.teamWorkspaces => 'team',
    ProductWorkspacePane.apiKeys => 'apiKeys',
    ProductWorkspacePane.contentCompliance => 'contentCompliance',
    ProductWorkspacePane.platformStatus => 'platformStatus',
    ProductWorkspacePane.platformConfig => 'platformConfig',
    ProductWorkspacePane.projects => 'projects',
    _ => 'projects',
  };
}

/// Canonical location for a utility pane (shareable, single shell).
String studioUriForUtilityPane(ProductWorkspacePane pane) {
  if (pane == ProductWorkspacePane.projects) {
    return '/';
  }
  return '/?$kStudioPaneQueryKey=${_wireNameForPane(pane)}';
}

bool studioUriIsShellHome(Uri uri) {
  if (uri.path != '/' && uri.path.isNotEmpty) {
    return uri.path == '/notifications' ||
        uri.path == '/settings' ||
        uri.path == '/help';
  }
  return uri.path == '/' || uri.path.isEmpty;
}
