import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// Column definition for [StudioTable].
class StudioTableColumn<T> {
  const StudioTableColumn({
    required this.label,
    required this.cellBuilder,
    this.flex = 1,
    this.sortable = false,
    this.semanticLabel,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final int flex;
  final bool sortable;
  final String? semanticLabel;
}

/// Sortable, selectable data table with Studio panel chrome.
class StudioTable<T> extends StatelessWidget {
  const StudioTable({
    super.key,
    required this.columns,
    required this.rows,
    this.selectedRows = const {},
    this.onSelectionChanged,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
    this.emptyLabel,
  });

  final List<StudioTableColumn<T>> columns;
  final List<T> rows;
  final Set<int> selectedRows;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;
  final String? emptyLabel;

  bool get _selectable => onSelectionChanged != null;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final emptyText = emptyLabel ?? l10n.studioDesignTableEmptyLabel;
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(StudioSpacing.md),
        child: Text(
          emptyText,
          style: studioHintStyle(context),
        ),
      );
    }

    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderRow<T>(
            columns: columns,
            selectable: _selectable,
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            onSort: onSort,
          ),
          Divider(height: 1, color: tokens.borderSubtle),
          ...List.generate(rows.length, (index) {
            final selected = selectedRows.contains(index);
            return Column(
              children: [
                _DataRow<T>(
                  index: index,
                  row: rows[index],
                  columns: columns,
                  selectable: _selectable,
                  selected: selected,
                  onSelected: _selectable
                      ? (value) {
                          final next = Set<int>.from(selectedRows);
                          if (value) {
                            next.add(index);
                          } else {
                            next.remove(index);
                          }
                          onSelectionChanged!(next);
                        }
                      : null,
                ),
                if (index < rows.length - 1)
                  Divider(height: 1, color: tokens.borderSubtle),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _HeaderRow<T> extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.selectable,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSort,
  });

  final List<StudioTableColumn<T>> columns;
  final bool selectable;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.sm,
        vertical: StudioSpacing.xs,
      ),
      child: Row(
        children: [
          if (selectable) const SizedBox(width: 40),
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].flex,
              child: _HeaderCell(
                label: columns[i].label,
                semanticLabel: columns[i].semanticLabel,
                sortable: columns[i].sortable && onSort != null,
                sorted: sortColumnIndex == i,
                ascending: sortAscending,
                onSort: columns[i].sortable && onSort != null
                    ? () {
                        final nextAsc =
                            sortColumnIndex == i ? !sortAscending : true;
                        onSort!(i, nextAsc);
                      }
                    : null,
                textColor: tokens.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    this.semanticLabel,
    required this.sortable,
    required this.sorted,
    required this.ascending,
    this.onSort,
    required this.textColor,
  });

  final String label;
  final String? semanticLabel;
  final bool sortable;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onSort;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: textColor,
      fontWeight: FontWeight.w600,
    );
    Widget labelWidget = Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (sorted) {
      labelWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: labelWidget),
          Icon(
            ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 14,
            color: textColor,
          ),
        ],
      );
    }
    if (sortable) {
      labelWidget = InkWell(
        onTap: onSort,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: labelWidget,
        ),
      );
    }
    return Semantics(
      label: semanticLabel ?? label,
      button: sortable,
      child: labelWidget,
    );
  }
}

class _DataRow<T> extends StatelessWidget {
  const _DataRow({
    required this.index,
    required this.row,
    required this.columns,
    required this.selectable,
    required this.selected,
    this.onSelected,
  });

  final int index;
  final T row;
  final List<StudioTableColumn<T>> columns;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Material(
      color: selected ? tokens.primarySoft : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.sm,
          vertical: StudioSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (selectable)
              SizedBox(
                width: 40,
                child: Checkbox(
                  value: selected,
                  onChanged: onSelected == null
                      ? null
                      : (value) => onSelected!(value ?? false),
                ),
              ),
            for (final column in columns)
              Expanded(
                flex: column.flex,
                child: column.cellBuilder(context, row),
              ),
          ],
        ),
      ),
    );
  }
}
