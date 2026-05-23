// Cross-panel snapshot versioning support (K.4)
//
// Tracks data versions for each panel to detect inconsistencies and alert
// users when panels are viewing different versions of the same data.

import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../design_system/studio_typography.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Localized display name for a tracked panel key (e.g. `production`, `export`).
String shortVideoPanelVersionPanelTitle(AppLocalizations l10n, String panel) {
  switch (panel) {
    case 'production':
      return l10n.shortVideoPanelVersionPanelProduction;
    case 'assets':
      return l10n.shortVideoPanelVersionPanelAssets;
    case 'assembly':
      return l10n.shortVideoPanelVersionPanelAssembly;
    case 'export':
      return l10n.shortVideoPanelVersionPanelExport;
    default:
      return panel;
  }
}

/// Snapshot of a panel's data version and load time
class PanelSnapshot {
  final String? dataVersion;
  final DateTime loadedAt;

  PanelSnapshot({required this.dataVersion, required this.loadedAt});

  /// Age of this snapshot in seconds
  int get ageSeconds => DateTime.now().difference(loadedAt).inSeconds;

  /// Whether this snapshot has a valid version
  bool get hasVersion => dataVersion != null && dataVersion!.isNotEmpty;
}

/// Result of cross-panel consistency check
class ConsistencyStatus {
  final bool consistent;
  final String? latestPanel;
  final String? latestVersion;
  final List<StalePanelInfo> stalePanels;

  ConsistencyStatus({
    required this.consistent,
    this.latestPanel,
    this.latestVersion,
    this.stalePanels = const [],
  });

  factory ConsistencyStatus.consistent() {
    return ConsistencyStatus(consistent: true);
  }

  factory ConsistencyStatus.inconsistent({
    required String latestPanel,
    required String latestVersion,
    required List<StalePanelInfo> stalePanels,
  }) {
    return ConsistencyStatus(
      consistent: false,
      latestPanel: latestPanel,
      latestVersion: latestVersion,
      stalePanels: stalePanels,
    );
  }
}

/// Information about a stale panel
class StalePanelInfo {
  final String panel;
  final String version;
  final int ageSeconds;

  StalePanelInfo({
    required this.panel,
    required this.version,
    required this.ageSeconds,
  });
}

/// Manager for cross-panel version tracking
class PanelVersionManager {
  final Map<String, PanelSnapshot> _snapshots = {};

  /// Update the version for a specific panel
  void updateVersion(String panel, String? dataVersion) {
    _snapshots[panel] = PanelSnapshot(
      dataVersion: dataVersion,
      loadedAt: DateTime.now(),
    );
  }

  /// Get the snapshot for a specific panel
  PanelSnapshot? getSnapshot(String panel) {
    return _snapshots[panel];
  }

  /// Clear all snapshots
  void clear() {
    _snapshots.clear();
  }

  /// Clear snapshot for a specific panel
  void clearPanel(String panel) {
    _snapshots.remove(panel);
  }

  /// Check consistency across all panels
  ConsistencyStatus checkConsistency() {
    final versioned = _snapshots.entries
        .where((e) => e.value.hasVersion)
        .map((e) => MapEntry(e.key, e.value))
        .toList();

    if (versioned.length < 2) {
      return ConsistencyStatus.consistent();
    }

    // Find latest version
    String? latestPanel;
    String? latestVersion;
    DateTime? latestTime;

    for (final entry in versioned) {
      final version = entry.value.dataVersion!;
      if (latestVersion == null || version.compareTo(latestVersion) > 0) {
        latestPanel = entry.key;
        latestVersion = version;
        latestTime = _parseVersion(version);
      }
    }

    if (latestVersion == null || latestTime == null) {
      return ConsistencyStatus.consistent();
    }

    // Find stale panels
    final stalePanels = <StalePanelInfo>[];
    for (final entry in versioned) {
      final version = entry.value.dataVersion!;
      if (version.compareTo(latestVersion) < 0) {
        final versionTime = _parseVersion(version);
        final ageSeconds = versionTime != null
            ? latestTime.difference(versionTime).inSeconds
            : 0;
        stalePanels.add(
          StalePanelInfo(
            panel: entry.key,
            version: version,
            ageSeconds: ageSeconds,
          ),
        );
      }
    }

    if (stalePanels.isEmpty) {
      return ConsistencyStatus.consistent();
    }

    return ConsistencyStatus.inconsistent(
      latestPanel: latestPanel!,
      latestVersion: latestVersion,
      stalePanels: stalePanels,
    );
  }

