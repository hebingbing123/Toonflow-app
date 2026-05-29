import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// Step state for [StudioStepper].
enum StudioStepState {
  pending,
  active,
  complete,
  error,
}

/// One step in [StudioStepper].
class StudioStepItem {
  const StudioStepItem({
    required this.label,
    this.subtitle,
    this.state = StudioStepState.pending,
  });

  final String label;
  final String? subtitle;
  final StudioStepState state;
}

/// Horizontal or vertical step indicator with optional navigation.
class StudioStepper extends StatelessWidget {
  const StudioStepper({
    super.key,
    required this.steps,
    this.currentIndex = 0,
    this.axis = Axis.horizontal,
    this.onStepTapped,
  });

  final List<StudioStepItem> steps;
  final int currentIndex;
  final Axis axis;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    if (axis == Axis.vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < steps.length; i++)
            _StepTile(
              index: i,
              item: _resolveState(steps[i], i),
              isLast: i == steps.length - 1,
              vertical: true,
              onTap: onStepTapped == null ? null : () => onStepTapped!(i),
            ),
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++)
          Expanded(
            child: _StepTile(
              index: i,
              item: _resolveState(steps[i], i),
              isLast: i == steps.length - 1,
              vertical: false,
              onTap: onStepTapped == null ? null : () => onStepTapped!(i),
            ),
          ),
      ],
    );
  }

  StudioStepItem _resolveState(StudioStepItem item, int index) {
    if (item.state != StudioStepState.pending) {
      return item;
    }
    if (index < currentIndex) {
      return StudioStepItem(
        label: item.label,
        subtitle: item.subtitle,
        state: StudioStepState.complete,
      );
    }
    if (index == currentIndex) {
      return StudioStepItem(
        label: item.label,
        subtitle: item.subtitle,
        state: StudioStepState.active,
      );
    }
    return item;
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.item,
    required this.isLast,
    required this.vertical,
    this.onTap,
  });

  final int index;
  final StudioStepItem item;
  final bool isLast;
  final bool vertical;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final metaSize = StudioTypography.of(context).meta;
    final badgeColor = switch (item.state) {
      StudioStepState.complete => tokens.success,
      StudioStepState.active => tokens.primary,
      StudioStepState.error => tokens.danger,
      StudioStepState.pending => tokens.borderSubtle,
    };
    final labelColor = switch (item.state) {
      StudioStepState.pending => tokens.textMuted,
      StudioStepState.error => tokens.danger,
      _ => tokens.textPrimary,
    };

    final badge = Semantics(
      label: item.label,
      selected: item.state == StudioStepState.active,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: item.state == StudioStepState.pending
              ? tokens.bgInset
              : badgeColor.withValues(alpha: 0.18),
          border: Border.all(color: badgeColor),
        ),
        child: item.state == StudioStepState.complete
            ? Icon(Icons.check_rounded, size: 16, color: badgeColor)
            : Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
      ),
    );

    final label = Column(
      crossAxisAlignment:
          vertical ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          item.label,
          textAlign: vertical ? TextAlign.start : TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: metaSize,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        if (item.subtitle != null)
          Text(
            item.subtitle!,
            style: studioHintStyle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    final body = vertical
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  badge,
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 32,
                      color: tokens.borderSubtle,
                    ),
                ],
              ),
              const SizedBox(width: StudioSpacing.sm),
              Expanded(child: label),
            ],
          )
        : Column(
            children: [
              badge,
              const SizedBox(height: StudioSpacing.xs),
              label,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(top: StudioSpacing.xs),
                  child: Divider(color: tokens.borderSubtle, height: 1),
                ),
            ],
          );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: StudioSpacing.xs),
        child: body,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: StudioSpacing.xs,
          horizontal: StudioSpacing.xs,
        ),
        child: body,
      ),
    );
  }
}
