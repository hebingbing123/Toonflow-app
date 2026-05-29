import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ix/studio_focus_trap.dart';
import '../ix/studio_form_keyboard.dart';
import '../ix/studio_platform_modals.dart';
import '../ix/studio_mobile_affordances.dart';
import '../ix/studio_scroll_behavior.dart';
import '../studio_interaction_timing.dart';
import '../studio_modal_presentation.dart';
import '../tokens.dart';
import 'studio_debounced_action.dart';
import 'studio_icon_button.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// Opens a modal with studio overlay and transparent [Dialog] chrome.
Future<T?> showStudioDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final tokens = StudioTokens.of(context);
  if (studioPrefersCupertinoModals(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: studioSystemUiOverlayStyleForSurface(
            Theme.of(ctx).dialogTheme.backgroundColor ??
                Theme.of(ctx).colorScheme.surface,
          ),
          child: StudioFocusTrap(child: builder(ctx)),
        );
      },
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: tokens.overlay,
    builder: (ctx) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: studioSystemUiOverlayStyleForSurface(
          Theme.of(ctx).dialogTheme.backgroundColor ??
              Theme.of(ctx).colorScheme.surface,
        ),
        child: StudioFocusTrap(child: builder(ctx)),
      );
    },
  );
}

/// Bottom sheet with studio panel chrome (gradient surface + overlay barrier).
Future<T?> showStudioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = false,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final tokens = StudioTokens.of(context);
  Widget sheetChrome(BuildContext ctx, Widget body) {
    final sheetTokens = StudioTokens.of(ctx);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(StudioSpacing.radiusCard),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: sheetTokens.bgSurface.withValues(alpha: 0.98),
          border: Border(
            top: BorderSide(color: sheetTokens.borderSubtle),
            left: BorderSide(color: sheetTokens.borderSubtle),
            right: BorderSide(color: sheetTokens.borderSubtle),
          ),
        ),
        child: body,
      ),
    );
  }

  if (studioModalPresentationFor(isScrollControlled: isScrollControlled) ==
      StudioModalPresentation.webTallDialog) {
    return showStudioDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) {
        return StudioWebTallSheetDialog(
          showDragHandle: showDragHandle,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: builder(ctx),
          ),
        );
      },
    );
  }

  if (studioPrefersCupertinoModals(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: studioSystemUiOverlayStyleForSurface(
          StudioTokens.of(ctx).bgSurface,
        ),
        child: StudioFocusTrap(
          child: sheetChrome(ctx, builder(ctx)),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: StudioPrimitives.transparent,
    barrierColor: tokens.overlay,
    builder: (ctx) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: studioSystemUiOverlayStyleForSurface(
        StudioTokens.of(ctx).bgSurface,
      ),
      child: StudioFocusTrap(
        child: sheetChrome(ctx, builder(ctx)),
      ),
    ),
  );
}

/// Centered tall panel for Web (replaces scroll-controlled bottom sheets).
///
/// Uses full corner radius and a single surface — do not wrap with [sheetChrome].
class StudioWebTallSheetDialog extends StatelessWidget {
  const StudioWebTallSheetDialog({
    super.key,
    required this.child,
    this.showDragHandle = false,
    this.maxWidth = 760,
    this.maxHeightFactor = 0.88,
  });

  final Widget child;
  final bool showDragHandle;
  final double maxWidth;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(
      math.max(viewport.width - StudioSpacing.md * 2, 320.0),
      maxWidth,
    );
    final maxHeight = viewport.height * maxHeightFactor;

    return Dialog(
      backgroundColor: StudioPrimitives.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.md,
        vertical: StudioSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Material(
          color: tokens.bgSurface.withValues(alpha: 0.98),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            side: BorderSide(color: tokens.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (showDragHandle) ...<Widget>[
                const SizedBox(height: StudioSpacing.xs),
                Center(
                  child: Container(
                    width: StudioLayoutSize.skeletonAvatar,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.borderDefault,
                      borderRadius: BorderRadius.circular(
                        StudioSpacing.radiusHairline,
                      ),
                    ),
                  ),
                ),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple confirm/cancel dialog using studio chrome.
///
/// When [onConfirmAction] is set, the confirm button runs that future (shows
/// inline loading) and only pops `true` after success. Otherwise confirm pops
/// `true` immediately. Confirm is debounced to prevent double submission.
Future<bool?> showStudioConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool barrierDismissible = true,
  Future<void> Function()? onConfirmAction,
}) {
  return showStudioDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible && onConfirmAction == null,
    builder: (ctx) => _StudioConfirmDialog(
      title: title,
      message: message,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirmAction: onConfirmAction,
    ),
  );
}

class _StudioConfirmDialog extends StatefulWidget {
  const _StudioConfirmDialog({
    required this.title,
    this.message,
    this.content,
    this.confirmLabel,
    this.cancelLabel,
    this.destructive = false,
    this.onConfirmAction,
  });

