import 'package:flutter/material.dart';

import '../studio_typography.dart';
import '../tokens.dart';

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
    this.width = 220,
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
    final field = MenuAnchor(
      style: studioSelectMenuStyle(context),
      alignmentOffset: const Offset(0, 6),
      crossAxisUnconstrained: false,
      menuChildren: entries
          .map(
            (entry) => StudioSelectMenuItem(
              label: entry.label,
              selected: entry.value == value,
              enabled: _isEnabled && entry.enabled,
              onPressed: _isEnabled && entry.enabled
                  ? () => onChanged!(entry.value)
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
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
      EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    ),
    elevation: const WidgetStatePropertyAll<double>(16),
    shadowColor: WidgetStatePropertyAll<Color>(
      tokens.panelGlow.withValues(alpha: 0.22),
    ),
    backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
    surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
    ),
    visualDensity: VisualDensity.compact,
  );
}

/// Menu row for studio select fields.
class StudioSelectMenuItem extends StatelessWidget {
  const StudioSelectMenuItem({
    super.key,
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
    final typography = theme.extension<StudioTypography>();

    return MenuItemButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(
          Size(double.infinity, 40),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        foregroundColor: WidgetStatePropertyAll<Color>(
          enabled ? tokens.textPrimary : tokens.textMuted,
        ),
        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (!enabled) {
            return Colors.transparent;
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return tokens.primarySoft.withValues(alpha: 0.92);
          }
          if (selected) {
            return tokens.primarySoft.withValues(alpha: 0.55);
          }
          return Colors.transparent;
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
          TextStyle(
            fontSize: typography?.body ?? 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            height: 1.35,
          ),
        ),
      ),
      trailingIcon: selected
          ? Icon(Icons.check_rounded, size: 18, color: tokens.accent)
          : null,
      child: child ?? Text(label),
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: !enabled
                ? tokens.textMuted.withValues(alpha: 0.5)
                : expanded
                ? tokens.accent
                : tokens.textMuted,
            size: 22,
          ),
        ),
      ),
      child: valueLabel.isEmpty
          ? null
          : Text(
              valueLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled ? tokens.textPrimary : tokens.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
    );

    if (!hasLabel && (decoration == null || decoration!.border == InputBorder.none)) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: valueLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valueLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled ? tokens.textPrimary : tokens.textMuted,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: expanded ? tokens.accent : tokens.textMuted,
                    size: 22,
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
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
