import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/layout_breakpoints.dart';
import '../../l10n/app_localizations.dart';
import '../../product_shell/studio_shell_scope.dart';
import '../tokens.dart';
import 'studio_ellipsis_tooltip_text.dart';
import 'studio_text_styles.dart';

/// Title row for secondary studio panes (tasks, jobs, quality, short-video, …).
class StudioPaneHeader extends StatelessWidget {
  const StudioPaneHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
    this.onBack,
    this.titleStyle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final resolvedTitleStyle = titleStyle ?? studioPaneTitleStyle(context);
    Widget? buildBackButton() {
      // Product shell already exposes ←/→ in the title bar (StudioShellScope).
      final effectiveShowBack =
          showBack && StudioShellScope.maybeOf(context) == null;
      if (!effectiveShowBack) {
        return null;
      }
      return IconButton(
        padding: const EdgeInsets.only(left: 0, right: 8),
        constraints: const BoxConstraints(
          minWidth: StudioSpacing.iconTouchTarget + 4,
          minHeight: StudioSpacing.iconTouchTarget + 4,
        ),
        tooltip: l10n.studioBackPreviousPane,
        style: IconButton.styleFrom(
          backgroundColor: tokens.bgSurface.withValues(alpha: 0.78),
          foregroundColor: tokens.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (onBack != null) {
            onBack!();
            return;
          }
          final scope = StudioShellScope.maybeOf(context);
          if (scope?.onPopProductPane?.call() == true) {
            return;
          }
          if (context.canPop()) {
            context.pop();
            return;
          }
          GoRouter.of(context).go('/');
        },
      );
    }

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: resolvedTitleStyle),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          StudioEllipsisTooltipText(
            text: subtitle!,
            style: studioHintStyle(context),
            maxLines: 2,
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailing =
            trailing != null &&
            constraints.maxWidth < kStudioCompactHeaderMinWidth;
        final backButton = buildBackButton();
        if (!stackTrailing) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ?backButton,
              Expanded(child: titleBlock),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      physics: const ClampingScrollPhysics(),
                      child: trailing,
                    ),
                  ),
                ),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ?backButton,
                Expanded(child: titleBlock),
              ],
            ),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        );
      },
    );
  }
}
