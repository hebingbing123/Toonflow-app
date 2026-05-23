import 'package:flutter/material.dart';

/// Status / metadata chip — uses [ThemeData.chipTheme] from [buildStudioDarkTheme].
class StudioChip extends StatelessWidget {
  const StudioChip({
    super.key,
    required this.label,
    this.avatar,
    this.backgroundColor,
    this.side,
    this.padding,
    this.labelStyle,
    this.visualDensity,
    this.materialTapTargetSize,
  });

  final Widget label;
  final Widget? avatar;
  final Color? backgroundColor;
  final BorderSide? side;
  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;
  final VisualDensity? visualDensity;
  final MaterialTapTargetSize? materialTapTargetSize;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: label,
      avatar: avatar,
      backgroundColor: backgroundColor,
      side: side,
      padding: padding,
      labelStyle: labelStyle,
      visualDensity: visualDensity,
      materialTapTargetSize: materialTapTargetSize,
    );
  }
}

/// Tappable chip with [onPressed] — uses chip theme + Material 3 action styling.
class StudioActionChip extends StatelessWidget {
  const StudioActionChip({
    super.key,
    required this.label,
    this.avatar,
    this.onPressed,
    this.backgroundColor,
    this.side,
    this.padding,
    this.labelStyle,
    this.tooltip,
  });

  final Widget label;
  final Widget? avatar;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final BorderSide? side;
  final EdgeInsetsGeometry? padding;
  final TextStyle? labelStyle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: label,
      avatar: avatar,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      side: side,
      padding: padding,
      labelStyle: labelStyle,
      tooltip: tooltip,
    );
  }
}

/// Single-select choice chip.
class StudioChoiceChip extends StatelessWidget {
  const StudioChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.avatar,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.labelStyle,
    this.tooltip,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final Color? selectedColor;
  final Color? backgroundColor;
  final BorderSide? side;
  final TextStyle? labelStyle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      side: side,
      labelStyle: labelStyle,
      tooltip: tooltip,
    );
  }
}

/// Deletable input chip (filter tags).
class StudioInputChip extends StatelessWidget {
  const StudioInputChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.deleteIcon,
    this.onSelected,
    this.selected = false,
    this.avatar,
    this.backgroundColor,
    this.side,
    this.labelStyle,
  });

  final Widget label;
  final VoidCallback? onDeleted;
  final Widget? deleteIcon;
  final ValueChanged<bool>? onSelected;
  final bool selected;
  final Widget? avatar;
  final Color? backgroundColor;
  final BorderSide? side;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: label,
      onDeleted: onDeleted,
      deleteIcon: deleteIcon,
      onSelected: onSelected,
      selected: selected,
      avatar: avatar,
      backgroundColor: backgroundColor,
      side: side,
      labelStyle: labelStyle,
    );
  }
}

/// Selectable filter chip — uses [ChipTheme] pill shape from studio theme.
class StudioFilterChip extends StatelessWidget {
  const StudioFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.avatar,
    this.showCheckmark = true,
    this.selectedColor,
    this.backgroundColor,
    this.side,
    this.labelStyle,
    this.tooltip,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? avatar;
  final bool showCheckmark;
  final Color? selectedColor;
  final Color? backgroundColor;
  final BorderSide? side;
  final TextStyle? labelStyle;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
      showCheckmark: showCheckmark,
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      side: side,
      labelStyle: labelStyle,
      tooltip: tooltip,
    );
  }
}
