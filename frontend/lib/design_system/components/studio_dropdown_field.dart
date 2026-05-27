import 'dart:async';

import 'package:flutter/material.dart';

import '../ix/studio_mobile_affordances.dart';
import '../studio_typography.dart';
import '../studio_motion.dart';
import '../tokens.dart';
import 'studio_decorative_icon.dart';
import 'studio_surfaces.dart';

/// One selectable row in a [StudioDropdownField] menu.
@immutable
class StudioDropdownEntry<T> {
  const StudioDropdownEntry({
    required this.value,
    required this.label,
    this.child,
    this.enabled = true,
  });

  final T value;
  final String label;
  final Widget? child;
  final bool enabled;
}

/// Studio-themed select field (MenuAnchor + InputDecorator trigger).
class StudioDropdownField<T> extends StatelessWidget {
  const StudioDropdownField({
    super.key,
    required this.entries,
    required this.onChanged,
    this.value,
    this.labelText,
    this.enabled = true,
    this.width,
    this.emptyLabel,
    this.isDense = true,
    this.decoration,
  });

  final T? value;
  final List<StudioDropdownEntry<T>> entries;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final bool enabled;
  final double? width;
  final String? emptyLabel;
  final bool isDense;
  final InputDecoration? decoration;

  bool get _isEnabled => enabled && onChanged != null;

  StudioDropdownEntry<T>? get _selectedEntry {
    for (final entry in entries) {
      if (entry.value == value) {
        return entry;
      }
    }
    return null;
  }

  String get _displayLabel {
    final selected = _selectedEntry;
    if (selected != null) {
      return selected.label;
    }
    if (value != null) {
      return value.toString();
    }
    return emptyLabel ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final field = StudioMenuAnchor(
      menuChildren: entries
          .map(
            (entry) => StudioSelectMenuItem(
              label: entry.label,
              selected: entry.value == value,
              enabled: _isEnabled && entry.enabled,
              onPressed: _isEnabled && entry.enabled
                  ? () {
                      unawaited(studioLightImpact());
                      onChanged!(entry.value);
                    }
                  : null,
              child: entry.child,
            ),
          )
          .toList(growable: false),
      builder: (context, controller, child) {
        return StudioSelectFieldTrigger(
          labelText: labelText,
          valueLabel: _displayLabel,
          expanded: controller.isOpen,
          enabled: _isEnabled,
          isDense: isDense,
          decoration: decoration,
          onTap: _isEnabled
              ? () {
                  unawaited(studioLightImpact());
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
        );
      },
    );
    if (width == null) {
      return field;
    }
    return SizedBox(width: width, child: field);
  }
}

/// Drop-in styled replacement for Material [DropdownButtonFormField].
class StudioDropdownButtonFormField<T> extends StatelessWidget {
  const StudioDropdownButtonFormField({
    super.key,
    this.value,
    this.initialValue,
    this.decoration,
    required this.items,
    this.onChanged,
    this.isExpanded = false,
    this.hint,
    this.width,
  });

  final T? value;
  final T? initialValue;
  final InputDecoration? decoration;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final Widget? hint;
  final double? width;

  T? get _effectiveValue => value ?? initialValue;

  @override
  Widget build(BuildContext context) {
    final entries = items
        .map(
          (item) => StudioDropdownEntry<T>(
            value: item.value as T,
            label: labelFromDropdownChild(item.child),
            child: item.child,
            enabled: item.enabled,
          ),
        )
        .toList(growable: false);

    return StudioDropdownField<T>(
      value: _effectiveValue,
      labelText: decoration?.labelText,
      decoration: decoration,
      entries: entries,
      onChanged: onChanged,
      enabled: onChanged != null,
      width: isExpanded ? null : width,
      emptyLabel: hint != null ? labelFromDropdownChild(hint!) : null,
    );
  }
}

/// Styled replacement for Material [DropdownButton] (no form decoration).
class StudioDropdownButton<T> extends StatelessWidget {
  const StudioDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = false,
    this.hint,
    this.width,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;
  final Widget? hint;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return StudioDropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      hint: hint,
      width: width,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: StudioSpacing.xs,
          vertical: StudioSpacing.xs,
        ),
      ),
    );
  }
}

