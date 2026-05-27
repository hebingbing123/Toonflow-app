import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_pointer.dart';

/// One action in a desktop-style context menu.
class StudioContextMenuItem {
  const StudioContextMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onSelected;
  final IconData? icon;
  final bool destructive;
  final bool enabled;
}

Future<void> _showStudioContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<StudioContextMenuItem> items,
}) async {
  final enabled = items.where((item) => item.enabled).toList(growable: false);
  if (enabled.isEmpty) return;

  final tokens = StudioTokens.of(context);
  final selected = await showMenu<int>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: <PopupMenuEntry<int>>[
      for (var i = 0; i < enabled.length; i++)
        PopupMenuItem<int>(
          value: i,
          child: Row(
            children: <Widget>[
              if (enabled[i].icon != null) ...<Widget>[
                Icon(
                  enabled[i].icon,
                  size: StudioIconSize.sm,
                  color: enabled[i].destructive
                      ? tokens.danger
                      : tokens.textSecondary,
                ),
                const SizedBox(width: StudioSpacing.xs),
              ],
              Expanded(
                child: Text(
                  enabled[i].label,
                  style: TextStyle(
                    color: enabled[i].destructive
                        ? tokens.danger
                        : tokens.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
  if (selected == null || selected < 0 || selected >= enabled.length) return;
  enabled[selected].onSelected();
}

/// Builds the standard desktop context menu for [StudioListRow].
List<StudioContextMenuItem> studioBuildListRowContextMenu({
  required BuildContext context,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
  VoidCallback? onMarkRead,
  String? markReadLabel,
  VoidCallback? onCopy,
  String? copyLabel,
  VoidCallback? onEdit,
  String? editLabel,
  VoidCallback? onRestore,
  String? restoreLabel,
  VoidCallback? onAlternate,
  String? alternateLabel,
  IconData? alternateIcon,
  VoidCallback? onDownload,
  String? downloadLabel,
  VoidCallback? onRetry,
  String? retryLabel,
  VoidCallback? onCancel,
  String? cancelLabel,
  VoidCallback? onPin,
  String? pinLabel,
  VoidCallback? onUnpin,
  String? unpinLabel,
  VoidCallback? onDelete,
  String? deleteLabel,
  List<StudioContextMenuItem>? leadingItems,
  List<StudioContextMenuItem>? trailingItems,
}) {
  final l10n = AppLocalizations.of(context);
  final items = <StudioContextMenuItem>[
    ...?leadingItems,
  ];

  void add(
    VoidCallback? action,
    String label, {
    IconData? icon,
    bool destructive = false,
  }) {
    if (action == null) return;
    items.add(
      StudioContextMenuItem(
        label: label,
        icon: icon,
        onSelected: action,
        destructive: destructive,
      ),
    );
  }

  add(
    onTap,
    l10n?.notificationsOpen ?? 'Open',
    icon: Icons.open_in_new_outlined,
  );
  add(
    onMarkRead,
    markReadLabel ?? l10n?.notificationsMarkRead ?? 'Mark read',
    icon: Icons.mark_email_read_outlined,
  );
  add(
    onPin,
    pinLabel ?? l10n?.globalSearchPinToSearchBar ?? 'Pin',
    icon: Icons.push_pin_outlined,
  );
  add(
    onUnpin,
    unpinLabel ?? l10n?.globalSearchUnpin ?? 'Unpin',
    icon: Icons.push_pin,
  );
  add(
    onCopy,
    copyLabel ?? l10n?.opsWhCopyActivityTooltip ?? 'Copy',
    icon: Icons.copy_outlined,
  );
  add(
    onEdit,
    editLabel ?? l10n?.notificationsComplianceTooltipEditTemplate ?? 'Edit',
    icon: Icons.edit_outlined,
  );
  add(
    onRestore,
    restoreLabel ?? l10n?.shortVideoVersionManagerTooltipRestoreDraft ?? 'Restore',
    icon: Icons.restore,
  );
  add(
    onAlternate,
    alternateLabel ?? l10n?.productShellMoreMenu ?? 'More',
    icon: alternateIcon ?? Icons.more_horiz,
  );
  add(
    onDownload,
    downloadLabel ?? l10n?.shortVideoSpaceDialogExportHistoryDownload ?? 'Download',
    icon: Icons.download_outlined,
  );
  add(
    onRetry,
    retryLabel ?? l10n?.shortVideoSpaceDialogExportHistoryRetry ?? 'Retry',
    icon: Icons.refresh,
  );
  add(
    onCancel,
    cancelLabel ?? l10n?.jobsCancel ?? 'Cancel',
    icon: Icons.cancel_outlined,
  );
  add(
    onLongPress,
    l10n?.productShellMoreMenu ?? 'More',
    icon: Icons.more_horiz,
  );
  if (trailingItems != null) {
    items.addAll(trailingItems);
  }
  add(
    onDelete,
    deleteLabel ?? l10n?.notificationsActionDelete ?? 'Delete',
    icon: Icons.delete_outline,
    destructive: true,
  );
  return items;
}

/// Wraps [child] with secondary-tap context menu on pointer-first devices.
class StudioContextMenu extends StatelessWidget {
  const StudioContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.enabled = true,
  });

  final Widget child;
  final List<StudioContextMenuItem> items;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || items.isEmpty) return child;
    if (!studioPointerChromeEnabled(context)) return child;

    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        if (event.buttons != kSecondaryMouseButton) return;
        _showStudioContextMenu(
          context: context,
          globalPosition: event.position,
          items: items,
        );
      },
      child: child,
    );
  }
}

/// Drop-in [ListTile] with pointer cursor, hover theme, and desktop context menu.
class StudioListRow extends StatelessWidget {
  const StudioListRow({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.isThreeLine = false,
    this.dense,
    this.visualDensity,
    this.shape,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.contentPadding,
    this.minVerticalPadding,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.focusColor,
    this.hoverColor,
    this.splashColor,
    this.tileColor,
    this.selectedTileColor,
    this.contextMenuItems,
    this.autoContextMenu = true,
    this.onMarkRead,
    this.markReadLabel,
    this.onCopy,
    this.copyLabel,
    this.onEdit,
    this.editLabel,
    this.onRestore,
    this.restoreLabel,
    this.onAlternate,
    this.alternateLabel,
    this.alternateIcon,
    this.onDownload,
    this.downloadLabel,
    this.onRetry,
    this.retryLabel,
    this.onCancel,
    this.cancelLabel,
    this.onPin,
    this.pinLabel,
    this.onUnpin,
    this.unpinLabel,
    this.onDelete,
    this.deleteLabel,
    this.leadingContextMenuItems,
    this.trailingContextMenuItems,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool isThreeLine;
  final bool? dense;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Color? selectedColor;
  final Color? iconColor;
  final Color? textColor;
  final EdgeInsetsGeometry? contentPadding;
  final double? minVerticalPadding;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Color? focusColor;
  final Color? hoverColor;
  final Color? splashColor;
  final Color? tileColor;
  final Color? selectedTileColor;
  final List<StudioContextMenuItem>? contextMenuItems;
  final bool autoContextMenu;
  final VoidCallback? onMarkRead;
  final String? markReadLabel;
  final VoidCallback? onCopy;
  final String? copyLabel;
  final VoidCallback? onEdit;
  final String? editLabel;
  final VoidCallback? onRestore;
  final String? restoreLabel;
  final VoidCallback? onAlternate;
  final String? alternateLabel;
  final IconData? alternateIcon;
  final VoidCallback? onDownload;
  final String? downloadLabel;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final VoidCallback? onPin;
  final String? pinLabel;
  final VoidCallback? onUnpin;
  final String? unpinLabel;
  final VoidCallback? onDelete;
  final String? deleteLabel;
  final List<StudioContextMenuItem>? leadingContextMenuItems;
  final List<StudioContextMenuItem>? trailingContextMenuItems;

  List<StudioContextMenuItem> _resolvedMenu(BuildContext context) {
    if (contextMenuItems != null && contextMenuItems!.isNotEmpty) {
      return contextMenuItems!;
    }
    if (!autoContextMenu) return const <StudioContextMenuItem>[];
    return studioBuildListRowContextMenu(
      context: context,
      onTap: onTap,
      onLongPress: onLongPress,
      onMarkRead: onMarkRead,
      markReadLabel: markReadLabel,
      onCopy: onCopy,
      copyLabel: copyLabel,
      onEdit: onEdit,
      editLabel: editLabel,
      onRestore: onRestore,
      restoreLabel: restoreLabel,
      onAlternate: onAlternate,
      alternateLabel: alternateLabel,
      alternateIcon: alternateIcon,
      onDownload: onDownload,
      downloadLabel: downloadLabel,
      onRetry: onRetry,
      retryLabel: retryLabel,
      onCancel: onCancel,
      cancelLabel: cancelLabel,
      onPin: onPin,
      pinLabel: pinLabel,
      onUnpin: onUnpin,
      unpinLabel: unpinLabel,
      onDelete: onDelete,
      deleteLabel: deleteLabel,
      leadingItems: leadingContextMenuItems,
      trailingItems: trailingContextMenuItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      isThreeLine: isThreeLine,
      dense: dense,
      visualDensity: visualDensity,
      shape: shape,
      selectedColor: selectedColor,
      iconColor: iconColor,
      textColor: textColor,
      contentPadding: contentPadding,
      minVerticalPadding: minVerticalPadding,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      selected: selected,
      focusColor: focusColor,
      hoverColor: hoverColor,
      splashColor: splashColor,
      tileColor: tileColor,
      selectedTileColor: selectedTileColor,
    );

    final interactive = enabled && (onTap != null || onLongPress != null);
    final wrapped = studioWrapClickCursor(
      enabled: interactive,
      child: tile,
    );

    final menu = _resolvedMenu(context);
    if (menu.isEmpty) return wrapped;

    return StudioContextMenu(
      items: menu,
      enabled: enabled,
      child: wrapped,
    );
  }
}

/// [CheckboxListTile] with pointer-first click cursor on the row.
class StudioCheckboxListRow extends StatelessWidget {
  const StudioCheckboxListRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.controlAffinity,
    this.dense,
    this.contentPadding,
    this.enabled = true,
    this.isThreeLine = false,
    this.checkboxShape,
    this.checkboxScaleFactor,
    this.autofocus = false,
    this.tristate = false,
    this.selected = false,
    this.visualDensity,
    this.shape,
    this.tileColor,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final ListTileControlAffinity? controlAffinity;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final bool isThreeLine;
  final OutlinedBorder? checkboxShape;
  final double? checkboxScaleFactor;
  final bool autofocus;
  final bool tristate;
  final bool selected;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    return studioWrapClickCursor(
      enabled: interactive,
      child: CheckboxListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        controlAffinity: controlAffinity,
        dense: dense,
        contentPadding: contentPadding,
        isThreeLine: isThreeLine,
        checkboxShape: checkboxShape,
        checkboxScaleFactor: checkboxScaleFactor ?? 1.0,
        autofocus: autofocus,
        tristate: tristate,
        selected: selected,
        visualDensity: visualDensity,
        shape: shape,
        tileColor: tileColor,
      ),
    );
  }
}

/// [SwitchListTile] with pointer-first click cursor on the row.
class StudioSwitchListRow extends StatelessWidget {
  const StudioSwitchListRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.controlAffinity,
    this.dense,
    this.contentPadding,
    this.enabled = true,
    this.autofocus = false,
    this.selected = false,
    this.visualDensity,
    this.shape,
    this.tileColor,
    this.thumbIcon,
    this.trackOutlineColor,
    this.trackColor,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final ListTileControlAffinity? controlAffinity;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool enabled;
  final bool autofocus;
  final bool selected;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final Color? tileColor;
  final WidgetStateProperty<Icon?>? thumbIcon;
  final WidgetStateProperty<Color?>? trackOutlineColor;
  final WidgetStateProperty<Color?>? trackColor;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    return studioWrapClickCursor(
      enabled: interactive,
      child: SwitchListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        controlAffinity: controlAffinity,
        dense: dense,
        contentPadding: contentPadding,
        autofocus: autofocus,
        selected: selected,
        visualDensity: visualDensity,
        shape: shape,
        tileColor: tileColor,
        thumbIcon: thumbIcon,
        trackOutlineColor: trackOutlineColor,
        trackColor: trackColor,
      ),
    );
  }
}
