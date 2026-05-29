import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/layout_breakpoints.dart';
import '../../l10n/app_localizations.dart';
import '../../local_prefs/risky_operation_confirm_prefs.dart';
import '../../product_shell/studio_shell_scope.dart';
import '../tokens.dart';
import 'studio_entrance_motion.dart';
import 'studio_ellipsis_tooltip_text.dart';
import 'studio_icon_button.dart';
import 'studio_text_styles.dart';

/// Title + risky-operation prefs menu; stacks when pane width is below [breakpoint].
class StudioPaneTitleMenuRow extends StatelessWidget {
  const StudioPaneTitleMenuRow({
    super.key,
    this.title,
    this.titleWidget,
    this.titleStyle,
    this.menu,
    this.menuTooltip,
    this.breakpoint = kStudioPipelineInlineMinWidth,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final TextStyle? titleStyle;
  final Widget? menu;
  final String? menuTooltip;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = titleWidget ??
        Text(
          title!,
          style: titleStyle ?? studioPaneTitleStyle(context),
        );
    final prefsMenu =
        menu ??
        RiskyOperationConfirmPrefsOverflowMenu(tooltip: menuTooltip);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < breakpoint;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              resolvedTitle,
              const SizedBox(height: StudioSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: prefsMenu),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: resolvedTitle),
            prefsMenu,
          ],
        );
      },
    );
  }
}

/// Merges [StudioPaneHeader] with inline toolbar actions (no separate 「筛选」 row).
class StudioPaneToolbar extends StatelessWidget {
  const StudioPaneToolbar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.secondary,
    this.menu,
    this.showBack = true,
    this.onBack,
    this.titleStyle,
    this.titleHeroTag,
  });

  final String title;
  final String? subtitle;
  final Widget? actions;
  final Widget? secondary;
  final Widget? menu;
  final bool showBack;
  final VoidCallback? onBack;
  final TextStyle? titleStyle;
  final String? titleHeroTag;

  Widget? _mergedTrailing() {
    if (actions == null && menu == null) {
      return null;
    }
    if (actions == null) {
      return menu;
    }
    if (menu == null) {
      return actions;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final handset = MediaQuery.sizeOf(context).shortestSide <
            kProjectsHomePhoneShortestSide;
        final stackActions =
            handset ||
            (maxWidth.isFinite && maxWidth < kStudioCompactHeaderMinWidth);
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              actions!,
              const SizedBox(height: StudioSpacing.sm),
              Align(alignment: Alignment.centerRight, child: menu!),
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              actions!,
              const SizedBox(width: StudioSpacing.sm),
              menu!,
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StudioPaneHeader(
          title: title,
          subtitle: subtitle,
          showBack: showBack,
          onBack: onBack,
          titleStyle: titleStyle,
          titleHeroTag: titleHeroTag,
          trailing: _mergedTrailing(),
        ),
        if (secondary != null) ...<Widget>[
          const SizedBox(height: StudioLayoutSpacing.inlineGap),
          secondary!,
        ],
      ],
    );
  }
}

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
    this.titleHeroTag,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;
  final VoidCallback? onBack;
  final TextStyle? titleStyle;
  final String? titleHeroTag;

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
      return StudioIconButton(
        icon: Icons.arrow_back,
        label: l10n.studioBackPreviousPane,
        style: IconButton.styleFrom(
          padding: const EdgeInsets.only(left: 0, right: StudioSpacing.xs),
          minimumSize: const Size(
            StudioSpacing.iconTouchTarget + 4,
            StudioSpacing.iconTouchTarget + 4,
          ),
          fixedSize: const Size(
            StudioSpacing.iconTouchTarget + 4,
            StudioSpacing.iconTouchTarget + 4,
          ),
          backgroundColor: tokens.bgSurface.withValues(alpha: 0.78),
          foregroundColor: tokens.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
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

    final titleWidget = StudioHero(
      tag: titleHeroTag,
      child: Text(
        title,
        style: resolvedTitleStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        titleWidget,
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
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
        final handset = MediaQuery.sizeOf(context).shortestSide <
            kProjectsHomePhoneShortestSide;
        final stackTrailing =
            trailing != null &&
            (handset || constraints.maxWidth < kStudioCompactHeaderMinWidth);
        final backButton = buildBackButton();
        if (!stackTrailing) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              ?backButton,
              Expanded(child: titleBlock),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: StudioSpacing.radiusComfort),
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
            SizedBox(
              width: constraints.maxWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        );
      },
    );
  }
}
