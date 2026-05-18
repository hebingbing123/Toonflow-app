import 'package:flutter/material.dart';

import '../tokens.dart';
import 'studio_primary_button.dart';

class StudioEmptyState extends StatelessWidget {
  const StudioEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.auto_awesome_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: tokens.primary.withValues(alpha: 0.7)),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.titleLarge,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.bodySmall,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.md),
              StudioPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