  /// Parse ISO 8601 timestamp from version string
  DateTime? _parseVersion(String version) {
    try {
      // Handle format: "2025-01-15 10:30:45.123456+00"
      // Convert to ISO 8601: "2025-01-15T10:30:45.123456+00:00"
      final normalized = version
          .replaceFirst(' ', 'T')
          .replaceFirst('+00', '+00:00');
      return DateTime.parse(normalized);
    } catch (e) {
      return null;
    }
  }

  /// Get human-readable age string (localized).
  static String formatAge(int seconds, AppLocalizations l10n) {
    if (seconds < 60) {
      return l10n.shortVideoPanelVersionAgeSeconds(seconds);
    }
    if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return l10n.shortVideoPanelVersionAgeMinutes(minutes);
    }
    final hours = seconds ~/ 3600;
    return l10n.shortVideoPanelVersionAgeHours(hours);
  }

  /// Get severity level based on age
  static StaleSeverity getSeverity(int ageSeconds) {
    if (ageSeconds < 30) {
      return StaleSeverity.info;
    } else if (ageSeconds < 300) {
      return StaleSeverity.warning;
    } else {
      return StaleSeverity.error;
    }
  }
}

/// Severity level for stale data
enum StaleSeverity { info, warning, error }

/// Widget to display consistency alert
class PanelConsistencyAlert extends StatelessWidget {
  final ConsistencyStatus status;
  final VoidCallback onRefresh;

  const PanelConsistencyAlert({
    super.key,
    required this.status,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (status.consistent) {
      return const SizedBox.shrink();
    }

    final l10n = resolveAppLocalizationsForErrors(context);
    final maxAge = status.stalePanels
        .map((p) => p.ageSeconds)
        .reduce((a, b) => a > b ? a : b);
    final severity = PanelVersionManager.getSeverity(maxAge);

    Color backgroundColor;
    Color textColor;
    IconData icon;

    final tokens = StudioTokens.of(context);
    switch (severity) {
      case StaleSeverity.info:
        backgroundColor = tokens.signal.withValues(alpha: 0.14);
        textColor = tokens.signal;
        icon = Icons.info_outline;
        break;
      case StaleSeverity.warning:
        backgroundColor = tokens.warning.withValues(alpha: 0.14);
        textColor = tokens.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case StaleSeverity.error:
        backgroundColor = tokens.danger.withValues(alpha: 0.14);
        textColor = tokens.danger;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.all(StudioSpacing.xs),
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoPanelVersionDataInconsistencyTitle,
                  style: studioAccentBannerTitleStyle(context, textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.shortVideoPanelVersionStaleSummary(
                    status.stalePanels.length,
                  ),
                  style: studioAccentBannerBodyStyle(context, textColor),
                ),
                if (status.stalePanels.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...status.stalePanels.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text(
                        l10n.shortVideoPanelVersionStaleRow(
                          shortVideoPanelVersionPanelTitle(l10n, p.panel),
                          PanelVersionManager.formatAge(p.ageSeconds, l10n),
                        ),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: StudioTypography.of(context).meta,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(l10n.shortVideoPanelVersionRefresh),
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor,
              foregroundColor: backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: studioAccentBannerBodyStyle(context, textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mixin to add panel versioning support to a state
mixin PanelVersioningMixin<T extends StatefulWidget> on State<T> {
  final PanelVersionManager _versionManager = PanelVersionManager();

  PanelVersionManager get versionManager => _versionManager;

  /// Update version for a panel
  void updatePanelVersion(String panel, String? dataVersion) {
    _versionManager.updateVersion(panel, dataVersion);
  }

  /// Check consistency and optionally show alert
  ConsistencyStatus checkPanelConsistency() {
    return _versionManager.checkConsistency();
  }

  /// Clear all panel versions
  void clearPanelVersions() {
    _versionManager.clear();
  }

  @override
  void dispose() {
    _versionManager.clear();
    super.dispose();
  }
}
