import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../l10n/native_bridge_startup_labels.dart';
import '../native_bridge/native_bridge_bootstrap.dart';

export '../config.dart' show kOpenflowDesktopDownloadsUrl;

enum DesktopRuntimeKind { desktopApp, webBrowser, mobileBrowser }

class DesktopRuntimeDescriptor {
  const DesktopRuntimeDescriptor({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.supportsDesktopBridge,
    required this.showDownloadCallToAction,
  });

  final DesktopRuntimeKind kind;
  final String headline;
  final String detail;
  final bool supportsDesktopBridge;
  final bool showDownloadCallToAction;
}

DesktopRuntimeDescriptor resolveDesktopRuntimeDescriptor({
  required AppLocalizations l10n,
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final isDesktopPlatform =
      resolvedPlatform == TargetPlatform.macOS ||
      resolvedPlatform == TargetPlatform.windows ||
      resolvedPlatform == TargetPlatform.linux;

  if (!isWeb && isDesktopPlatform) {
    return DesktopRuntimeDescriptor(
      kind: DesktopRuntimeKind.desktopApp,
      headline: l10n.shortVideoDesktopRuntimeHeadlineDesktopApp,
      detail: l10n.shortVideoDesktopRuntimeDetailDesktopApp,
      supportsDesktopBridge: true,
      showDownloadCallToAction: false,
    );
  }

  if (isWeb &&
      (resolvedPlatform == TargetPlatform.android ||
          resolvedPlatform == TargetPlatform.iOS)) {
    return DesktopRuntimeDescriptor(
      kind: DesktopRuntimeKind.mobileBrowser,
      headline: l10n.shortVideoDesktopRuntimeHeadlineMobileBrowser,
      detail: l10n.shortVideoDesktopRuntimeDetailMobileBrowser,
      supportsDesktopBridge: false,
      showDownloadCallToAction: true,
    );
  }

  return DesktopRuntimeDescriptor(
    kind: DesktopRuntimeKind.webBrowser,
    headline: l10n.shortVideoDesktopRuntimeHeadlineWebBrowser,
    detail: l10n.shortVideoDesktopRuntimeDetailWebBrowser,
    supportsDesktopBridge: false,
    showDownloadCallToAction: true,
  );
}

bool canUseLocalAssemblyActions({
  required DesktopRuntimeDescriptor runtime,
  required NativeBridgeStartupSnapshot snapshot,
}) {
  return runtime.supportsDesktopBridge && snapshot.isReady;
}

String? resolveLocalAssemblyBlockedHint({
  required AppLocalizations l10n,
  required DesktopRuntimeDescriptor runtime,
  required NativeBridgeStartupSnapshot snapshot,
}) {
  if (!runtime.supportsDesktopBridge) {
    return runtime.detail;
  }
  if (snapshot.isReady) {
    return null;
  }
  return nativeBridgeStartupMessage(l10n, snapshot);
}

class ShortVideoDesktopCapabilityPanel extends StatelessWidget {
  const ShortVideoDesktopCapabilityPanel({
    super.key,
    this.bootstrap,
    this.runtimeDescriptor,
    this.downloadUrl = kOpenflowDesktopDownloadsUrl,
  });

  final NativeBridgeBootstrap? bootstrap;
  final DesktopRuntimeDescriptor? runtimeDescriptor;
  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final runtime =
        runtimeDescriptor ?? resolveDesktopRuntimeDescriptor(l10n: l10n);
    final resolvedBootstrap = bootstrap ?? NativeBridgeBootstrap.instance;
    final colorScheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: resolvedBootstrap,
      builder: (context, _) {
        final snapshot = resolvedBootstrap.snapshot;
        final tone = _resolveTone(runtime: runtime, snapshot: snapshot);
        final background = switch (tone) {
          _PanelTone.info => colorScheme.secondaryContainer,
          _PanelTone.warning => colorScheme.tertiaryContainer,
          _PanelTone.error => colorScheme.errorContainer,
        };
        final foreground = switch (tone) {
          _PanelTone.info => colorScheme.onSecondaryContainer,
          _PanelTone.warning => colorScheme.onTertiaryContainer,
          _PanelTone.error => colorScheme.onErrorContainer,
        };
        final icon = switch (tone) {
          _PanelTone.info => Icons.memory_outlined,
          _PanelTone.warning => Icons.download_outlined,
          _PanelTone.error => Icons.error_outline,
        };

        final lines = <String>[
          runtime.detail,
          if (runtime.supportsDesktopBridge)
            nativeBridgeStartupMessage(l10n, snapshot),
          if (runtime.supportsDesktopBridge && snapshot.libraryPath != null)
            l10n.nativeBridgeLibraryPathLine(snapshot.libraryPath!),
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
            border: Border.all(color: foreground.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: foreground),
                  const SizedBox(width: StudioSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          runtime.headline,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          _statusLabel(
                            l10n: l10n,
                            runtime: runtime,
                            snapshot: snapshot,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: foreground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  ),
                ),
              ),
              if (runtime.showDownloadCallToAction) ...[
                const SizedBox(height: StudioSpacing.sm),
                FilledButton.icon(
                  style: studioFormIconLabeledButtonStyle(context),
                  onPressed: () => unawaited(_openDownloads()),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(
                    resolveAppLocalizationsForErrors(context)
                        .shortVideoDownloadDesktopApp,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDownloads() async {
    final uri = Uri.parse(downloadUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static _PanelTone _resolveTone({
    required DesktopRuntimeDescriptor runtime,
    required NativeBridgeStartupSnapshot snapshot,
  }) {
    if (!runtime.supportsDesktopBridge) {
      return _PanelTone.warning;
    }
    return switch (snapshot.state) {
      NativeBridgeStartupState.ready => _PanelTone.info,
      NativeBridgeStartupState.failed => _PanelTone.error,
      NativeBridgeStartupState.idle ||
      NativeBridgeStartupState.skipped => _PanelTone.warning,
    };
  }

  static String _statusLabel({
    required AppLocalizations l10n,
    required DesktopRuntimeDescriptor runtime,
    required NativeBridgeStartupSnapshot snapshot,
  }) {
    if (!runtime.supportsDesktopBridge) {
      return l10n.shortVideoDesktopRuntimeStatusNoBridge;
    }
    return switch (snapshot.state) {
      NativeBridgeStartupState.ready => l10n.shortVideoDesktopRuntimeStatusReady,
      NativeBridgeStartupState.failed =>
        l10n.shortVideoDesktopRuntimeStatusFailed,
      NativeBridgeStartupState.idle => l10n.shortVideoDesktopRuntimeStatusIdle,
      NativeBridgeStartupState.skipped =>
        l10n.shortVideoDesktopRuntimeStatusSkipped,
    };
  }
}

enum _PanelTone { info, warning, error }