/// Shared [MenuAnchor] wrapper — always applies [studioSelectMenuStyle].
class StudioMenuAnchor extends StatelessWidget {
  const StudioMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
    this.alignmentOffset = const Offset(0, 6),
    this.crossAxisUnconstrained = false,
  });

  final List<Widget> menuChildren;
  final MenuAnchorChildBuilder builder;
  final Offset alignmentOffset;
  final bool crossAxisUnconstrained;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      style: studioSelectMenuStyle(context),
      alignmentOffset: alignmentOffset,
      crossAxisUnconstrained: crossAxisUnconstrained,
      menuChildren: menuChildren,
      builder: builder,
    );
  }
}

/// One action row in [StudioIconMenuButton] menus.
@immutable
class StudioMenuEntry<T> {
  const StudioMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.child,
    this.enabled = true,
    this.foregroundColor,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? child;
  final bool enabled;
  final Color? foregroundColor;
}

/// Icon-trigger action menu (locale, overflow, saved-view actions, etc.).
class StudioIconMenuButton<T> extends StatelessWidget {
  const StudioIconMenuButton({
    super.key,
    this.icon,
    this.iconWidget,
    this.tooltip,
    this.style,
    this.iconSize,
    required this.entries,
    required this.onSelected,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String? tooltip;
  final ButtonStyle? style;
  final double? iconSize;
  final List<StudioMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return StudioMenuAnchor(
      menuChildren: entries
          .map(
            (entry) => Builder(
              builder: (menuContext) {
                final menuController = MenuController.maybeOf(menuContext);
                return StudioSelectMenuItem(
                  label: entry.label,
                  subtitle: entry.subtitle,
                  leading: entry.leading,
                  selected: false,
                  showCheckmark: false,
                  enabled: entry.enabled,
                  foregroundColor: entry.foregroundColor,
                  onPressed: entry.enabled
                      ? () {
                          unawaited(studioLightImpact());
                          menuController?.close();
                          onSelected(entry.value);
                        }
                      : null,
                  child: entry.child,
                );
              },
            ),
          )
          .toList(growable: false),
      builder: (context, controller, child) {
        return IconButton(
          style: style,
          tooltip: tooltip,
          onPressed: () {
            unawaited(studioLightImpact());
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          icon: iconWidget ?? Icon(icon, size: iconSize),
        );
      },
    );
  }
}

/// Multi-select field with the same menu chrome as [StudioDropdownField].
class StudioMultiSelectField<T> extends StatefulWidget {
  const StudioMultiSelectField({
    super.key,
    required this.entries,
    required this.selectedValues,
    required this.onChanged,
    required this.valueLabel,
    this.decoration,
    this.enabled = true,
    this.width,
  });

  final List<StudioDropdownEntry<T>> entries;
  final Set<T> selectedValues;
  final ValueChanged<Set<T>> onChanged;
  final String valueLabel;
  final InputDecoration? decoration;
  final bool enabled;
  final double? width;

  @override
  State<StudioMultiSelectField<T>> createState() =>
      _StudioMultiSelectFieldState<T>();
}

class _StudioMultiSelectFieldState<T> extends State<StudioMultiSelectField<T>> {
  late Set<T> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.from(widget.selectedValues);
  }

  @override
  void didUpdateWidget(StudioMultiSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValues != widget.selectedValues) {
      _selected = Set<T>.from(widget.selectedValues);
    }
  }

