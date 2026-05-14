import 'package:flutter/material.dart';

import '../rust_api.dart';

class OverviewSectionViewModel {
  const OverviewSectionViewModel({
    required this.apiBaseUrl,
    required this.loadingHealth,
    required this.loadingHealthRoot,
    required this.loadingPing,
    required this.loadingVersion,
    required this.loadingReady,
    required this.healthBody,
    required this.healthRootBody,
    required this.pingBody,
    required this.versionBody,
    required this.readyBody,
  });

  final String apiBaseUrl;
  final bool loadingHealth;
  final bool loadingHealthRoot;
  final bool loadingPing;
  final bool loadingVersion;
  final bool loadingReady;
  final String? healthBody;
  final String? healthRootBody;
  final String? pingBody;
  final String? versionBody;
  final String? readyBody;
}

class OverviewSectionViewCallbacks {
  const OverviewSectionViewCallbacks({
    required this.onPingHealth,
    required this.onPingHealthRoot,
    required this.onPingPing,
    required this.onPingVersion,
    required this.onPingReady,
  });

  final VoidCallback? onPingHealth;
  final VoidCallback? onPingHealthRoot;
  final VoidCallback? onPingPing;
  final VoidCallback? onPingVersion;
  final VoidCallback? onPingReady;
}

class OverviewSectionView extends StatelessWidget {
  const OverviewSectionView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final OverviewSectionViewModel model;
  final OverviewSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final busy = l10n.workspaceDebugOverviewProbeBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.workspaceDebugOverviewApiBase(model.apiBaseUrl),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: model.loadingHealth ? null : callbacks.onPingHealth,
              child: Text(
                model.loadingHealth
                    ? busy
                    : l10n.workspaceDebugOverviewButtonHealthV1,
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingHealthRoot
                  ? null
                  : callbacks.onPingHealthRoot,
              child: Text(
                model.loadingHealthRoot
                    ? busy
                    : l10n.workspaceDebugOverviewButtonHealthRoot,
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingPing ? null : callbacks.onPingPing,
              child: Text(
                model.loadingPing
                    ? busy
                    : l10n.workspaceDebugOverviewButtonPing,
              ),
            ),
          ],
        ),
        if (model.healthBody != null) ...[
          const SizedBox(height: 8),
          Text(l10n.workspaceDebugOverviewHealthV1Line(model.healthBody!)),
        ],
        if (model.healthRootBody != null) ...[
          const SizedBox(height: 8),
          Text(l10n.workspaceDebugOverviewHealthRootLine(model.healthRootBody!)),
        ],
        if (model.pingBody != null) ...[
          const SizedBox(height: 8),
          Text(l10n.workspaceDebugOverviewPingLine(model.pingBody!)),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: model.loadingVersion ? null : callbacks.onPingVersion,
          child: Text(
            model.loadingVersion
                ? busy
                : l10n.workspaceDebugOverviewButtonVersion,
          ),
        ),
        if (model.versionBody != null) ...[
          const SizedBox(height: 8),
          Text(l10n.workspaceDebugOverviewVersionLine(model.versionBody!)),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: model.loadingReady ? null : callbacks.onPingReady,
          child: Text(
            model.loadingReady
                ? busy
                : l10n.workspaceDebugOverviewButtonReady,
          ),
        ),
        if (model.readyBody != null) ...[
          const SizedBox(height: 8),
          Text(l10n.workspaceDebugOverviewReadyLine(model.readyBody!)),
        ],
      ],
    );
  }
}
