import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
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
    final resolvedTitleStyle = titleStyle ?? studioPaneTitleStyle(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showBack)
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.only(left: 0, right: 8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: l10n.studioExitProjectStudio,
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack ?? () => GoRouter.of(context).go('/'),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: resolvedTitleStyle),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(subtitle!, style: studioHintStyle(context)),
              ],
            ],
          ),
        ),
        ...?(trailing == null
            ? null
            : <Widget>[const SizedBox(width: 12), trailing!]),
      ],
    );
  }
}