  void _toggle(T value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
    unawaited(studioLightImpact());
    widget.onChanged(Set<T>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final field = StudioMenuAnchor(
      menuChildren: widget.entries
          .map(
            (entry) => _StudioMultiSelectMenuRow<T>(
              label: entry.label,
              selected: _selected.contains(entry.value),
              enabled: widget.enabled && entry.enabled,
              onPressed: widget.enabled && entry.enabled
                  ? () => _toggle(entry.value)
                  : null,
              child: entry.child,
            ),
          )
          .toList(growable: false),
      builder: (context, controller, child) {
        return StudioSelectFieldTrigger(
          valueLabel: widget.valueLabel,
          expanded: controller.isOpen,
          labelText: widget.decoration?.labelText,
          decoration: widget.decoration,
          enabled: widget.enabled,
          onTap: widget.enabled
              ? () {
                  unawaited(studioLightImpact());
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                }
              : null,
        );
      },
    );
    if (widget.width == null) {
      return field;
    }
    return SizedBox(width: widget.width, child: field);
  }
}

/// Toggle row that does not close the parent [MenuAnchor] (multi-select menus).
class _StudioMultiSelectMenuRow<T> extends StatelessWidget {
  const _StudioMultiSelectMenuRow({
    required this.label,
    required this.selected,
    this.child,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final Widget? child;
  final bool selected;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);

    return Padding(
      key: ValueKey<String>('studio_multi_select_$label'),
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: StudioSpacing.chromeActionGap,
      ),
      child: Material(
        color: StudioPrimitives.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          onTap: enabled
              ? () {
                  unawaited(studioLightImpact());
                  onPressed?.call();
                }
              : null,
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? tokens.primarySoft.withValues(alpha: 0.55)
                  : StudioPrimitives.transparent,
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudioLayoutSpacing.insetDense,
                vertical: StudioLayoutSpacing.inlineGap,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: enabled ? tokens.textPrimary : tokens.textMuted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      child: child ?? Text(label),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_rounded,
                      size: StudioIconSize.sm,
                      color: tokens.accent,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Divider between sections in a studio menu panel.
class StudioMenuDivider extends StatelessWidget {
  const StudioMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: StudioSpacing.chromeActionGap,
        horizontal: StudioSpacing.xs,
      ),
      child: Divider(
        height: StudioControlSize.dividerThickness,
        thickness: 1,
        color: tokens.borderSubtle,
      ),
    );
  }
}

MenuStyle studioSelectMenuStyle(BuildContext context) {
  final tokens = StudioTokens.of(context);
  return MenuStyle(
    alignment: AlignmentDirectional.topStart,
    minimumSize: const WidgetStatePropertyAll<Size>(Size(180, 0)),
    maximumSize: const WidgetStatePropertyAll<Size>(Size(double.infinity, 360)),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(
        vertical: StudioSpacing.xs,
        horizontal: StudioSpacing.xs,
      ),
    ),
    elevation: const WidgetStatePropertyAll<double>(16),
    shadowColor: WidgetStatePropertyAll<Color>(
      studioShadowColor(context, alpha: 0.42),
    ),
    backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(
      StudioPrimitives.transparent,
    ),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
    ),
  );
}

ButtonStyle studioMenuItemButtonStyle(
  BuildContext context, {
  required bool enabled,
  required bool selected,
  Color? foregroundColor,
}) {
  final tokens = StudioTokens.of(context);
  final theme = Theme.of(context);
  final typography = theme.extension<StudioTypography>();
  final resolvedForeground =
      foregroundColor ?? (enabled ? tokens.textPrimary : tokens.textMuted);

  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(double.infinity, 40)),
    padding: const WidgetStatePropertyAll<EdgeInsets>(
      EdgeInsets.symmetric(
        horizontal: StudioSpacing.sm,
        vertical: StudioSpacing.sm,
      ),
    ),
    foregroundColor: WidgetStatePropertyAll<Color>(resolvedForeground),
    backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (!enabled) {
        return StudioPrimitives.transparent;
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return tokens.primarySoft.withValues(alpha: 0.92);
      }
      if (selected) {
        return tokens.primarySoft.withValues(alpha: 0.55);
      }
      return StudioPrimitives.transparent;
    }),
    overlayColor: WidgetStatePropertyAll<Color>(
      tokens.primary.withValues(alpha: 0.08),
    ),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
      ),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(
      (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: typography?.body ?? StudioTypography.regular.body,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        height: 1.35,
        color: enabled ? tokens.textPrimary : tokens.textMuted,
      ),
    ),
  );
}

