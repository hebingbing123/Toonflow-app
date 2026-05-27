import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
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
    final apiText = l10n.workspaceDebugOverviewApiBase(model.apiBaseUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(apiText, style: studioSectionIntroStyle(context)),
        const SizedBox(height: StudioSpacing.sm),
        Wrap(
          spacing: StudioSpacing.sm,
          runSpacing: StudioSpacing.sm,
          children: <Widget>[
            _ProbeTile(
              endpoint: '/api/v1/health',
              actionLabel: model.loadingHealth
                  ? busy
                  : l10n.workspaceDebugOverviewButtonHealthV1,
              onPressed: model.loadingHealth ? null : callbacks.onPingHealth,
              responseText: model.healthBody == null
                  ? null
                  : l10n.workspaceDebugOverviewHealthV1Line(model.healthBody!),
            ),
            _ProbeTile(
              endpoint: '/health',
              actionLabel: model.loadingHealthRoot
                  ? busy
                  : l10n.workspaceDebugOverviewButtonHealthRoot,
              onPressed: model.loadingHealthRoot
                  ? null
                  : callbacks.onPingHealthRoot,
              responseText: model.healthRootBody == null
                  ? null
                  : l10n.workspaceDebugOverviewHealthRootLine(
                      model.healthRootBody!,
                    ),
            ),
            _ProbeTile(
              endpoint: '/api/v1/ping',
              actionLabel: model.loadingPing
                  ? busy
                  : l10n.workspaceDebugOverviewButtonPing,
              onPressed: model.loadingPing ? null : callbacks.onPingPing,
              responseText: model.pingBody == null
                  ? null
                  : l10n.workspaceDebugOverviewPingLine(model.pingBody!),
            ),
            _ProbeTile(
              endpoint: '/api/v1/version',
              actionLabel: model.loadingVersion
                  ? busy
                  : l10n.workspaceDebugOverviewButtonVersion,
              onPressed: model.loadingVersion ? null : callbacks.onPingVersion,
              responseText: model.versionBody == null
                  ? null
                  : l10n.workspaceDebugOverviewVersionLine(model.versionBody!),
            ),
            _ProbeTile(
              endpoint: '/api/v1/ready',
              actionLabel: model.loadingReady
                  ? busy
                  : l10n.workspaceDebugOverviewButtonReady,
              onPressed: model.loadingReady ? null : callbacks.onPingReady,
              responseText: model.readyBody == null
                  ? null
                  : l10n.workspaceDebugOverviewReadyLine(model.readyBody!),
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          apiText,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProbeTile extends StatelessWidget {
  const _ProbeTile({
    required this.endpoint,
    required this.actionLabel,
    required this.onPressed,
    this.responseText,
  });

  final String endpoint;
  final String actionLabel;
  final VoidCallback? onPressed;
  final String? responseText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 248, maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
          border: Border.all(color: studioPanelBorderColor(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(endpoint, style: studioCardTitleStyle(context)),
              const SizedBox(height: StudioSpacing.xs),
              FilledButton.tonal(
                style: studioFormTonalButtonStyle(context),
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
              if (responseText != null) ...<Widget>[
                const SizedBox(height: StudioSpacing.sm),
                SelectableText(
                  responseText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
