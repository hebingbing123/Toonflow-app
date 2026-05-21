part of '../../home_page.dart';

class _ProductPaneSelector extends StatefulWidget {
  const _ProductPaneSelector({
    required this.config,
    required this.unreadNotifications,
    required this.selectedPane,
    required this.onSelectPane,
  });

  final PlatformConfigToggleSetV1 config;
  final int unreadNotifications;
  final ProductWorkspacePane selectedPane;
  final ValueChanged<ProductWorkspacePane> onSelectPane;

  @override
  State<_ProductPaneSelector> createState() => _ProductPaneSelectorState();
}

class _ProductPaneSelectorState extends State<_ProductPaneSelector> {
  bool _isPaneEnabled(ProductWorkspacePane pane) {
    switch (pane) {
      case ProductWorkspacePane.helpHub:
        return widget.config.helpHubEnabled;
      case ProductWorkspacePane.platformStatus:
        return widget.config.platformStatusEnabled;
      case ProductWorkspacePane.workspaceActivity:
        return widget.config.workspaceActivityEnabled;
      case ProductWorkspacePane.benchmark:
        return widget.config.benchmarkPaneEnabled;
      case ProductWorkspacePane.jobs:
        return widget.config.jobsPaneEnabled;
      case ProductWorkspacePane.quality:
        return widget.config.qualityDashboardEnabled;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final paneEntries = <(ProductWorkspacePane, String, int?)>[
      (
        ProductWorkspacePane.shortVideoSpace,
        l10n.productNavShortVideoSpace,
        null,
      ),
      (ProductWorkspacePane.projects, l10n.productNavProjects, null),
      (ProductWorkspacePane.account, l10n.productNavAccount, null),
      (ProductWorkspacePane.apiKeys, l10n.productNavApiKeys, null),
      (
        ProductWorkspacePane.notifications,
        l10n.productNavNotifications,
        widget.unreadNotifications,
      ),
      (
        ProductWorkspacePane.contentCompliance,
        l10n.productNavContentCompliance,
        null,
      ),
      (
        ProductWorkspacePane.platformStatus,
        l10n.productNavPlatformStatus,
        null,
      ),
      (
        ProductWorkspacePane.teamWorkspaces,
        l10n.productNavTeamWorkspaces,
        null,
      ),
      (
        ProductWorkspacePane.scriptWorkspace,
        l10n.productNavScriptWorkspace,
        null,
      ),
      (
        ProductWorkspacePane.productionWorkspace,
        l10n.productNavProductionWorkspace,
        null,
      ),
      (
        ProductWorkspacePane.workspaceActivity,
        l10n.productNavWorkspaceActivity,
        null,
      ),
      (ProductWorkspacePane.benchmark, l10n.productNavBenchmark, null),
      (ProductWorkspacePane.tasks, l10n.productNavTasks, null),
      (ProductWorkspacePane.jobs, l10n.productNavJobs, null),
      (ProductWorkspacePane.quality, l10n.productNavQuality, null),
      (
        ProductWorkspacePane.platformConfig,
        l10n.productNavPlatformConfig,
        null,
      ),
      (ProductWorkspacePane.helpHub, l10n.productNavHelp, null),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.productNavSectionTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: paneEntries
                .map((entry) {
                  final pane = entry.$1;
                  final enabled = _isPaneEnabled(pane);
                  final unread = entry.$3;
                  return ChoiceChip(
                    label: Text(
                      unread != null && unread > 0
                          ? '${entry.$2} ($unread)'
                          : entry.$2,
                    ),
                    selected: widget.selectedPane == pane,
                    onSelected: enabled
                        ? (selected) {
                            if (!selected) {
                              return;
                            }
                            widget.onSelectPane(pane);
                          }
                        : null,
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          PlatformShortDramaPipelineStrip(
            onSelectPane: widget.onSelectPane,
            jobsPaneEnabled: widget.config.jobsPaneEnabled,
            qualityPaneEnabled: widget.config.qualityDashboardEnabled,
          ),
        ],
      ),
    );
  }
}

class _PlatformPaneDisabledNotice extends StatelessWidget {
  const _PlatformPaneDisabledNotice({
    required this.title,
    required this.reason,
  });

  final String title;
  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
            decoration: studioRecessedPanelDecoration(context),
            child: Text(reason, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