/// Menu row for studio select / action menus.
class StudioSelectMenuItem extends StatelessWidget {
  const StudioSelectMenuItem({
    super.key,
    required this.label,
    required this.selected,
    this.child,
    this.subtitle,
    this.leading,
    this.onPressed,
    this.enabled = true,
    this.foregroundColor,
    this.showCheckmark,
  });

  final String label;
  final Widget? child;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onPressed;
  final bool enabled;
  final Color? foregroundColor;
  final bool? showCheckmark;

  bool get _showsCheckmark => showCheckmark ?? selected;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);
    final resolvedForeground =
        foregroundColor ?? (enabled ? tokens.textPrimary : tokens.textMuted);
    final title = DefaultTextStyle(
      style: theme.textTheme.bodyMedium!.copyWith(
        color: resolvedForeground,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      child: child ?? Text(label),
    );
    final content = leading != null || subtitle != null
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: StudioLayoutSpacing.inlineGap),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    title,
                    if (subtitle != null) ...[
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          )
        : title;

    return MenuItemButton(
      onPressed: enabled
          ? () {
              unawaited(studioLightImpact());
              onPressed?.call();
            }
          : null,
      style: studioMenuItemButtonStyle(
        context,
        enabled: enabled,
        selected: selected,
        foregroundColor: foregroundColor,
      ),
      trailingIcon: _showsCheckmark && selected
          ? Icon(
              Icons.check_rounded,
              size: StudioIconSize.sm,
              color: tokens.accent,
            )
          : null,
      child: content,
    );
  }
}

/// Trigger surface for studio select fields.
class StudioSelectFieldTrigger extends StatelessWidget {
  const StudioSelectFieldTrigger({
    super.key,
    required this.valueLabel,
    required this.expanded,
    this.labelText,
    this.onTap,
    this.enabled = true,
    this.isDense = true,
    this.decoration,
  });

  final String? labelText;
  final String valueLabel;
  final bool expanded;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDense;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final theme = Theme.of(context);
    final hasLabel = labelText != null && labelText!.isNotEmpty;

    final field = InputDecorator(
      isEmpty: valueLabel.isEmpty,
      decoration: (decoration ?? InputDecoration()).copyWith(
        labelText: hasLabel ? labelText : decoration?.labelText,
        isDense: isDense,
        suffixIcon: AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: studioAnimationDuration(
            context,
            const Duration(milliseconds: 180),
          ),
          curve: studioAnimationCurve(context, Curves.easeOutCubic),
          child: studioDecorativeIcon(
            Icons.keyboard_arrow_down_rounded,
            color: !enabled
                ? tokens.textMuted.withValues(alpha: 0.5)
                : expanded
                ? tokens.accent
                : tokens.textMuted,
            size: StudioIconSize.xl,
          ),
        ),
      ),
      child: valueLabel.isEmpty
          ? null
          : Text(
              valueLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled ? tokens.textPrimary : tokens.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    if (!hasLabel &&
        (decoration == null || decoration!.border == InputBorder.none)) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: valueLabel,
      child: Material(
        color: StudioPrimitives.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(studioLightImpact());
                  onTap!();
                },
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.chromeActionGap,
                vertical: StudioSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      valueLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled ? tokens.textPrimary : tokens.textMuted,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: expanded ? tokens.accent : tokens.textMuted,
                    size: StudioIconSize.xl,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: hasLabel ? '$labelText: $valueLabel' : valueLabel,
      child: Material(
        color: StudioPrimitives.transparent,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(studioLightImpact());
                  onTap!();
                },
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          child: field,
        ),
      ),
    );
  }
}

String labelFromDropdownChild(Widget child) {
  if (child is Text) {
    if (child.data != null && child.data!.isNotEmpty) {
      return child.data!;
    }
    final span = child.textSpan;
    if (span != null) {
      return span.toPlainText();
    }
  }
  return '';
}