  final String title;
  final String? message;
  final Widget? content;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool destructive;
  final Future<void> Function()? onConfirmAction;

  @override
  State<_StudioConfirmDialog> createState() => _StudioConfirmDialogState();
}

class _StudioConfirmDialogState extends State<_StudioConfirmDialog> {
  bool _confirmBusy = false;
  DateTime? _lastConfirmTap;

  Future<void> _handleConfirm() async {
    if (_confirmBusy) return;
    final now = DateTime.now();
    if (_lastConfirmTap != null &&
        now.difference(_lastConfirmTap!) <
            StudioInteractionTiming.submitDebounce) {
      return;
    }
    _lastConfirmTap = now;
    final action = widget.onConfirmAction;
    if (action == null) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _confirmBusy = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _confirmBusy = false);
    }
  }

  void _handleCancel() {
    if (_confirmBusy) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCancel =
        widget.cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel;
    final resolvedConfirm =
        widget.confirmLabel ?? MaterialLocalizations.of(context).okButtonLabel;
    final body =
        widget.content ??
        (widget.message == null
            ? null
            : Text(widget.message!, style: studioSectionIntroStyle(context)));

    final confirmChild = _confirmBusy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.destructive
                  ? Theme.of(context).colorScheme.onError
                  : Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Text(resolvedConfirm);

    if (studioPrefersCupertinoModals(context)) {
      return StudioFormKeyboardScope(
        onEnterSubmit: _confirmBusy ? null : () => unawaited(_handleConfirm()),
        child: CupertinoAlertDialog(
          title: Text(widget.title),
          content: body,
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: _confirmBusy ? null : _handleCancel,
              child: Text(resolvedCancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: widget.destructive,
              isDefaultAction: !widget.destructive,
              onPressed: _confirmBusy ? null : () => unawaited(_handleConfirm()),
              child: confirmChild,
            ),
          ],
        ),
      );
    }

    Widget buildMaterialConfirm(VoidCallback? onPressed) {
      if (widget.destructive) {
        return FilledButton(
          style: studioFormDestructivePrimaryButtonStyle(context),
          onPressed: onPressed,
          child: confirmChild,
        );
      }
      return FilledButton(
        style: studioFormPrimaryButtonStyle(context),
        onPressed: onPressed,
        child: confirmChild,
      );
    }

    return StudioFormKeyboardScope(
      onEnterSubmit: _confirmBusy ? null : _handleConfirm,
      child: StudioAlertDialog(
        title: Text(widget.title),
        content: body,
        actions: <Widget>[
          TextButton(
            onPressed: _confirmBusy ? null : _handleCancel,
            child: Text(resolvedCancel),
          ),
          StudioDebouncedAction(
            enabled: !_confirmBusy,
            onPressed: _handleConfirm,
            builder: (ctx, onPressed) => buildMaterialConfirm(onPressed),
          ),
        ],
      ),
    );
  }
}

/// Drop-in replacement for [AlertDialog] with studio panel chrome.
class StudioAlertDialog extends StatelessWidget {
  const StudioAlertDialog({
    super.key,
    this.onEnterSubmit,
    this.enterSubmitEnabled = true,
    this.icon,
    this.iconPadding,
    this.iconColor,
    this.title,
    this.titlePadding,
    this.titleTextStyle,
    this.content,
    this.contentPadding,
    this.contentTextStyle,
    this.actions,
    this.actionsPadding,
    this.actionsAlignment = MainAxisAlignment.end,
    this.actionsOverflowAlignment,
    this.actionsOverflowButtonSpacing,
    this.buttonPadding,
    this.backgroundColor,
    this.elevation,
    this.shadowColor,
    this.surfaceTintColor,
    this.semanticLabel,
    this.insetPadding,
    this.clipBehavior,
    this.shape,
    this.alignment,
    this.scrollable = false,
    this.maxWidth = 520,
    this.maxHeightFactor = 0.88,
    this.showCloseButton = true,
  });

  /// When set, Enter on a single-line field triggers this callback.
  ///
  /// When null and [enterSubmitEnabled] is true, a lone single-line [TextField] in
  /// [content] auto-wires to the trailing [FilledButton] in [actions].
  final VoidCallback? onEnterSubmit;

  /// When false, never binds Enter (including auto-infer).
  final bool enterSubmitEnabled;

