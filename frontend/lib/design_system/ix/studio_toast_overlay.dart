import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../components/studio_icon_button.dart';
import '../components/studio_repaint_boundary.dart';
import '../components/studio_surfaces.dart';
import '../glass.dart';
import '../studio_typography.dart';
import '../tokens.dart';

/// Visual tone for [StudioToastOverlay].
enum StudioToastTone {
  info(Icons.info_outline_rounded),
  success(Icons.check_circle_outline_rounded),
  warning(Icons.warning_amber_rounded),
  error(Icons.error_outline_rounded);

  const StudioToastTone(this.icon);
  final IconData icon;
}

/// Global top-right glass toast (replaces bottom [SnackBar] chrome).
class StudioToastOverlay {
  StudioToastOverlay._();

  static OverlayEntry? _entry;
  static Timer? _autoHideTimer;
  static OverlayState? _appOverlay;
  static final List<_QueuedToast> _queue = <_QueuedToast>[];
  static bool _draining = false;

  /// Binds the navigator overlay from [MaterialApp.builder] (see [StudioToastHost]).
  static void bindAppOverlay(OverlayState? overlay) {
    _appOverlay = overlay;
  }

  static void hide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _entry?.remove();
    _entry = null;
    _draining = false;
    if (_queue.isNotEmpty) {
      _drainQueue();
    }
  }

  static void _clearCurrentEntry() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
    _entry?.remove();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    StudioToastTone tone = StudioToastTone.info,
    IconData? icon,
    Color? iconColor,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
    Duration duration = const Duration(seconds: 4),
    bool highPriority = false,
  }) {
    final request = _QueuedToast(
      context: context,
      message: message,
      tone: tone,
      icon: icon,
      iconColor: iconColor,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: onDismiss,
      duration: duration,
      highPriority: highPriority,
    );
    if (highPriority) {
      _queue.insert(0, request);
    } else {
      _queue.add(request);
    }
    _drainQueue();
  }

  static void _drainQueue() {
    if (_draining || _queue.isEmpty) {
      return;
    }
    final next = _queue.removeAt(0);
    if (!next.context.mounted) {
      _drainQueue();
      return;
    }
    _draining = true;
    _present(next);
  }

  static void _present(_QueuedToast request) {
    _clearCurrentEntry();
    final overlay = _appOverlay ?? Overlay.maybeOf(request.context, rootOverlay: true);
    if (overlay == null) {
      _draining = false;
      return;
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final tokens = StudioTokens.of(overlayContext);
        final theme = Theme.of(overlayContext);
        final typography = StudioTypography.of(overlayContext);
        final media = MediaQuery.of(overlayContext);
        final maxWidth = (media.size.width - 32).clamp(
          StudioLayoutSize.fieldStandard,
          400.0,
        );
        final accent =
            request.iconColor ??
            switch (request.tone) {
              StudioToastTone.error => tokens.danger,
              StudioToastTone.warning => tokens.warning,
              StudioToastTone.success => tokens.success,
              StudioToastTone.info => tokens.primary,
            };

        final toastRadius = BorderRadius.circular(StudioSpacing.radiusCard);
        final toastBody = Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StudioSpacing.sm,
                    StudioLayoutSpacing.stackMedium,
                    StudioSpacing.xs,
                    StudioSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        spacing: StudioSpacing.sm,
                        runSpacing: StudioSpacing.xs,
                        children: <Widget>[
                          Icon(
                            request.icon ?? request.tone.icon,
                            color: accent,
                            size: StudioIconSize.xl,
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxWidth - 84,
                            ),
                            child: Text(
                              request.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: tokens.textPrimary,
                                fontSize: typography.body,
                                height: 1.4,
                              ),
                            ),
                          ),
                          StudioIconButton(
                            icon: Icons.close_rounded,
                            label: MaterialLocalizations.of(overlayContext)
                                .closeButtonTooltip,
                            size: StudioIconSize.md,
                            color: tokens.textMuted,
                            style: studioUtilityIconButtonStyle(overlayContext),
                            onPressed: () {
                              hide();
                              request.onDismiss?.call();
                            },
                          ),
                        ],
                      ),
                      if (request.actionLabel != null &&
                          request.onAction != null) ...<Widget>[
                        const SizedBox(height: StudioSpacing.xs),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              hide();
                              request.onAction!();
                            },
                            child: Text(
                              request.actionLabel!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: tokens.accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
        final toastSurface = StudioGlassPanel.glassEnabled
            ? ClipRRect(
                borderRadius: toastRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.glass,
                      border: Border.all(color: tokens.glassBorder),
                    ),
                    child: toastBody,
                  ),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.bgElevated.withValues(alpha: 0.96),
                  border: Border.all(color: tokens.glassBorder),
                  borderRadius: toastRadius,
                ),
                child: toastBody,
              );

        final card = StudioRepaintBoundary(
          child: Material(
            color: StudioPrimitives.transparent,
            elevation: 4,
            shadowColor: studioShadowColor(overlayContext, alpha: 0.14),
            borderRadius: toastRadius,
            clipBehavior: Clip.antiAlias,
            child: toastSurface,
          ),
        );

        return Positioned(
          top: media.padding.top + 12,
          right: 16,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: card,
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _autoHideTimer = Timer(request.duration, hide);
  }
}

class _QueuedToast {
  const _QueuedToast({
    required this.context,
    required this.message,
    required this.tone,
    this.icon,
    this.iconColor,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    required this.duration,
    required this.highPriority,
  });

  final BuildContext context;
  final String message;
  final StudioToastTone tone;
  final IconData? icon;
  final Color? iconColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final Duration duration;
  final bool highPriority;
}

/// Registers the app [Overlay] for toasts when [StudioScaffoldMessenger] sits
/// above [MaterialApp].
class StudioToastHost extends StatefulWidget {
  const StudioToastHost({super.key, required this.child});

  final Widget child;

  @override
  State<StudioToastHost> createState() => _StudioToastHostState();
}

class _StudioToastHostState extends State<StudioToastHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_bindOverlay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(_bindOverlay);
  }

  void _bindOverlay(Duration _) {
    if (!mounted) return;
    StudioToastOverlay.bindAppOverlay(Overlay.maybeOf(context));
  }

  @override
  void dispose() {
    StudioToastOverlay.bindAppOverlay(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
