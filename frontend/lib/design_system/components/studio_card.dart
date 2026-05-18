import 'package:flutter/material.dart';

import '../tokens.dart';

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StudioSpacing.sm),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.bgElevated,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(color: tokens.borderSubtle),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        child: card,
      ),
    );
  }
}