  final Widget? icon;
  final EdgeInsetsGeometry? iconPadding;
  final Color? iconColor;
  final Widget? title;
  final EdgeInsetsGeometry? titlePadding;
  final TextStyle? titleTextStyle;
  final Widget? content;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? contentTextStyle;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? actionsPadding;
  final MainAxisAlignment actionsAlignment;
  final OverflowBarAlignment? actionsOverflowAlignment;
  final double? actionsOverflowButtonSpacing;
  final EdgeInsetsGeometry? buttonPadding;
  final Color? backgroundColor;
  final double? elevation;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final String? semanticLabel;
  final EdgeInsetsGeometry? insetPadding;
  final Clip? clipBehavior;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;
  final bool scrollable;
  final double maxWidth;
  final double maxHeightFactor;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    Widget? leading;
    if (icon != null) {
      leading = Padding(
        padding: iconPadding ?? EdgeInsets.zero,
        child: IconTheme(
          data: IconThemeData(
            color: iconColor ?? tokens.signal,
            size: StudioIconSize.xl,
          ),
          child: icon!,
        ),
      );
    }

    final resolvedTitle = _resolveTitleWidget(context);
    final body = content ?? const SizedBox.shrink();
    final styledBody = contentTextStyle == null
        ? body
        : DefaultTextStyle(style: contentTextStyle!, child: body);
    final paddedBody = contentPadding == null
        ? styledBody
        : Padding(padding: contentPadding!, child: styledBody);

    final shellActions = actions;

    final shell = StudioDialogShell(
      title: _resolveTitleString(title) ?? '',
      titleWidget: resolvedTitle,
      leading: leading,
      onClose: showCloseButton ? () => Navigator.of(context).pop() : null,
      actions: shellActions,
      actionsAlignment: actionsAlignment,
      maxWidth: maxWidth,
      maxHeightFactor: maxHeightFactor,
      scrollable: scrollable,
      child: paddedBody,
    );

    final resolvedEnterSubmit = studioResolveAlertDialogEnterSubmit(
      enterSubmitEnabled: enterSubmitEnabled,
      onEnterSubmit: onEnterSubmit,
      content: content,
      actions: actions,
    );
    if (resolvedEnterSubmit == null) {
      return shell;
    }
    return StudioFormKeyboardScope(
      onEnterSubmit: resolvedEnterSubmit,
      child: shell,
    );
  }

  String? _resolveTitleString(Widget? widget) {
    if (widget is Text) {
      if (widget.data != null && widget.data!.isNotEmpty) {
        return widget.data;
      }
      if (widget.textSpan != null) {
        return widget.textSpan!.toPlainText();
      }
    }
    return null;
  }

  Widget? _resolveTitleWidget(BuildContext context) {
    final widget = title;
    if (widget == null) {
      return null;
    }
    if (_resolveTitleString(widget) != null) {
      return null;
    }
    final style = titleTextStyle ?? studioDialogTitleStyle(context);
    return Padding(
      padding: titlePadding ?? EdgeInsets.zero,
      child: DefaultTextStyle(style: style!, child: widget),
    );
  }
}

