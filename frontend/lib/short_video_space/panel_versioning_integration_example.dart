// ignore_for_file: unused_element, unused_field

// Example integration of cross-panel versioning in short_video_space
//
// This file demonstrates how to integrate the panel versioning system
// into the existing ShortVideoSpaceSection. This is a reference implementation
// that should be adapted to the actual codebase.
//
// NOTE: This file is for documentation purposes only and will have compile
// errors until the Dart types are regenerated from the updated Rust API.
// The actual integration should be done in the main section.dart file.

import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'panel_versioning.dart';
import '../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

/// Example of how to integrate panel versioning into the state
class _ShortVideoSpaceSectionStateWithVersioning extends State<StatefulWidget>
    with PanelVersioningMixin {
  // Existing state fields...
  bool _loadingProjectOverview = false;
  ProjectProductionOverview? _productionOverview;
  ProjectAssetsOverview? _projectAssetsOverview;
  ProjectShortVideoAssembly? _shortVideoAssembly;
  ProjectShortVideoExportCheck? _shortVideoExportCheck;

  // Add consistency status tracking
  ConsistencyStatus _consistencyStatus = ConsistencyStatus.consistent();

  @override
  void initState() {
    super.initState();
    // Existing initialization...
  }

  /// Modified loadProjectOverview to track versions
  Future<void> _loadProjectOverview() async {
    final token = 'example-token'; // Get from widget
    final projectId = 'example-project-id'; // Get from state

    setState(() {
      _loadingProjectOverview = true;
    });

    try {
      // Load production overview
      final productionOverview =
          await fetchProjectProductionOverviewByProjectId(token, projectId);
      updatePanelVersion('production', 'v${productionOverview.schemaVersion}');

      // Load assets overview
      final assetsOverview = await fetchProjectAssetsOverviewByProjectId(
        token,
        projectId,
      );
      updatePanelVersion('assets', 'v${assetsOverview.schemaVersion}');

      // Load assembly
      final assembly = await fetchProjectShortVideoAssemblyByProjectId(
        token,
        projectId,
      );
      updatePanelVersion('assembly', 'v${assembly.schemaVersion}');

      // Load export check
      final exportCheck = await fetchProjectShortVideoExportCheckByProjectId(
        token,
        projectId,
      );
      updatePanelVersion(
        'export',
        exportCheck.dataVersion ?? 'v${exportCheck.schemaVersion}',
      );

      // Check consistency after loading all panels
      final status = checkPanelConsistency();

      if (mounted) {
        setState(() {
          _productionOverview = productionOverview;
          _projectAssetsOverview = assetsOverview;
          _shortVideoAssembly = assembly;
          _shortVideoExportCheck = exportCheck;
          _consistencyStatus = status;
        });
      }
    } catch (e) {
      // Handle error...
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjectOverview = false;
        });
      }
    }
  }

  /// Refresh all panels
  Future<void> _refreshAllPanels() async {
    clearPanelVersions();
    await _loadProjectOverview();
  }

  /// Check consistency before critical operation
  Future<bool> _checkConsistencyBeforeOperation(BuildContext context) async {
    final status = checkPanelConsistency();

    if (!status.consistent) {
      final result = await showStudioDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = resolveAppLocalizationsForErrors(dialogContext);
          return StudioAlertDialog(
            title: Text(l10n.shortVideoPanelVersionDataInconsistencyTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shortVideoPanelVersionStaleDialogBody),
                const SizedBox(height: 16),
                ...status.stalePanels.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      l10n.shortVideoPanelVersionStaleRow(
                        shortVideoPanelVersionPanelTitle(l10n, p.panel),
                        PanelVersionManager.formatAge(p.ageSeconds, l10n),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.taskCenterCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.shortVideoPanelVersionRefreshAndContinue),
              ),
            ],
          );
        },
      );

      if (result == true) {
        await _refreshAllPanels();
        return true;
      }
      return false;
    }

    return true;
  }

  /// Example critical operation with consistency check
  Future<void> _performPublishOperation(BuildContext context) async {
    // Check consistency before publishing
    final canProceed = await _checkConsistencyBeforeOperation(context);
    if (!canProceed) {
      return;
    }

    // Proceed with publish operation...
    // await publishDraft(...);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show consistency alert if data is inconsistent
        PanelConsistencyAlert(
          status: _consistencyStatus,
          onRefresh: _refreshAllPanels,
        ),

        // Existing UI components...
        // Production overview panel
        // Assets overview panel
        // Assembly panel
        // Export check panel
        // Publish panel with consistency check before operations

        // Example: Publish button with consistency check
        ElevatedButton(
          onPressed: () => _performPublishOperation(context),
          child: Text(
            resolveAppLocalizationsForErrors(context).shortVideoPanelVersionExamplePublish,
          ),
        ),
      ],
    );
  }
}

/// Example of how to display panel freshness indicators
class PanelFreshnessIndicator extends StatelessWidget {
  final String panelName;
  final PanelSnapshot? snapshot;

  const PanelFreshnessIndicator({
    super.key,
    required this.panelName,
    required this.snapshot,
  });

  @override
  Widget build(BuildContext context) {
    final snap = snapshot;
    if (snap == null || !snap.hasVersion) {
      return const SizedBox.shrink();
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final age = snap.ageSeconds;
    final severity = PanelVersionManager.getSeverity(age);

    Color color;
    IconData icon;

    final tokens = StudioTokens.of(context);
    switch (severity) {
      case StaleSeverity.info:
        color = tokens.signal;
        icon = Icons.check_circle_outline;
        break;
      case StaleSeverity.warning:
        color = tokens.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case StaleSeverity.error:
        color = tokens.danger;
        icon = Icons.error_outline;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          PanelVersionManager.formatAge(age, l10n),
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Example of panel header with refresh button and freshness indicator
class PanelHeader extends StatelessWidget {
  final String title;
  final PanelSnapshot? snapshot;
  final VoidCallback onRefresh;

  const PanelHeader({
    super.key,
    required this.title,
    required this.snapshot,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        PanelFreshnessIndicator(panelName: title, snapshot: snapshot),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          tooltip: l10n.shortVideoPanelVersionRefreshPanelTooltip,
        ),
      ],
    );
  }
}
