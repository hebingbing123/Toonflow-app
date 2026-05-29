import 'package:flutter/material.dart';

import 'studio_primary_button.dart';
import 'studio_surfaces.dart';
import 'studio_toolbar_button.dart';
import '../tokens.dart';

/// Visual variant for [StudioButton].
enum StudioButtonVariant { filled, outlined, text, toolbar }

/// Size tier for [StudioButton].
enum StudioButtonSize { small, medium, large }

/// Unified Studio button API (wraps [StudioPrimaryButton] and toolbar styles).
class StudioButton extends StatelessWidget {
  const StudioButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = StudioButtonVariant.filled,
    this.size = StudioButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final StudioButtonVariant variant;
  final StudioButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final String? semanticLabel;

  EdgeInsets _paddingForSize() {
    return switch (size) {
      StudioButtonSize.small => const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: StudioSpacing.chromeActionGap,
      ),
      StudioButtonSize.large => const EdgeInsets.symmetric(
        horizontal: StudioSpacing.md,
        vertical: StudioSpacing.sm,
      ),
      StudioButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: StudioSpacing.sm,
        vertical: StudioSpacing.xs,
      ),
    };
  }

  Widget _labelChild() {
    if (isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(label);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isDisabled || isLoading ? null : onPressed;
    final padding = WidgetStatePropertyAll(_paddingForSize());
    final child = switch (variant) {
      StudioButtonVariant.toolbar => StudioToolbarButton(
        label: label,
        onPressed: effectiveOnPressed,
        icon: icon,
        busy: isLoading,
      ),
      StudioButtonVariant.filled => StudioPrimaryButton(
        label: label,
        onPressed: effectiveOnPressed,
        icon: icon,
        loading: isLoading,
      ),
      StudioButtonVariant.outlined => icon != null
          ? OutlinedButton.icon(
              style: studioFormSecondaryButtonStyle(context).copyWith(
                padding: padding,
              ),
              onPressed: effectiveOnPressed,
              icon: Icon(icon, size: StudioIconSize.sm),
              label: _labelChild(),
            )
          : OutlinedButton(
              style: studioFormSecondaryButtonStyle(context).copyWith(
                padding: padding,
              ),
              onPressed: effectiveOnPressed,
              child: _labelChild(),
            ),
      StudioButtonVariant.text => icon != null
          ? TextButton.icon(
              style: studioFormTextButtonIconStyle(context).copyWith(
                padding: padding,
              ),
              onPressed: effectiveOnPressed,
              icon: Icon(icon, size: StudioIconSize.sm),
              label: _labelChild(),
            )
          : TextButton(
              style: studioFormTextButtonIconStyle(context).copyWith(
                padding: padding,
              ),
              onPressed: effectiveOnPressed,
              child: _labelChild(),
            ),
    };

    if (semanticLabel == null) {
      return child;
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: effectiveOnPressed != null,
      child: child,
    );
  }
}