/// Decorated dialog surface for fully custom layouts (no built-in header).
class StudioDialogFrame extends StatelessWidget {
  const StudioDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.maxHeightFactor = 0.92,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: StudioSpacing.md,
      vertical: StudioSpacing.md,
    ),
  });

  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width.isFinite
        ? viewport.width.clamp(320.0, maxWidth)
        : maxWidth;
    final maxHeight = viewport.height.isFinite
        ? viewport.height * maxHeightFactor
        : 720.0;

    return Dialog(
      backgroundColor: StudioPrimitives.transparent,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Material(
          color: StudioPrimitives.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: studioInsetElevationShadow(
                context,
                alpha: 0.24,
                blurRadius: StudioSpacing.md,
                offset: const Offset(0, StudioSpacing.sm),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tech-style dialog frame: elevated panel, gradient border, header + scroll body.
class StudioDialogShell extends StatelessWidget {
  const StudioDialogShell({
    super.key,
    required this.title,
    required this.child,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.onClose,
    this.actions,
    this.actionsAlignment = MainAxisAlignment.end,
    this.maxWidth = 760,
    this.maxHeightFactor = 0.9,
    this.scrollable = true,
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final Widget child;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final MainAxisAlignment actionsAlignment;
  final double maxWidth;
  final double maxHeightFactor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final width = viewport.width.isFinite
        ? viewport.width.clamp(320.0, maxWidth)
        : maxWidth;
    final maxHeight = viewport.height.isFinite
        ? viewport.height * maxHeightFactor
        : 720.0;

    final headerTitle =
        titleWidget ??
        (title.isEmpty
            ? null
            : Text(title, style: studioDialogTitleStyle(context)));

    final bodySection = scrollable
        ? Flexible(
            child: StudioScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(StudioSpacing.sm),
                child: child,
              ),
            ),
          )
        : Flexible(
            fit: FlexFit.loose,
            child: Padding(
              padding: const EdgeInsets.all(StudioSpacing.sm),
              child: child,
            ),
          );

    return Dialog(
      backgroundColor: StudioPrimitives.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.md,
        vertical: StudioSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: Material(
          color: StudioPrimitives.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.bgSurface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              border: Border.all(color: tokens.borderSubtle),
              boxShadow: studioInsetElevationShadow(
                context,
                alpha: 0.24,
                blurRadius: StudioSpacing.md,
                offset: const Offset(0, StudioSpacing.sm),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (headerTitle != null ||
                      subtitle != null ||
                      leading != null ||
                      onClose != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        StudioSpacing.sm,
                        StudioSpacing.sm,
                        StudioSpacing.xs,
                        StudioSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (leading != null) ...<Widget>[
                            leading!,
                            const SizedBox(width: StudioSpacing.radiusComfort),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                ?headerTitle,
                                ...?subtitle == null
                                    ? null
                                    : <Widget>[
                                        const SizedBox(
                                          height:
                                              StudioLayoutSpacing.titleTight,
                                        ),
                                        Text(
                                          subtitle!,
                                          style: studioSectionIntroStyle(
                                            context,
                                          ),
                                        ),
                                      ],
                              ],
                            ),
                          ),
                          if (onClose != null)
                            StudioIconButton(
                              icon: Icons.close,
                              label: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              size: StudioIconSize.md,
                              color: tokens.textSecondary,
                              style: IconButton.styleFrom(
                                backgroundColor: tokens.bgSurface.withValues(
                                  alpha: 0.78,
                                ),
                                foregroundColor: tokens.textSecondary,
                                minimumSize: const Size(
                                  StudioSpacing.iconTouchTarget,
                                  StudioSpacing.iconTouchTarget,
                                ),
                                tapTargetSize: MaterialTapTargetSize.padded,
                                visualDensity: VisualDensity.standard,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    StudioSpacing.radiusComfort,
                                  ),
                                  side: BorderSide(
                                    color: tokens.surfaceHighlight,
                                  ),
                                ),
                              ),
                              onPressed: onClose,
                            ),
                        ],
                      ),
                    ),
                  if (headerTitle != null ||
                      subtitle != null ||
                      leading != null ||
                      onClose != null)
                    Divider(
                      height: StudioControlSize.dividerThickness,
                      color: tokens.borderSubtle,
                    ),
                  bodySection,
                  if (actions != null && actions!.isNotEmpty) ...<Widget>[
                    Divider(
                      height: StudioControlSize.dividerThickness,
                      color: tokens.borderSubtle,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        StudioSpacing.sm,
                        StudioSpacing.xs,
                        StudioSpacing.sm,
                        StudioSpacing.sm,
                      ),
                      child: Wrap(
                        alignment: switch (actionsAlignment) {
                          MainAxisAlignment.start => WrapAlignment.start,
                          MainAxisAlignment.center => WrapAlignment.center,
                          MainAxisAlignment.end => WrapAlignment.end,
                          MainAxisAlignment.spaceBetween =>
                            WrapAlignment.spaceBetween,
                          MainAxisAlignment.spaceAround =>
                            WrapAlignment.spaceAround,
                          MainAxisAlignment.spaceEvenly =>
                            WrapAlignment.spaceEvenly,
                        },
                        spacing: StudioSpacing.xs,
                        runSpacing: StudioSpacing.xs,
                        children: actions!,
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
  }
}

/// Inset telemetry / status block inside studio dialogs.
class StudioDialogInsetPanel extends StatelessWidget {
  const StudioDialogInsetPanel({
    super.key,
    required this.lines,
    this.monospace = true,
  });

  final List<String> lines;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final filtered = lines.where((line) => line.trim().isNotEmpty).toList();
    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }
    final base = studioHintStyle(context);
    final style = monospace
        ? base?.copyWith(
            fontFamily: 'monospace',
            fontFamilyFallback: const <String>[
              'Menlo',
              'Consolas',
              'monospace',
            ],
            height: 1.45,
          )
        : base;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: StudioLayoutSpacing.insetDense,
        vertical: StudioLayoutSpacing.inlineGap,
      ),
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SelectableText(filtered.join('\n'), style: style),
    );
  }
}
