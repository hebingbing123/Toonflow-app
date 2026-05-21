import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../components/studio_surfaces.dart';
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

  /// Binds the navigator overlay from [MaterialApp.builder] (see [StudioToastHost]).
  static void bindAppOverlay(OverlayState? overlay) {
    _appOverlay = overlay;
  }

  static void hide() {
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
  }) {
    hide();
    final overlay =
        _appOverlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final tokens = StudioTokens.of(overlayContext);
        final typography = StudioTypography.of(overlayContext);
        final media = MediaQuery.of(overlayContext);
        final maxWidth = (media.size.width - 32).clamp(280.0, 400.0);
        final accent = iconColor ??
            switch (tone) {
              StudioToastTone.error => tokens.danger,
              StudioToastTone.warning => tokens.warning,
              StudioToastTone.success => tokens.success,
              StudioToastTone.info => tokens.primary,
            };

        final card = Material(
          color: Colors.transparent,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.glass,
                  border: Border.all(color: tokens.glassBorder),
                ),
                child: Padding(
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(icon ?? tone.icon, color: accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              message,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: typography.body,
                                height: 1.4,
                              ),
                            ),
                          ),
                          IconButton(
                            style: studioUtilityIconButtonStyle(overlayContext),
                            onPressed: () {
                              hide();
                              onDismiss?.call();
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                      if (actionLabel != null && onAction != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              hide();
                              onAction();
                            },
                            child: Text(
                              actionLabel,
                              style: TextStyle(color: tokens.accent),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
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
    _autoHideTimer = Timer(duration, hide);
  }
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
