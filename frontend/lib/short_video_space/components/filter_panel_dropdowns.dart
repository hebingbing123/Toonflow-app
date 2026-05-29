part of 'filter_panel.dart';

class _StatusFilterDropdown extends StatelessWidget {
  const _StatusFilterDropdown({
    required this.selectedFilters,
    required this.onChanged,
  });

  final Set<ShotStatusFilter> selectedFilters;
  final ValueChanged<Set<ShotStatusFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioMultiSelectField<ShotStatusFilter>(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
      ).copyWith(labelText: l10n.shortVideoFilterPanelStatusLabel),
      valueLabel: selectedFilters.isEmpty
          ? l10n.shortVideoFilterPanelDropdownAll
          : l10n.shortVideoFilterPanelDropdownSelectedCount(
              selectedFilters.length,
            ),
      entries: [
        for (final filter in ShotStatusFilter.values)
          StudioDropdownEntry<ShotStatusFilter>(
            value: filter,
            label: filter.localizedLabel(l10n),
          ),
      ],
      selectedValues: selectedFilters,
      onChanged: onChanged,
    );
  }
}

/// Quality filter dropdown widget
class _QualityFilterDropdown extends StatelessWidget {
  const _QualityFilterDropdown({
    required this.selectedFilters,
    required this.onChanged,
  });

  final Set<QualityFilter> selectedFilters;
  final ValueChanged<Set<QualityFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioMultiSelectField<QualityFilter>(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: StudioSpacing.sm),
      ).copyWith(labelText: l10n.shortVideoFilterPanelQualityLabel),
      valueLabel: selectedFilters.isEmpty
          ? l10n.shortVideoFilterPanelDropdownAll
          : l10n.shortVideoFilterPanelDropdownSelectedCount(
              selectedFilters.length,
            ),
      entries: [
        for (final filter in QualityFilter.values)
          StudioDropdownEntry<QualityFilter>(
            value: filter,
            label: filter.localizedLabel(l10n),
          ),
      ],
      selectedValues: selectedFilters,
      onChanged: onChanged,
    );
  }
}

/// Filter state model
