import 'package:flutter/material.dart';

import '../theme.dart';
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
    final studio = StudioColors.of(context);
    final theme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          tokens.panelGlowSecondary.withValues(alpha: 0.22),
                          tokens.panelGlow.withValues(alpha: 0.08),
                          tokens.bgInset.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tokens.surfaceHighlight.withValues(alpha: 0.9),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          tokens.bgSurface.withValues(alpha: 0.96),
                          tokens.bgInset.withValues(alpha: 0.98),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tokens.panelGlow.withValues(alpha: 0.18),
                          blurRadius: 18,
                          spreadRadius: -10,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: studio.signalGradient,
                        ),
                        child: Icon(icon, size: 22, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.titleLarge?.copyWith(letterSpacing: 0),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.bodySmall?.copyWith(height: 1.55),
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
