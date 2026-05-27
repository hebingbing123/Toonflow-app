import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../ix/studio_platform_modals.dart';
import '../ix/studio_scroll_behavior.dart';
import '../tokens.dart';
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
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: tokens.overlay,
    builder: builder,
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

  if (studioPrefersCupertinoModals(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => sheetChrome(ctx, builder(ctx)),
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
    builder: (ctx) => sheetChrome(ctx, builder(ctx)),
  );
}

/// Simple confirm/cancel dialog using studio chrome.
Future<bool?> showStudioConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
  bool barrierDismissible = true,
}) {
  return showStudioDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
      builder: (ctx) {
      final resolvedCancel = cancelLabel ?? MaterialLocalizations.of(ctx).cancelButtonLabel;
      final resolvedConfirm = confirmLabel ?? MaterialLocalizations.of(ctx).okButtonLabel;
      if (studioPrefersCupertinoModals(ctx)) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: content ??
              (message == null ? null : Text(message, style: studioSectionIntroStyle(ctx))),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(resolvedCancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: destructive,
              isDefaultAction: !destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(resolvedConfirm),
            ),
          ],
        );
      }
      return StudioAlertDialog(
        title: Text(title),
        content: content ??
            (message == null
                ? null
                : Text(message, style: studioSectionIntroStyle(ctx))),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(resolvedCancel),
          ),
          if (destructive)
            FilledButton(
              style: studioFormDestructivePrimaryButtonStyle(ctx),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(resolvedConfirm),
            )
          else
            FilledButton(
              style: studioFormPrimaryButtonStyle(ctx),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(resolvedConfirm),
            ),
        ],
      );
    },
  );
}

/// Drop-in replacement for [AlertDialog] with studio panel chrome.
class StudioAlertDialog extends StatelessWidget {
  const StudioAlertDialog({
    super.key,
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
          data: IconThemeData(color: iconColor ?? tokens.signal, size: 22),
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

    return StudioDialogShell(
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

    final headerTitle = titleWidget ??
        (title.isEmpty
            ? null
            : Text(title, style: studioDialogTitleStyle(context)));

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
                mainAxisSize: MainAxisSize.min,
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
                                          height: StudioLayoutSpacing.titleTight,
                                        ),
                                        Text(
                                          subtitle!,
                                          style: studioSectionIntroStyle(context),
                                        ),
                                      ],
                              ],
                            ),
                          ),
                          if (onClose != null)
                            IconButton(
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
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
                                  borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
                                  side: BorderSide(
                                    color: tokens.surfaceHighlight,
                                  ),
                                ),
                              ),
                              onPressed: onClose,
                              icon: const Icon(Icons.close, size: 20),
                            ),
                        ],
                      ),
                    ),
                  if (headerTitle != null ||
                      subtitle != null ||
                      leading != null ||
                      onClose != null)
                    Divider(height: 1, color: tokens.borderSubtle),
                  Flexible(
                    child: scrollable
                        ? StudioScrollbar(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(StudioSpacing.sm),
                              child: child,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(StudioSpacing.sm),
                            child: child,
                          ),
                  ),
                  if (actions != null && actions!.isNotEmpty) ...<Widget>[
                    Divider(height: 1, color: tokens.borderSubtle),
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
            fontFamilyFallback: const <String>['Menlo', 'Consolas', 'monospace'],
            height: 1.45,
          )
        : base;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: SelectableText(filtered.join('\n'), style: style),
    );
  }
}
