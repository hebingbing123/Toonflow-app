import 'dart:async';
import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';
import '../../design_system/components/studio_icon_button.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_collapsible_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_filter_row.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/studio_scheduler.dart';
import 'package:openflow_app/design_system/tokens.dart';

/// Filter panel component for short video assembly
/// 
/// Provides multi-dimensional filtering and search functionality:
/// - Search input field with 300ms debounce
/// - Status filter dropdown with 200ms debounce (enabled/disabled, has video, has duration, has subtitle, has voiceover)
/// - Quality filter dropdown with 200ms debounce (has bad examples, review stage, quality degradation)
/// - Active filter tags display
/// - Clear all filters button
/// - Filter preset support (save, load, delete presets)
/// 
/// ## Filter Preset Usage
/// 
/// Filter presets allow users to save commonly used filter combinations for quick access:
/// 
/// 1. **Save Preset**: When filters are active, click "保存预设" button to save current filters
/// 2. **Apply Preset**: Click the bookmarks icon to see saved presets and select one to apply
/// 3. **Delete Preset**: In the presets dropdown, click the delete icon next to a preset to remove it
/// 4. **Clear Filters**: Click "清除" button to remove all active filters
/// 
/// Example:
/// ```dart
/// FilterPanel(
///   initialFilter: FilterState.empty(),
///   onFilterChanged: (filter) {
///     // Handle filter changes
///   },
///   presets: savedPresets,
///   onPresetsChanged: (newPresets) {
///     // Save presets to persistent storage
///   },
/// )
/// ```
part 'filter_panel_dropdowns.dart';
part 'filter_panel_types.dart';
part 'filter_panel_presets.dart';

class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.onFilterChanged,
    this.initialFilter,
    this.presets = const [],
    this.onPresetsChanged,
    this.onSearchFocusNodeCreated,
  });

  /// Callback when filter criteria changes
  final ValueChanged<FilterState> onFilterChanged;

  /// Initial filter state
  final FilterState? initialFilter;

  /// List of saved filter presets
  final List<FilterPreset> presets;

  /// Callback when presets are modified (save/delete)
  final ValueChanged<List<FilterPreset>>? onPresetsChanged;

  /// Callback when search focus node is created (for keyboard shortcuts)
  final ValueChanged<FocusNode>? onSearchFocusNodeCreated;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late FilterState _currentFilter;
  Timer? _searchDebounceTimer;
  Timer? _filterDebounceTimer;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter ?? FilterState.empty();
    _searchController = TextEditingController(text: _currentFilter.searchKeyword);
    _searchFocusNode = FocusNode();
    
    StudioScheduler.scheduleOnceUntil('short_video_filter_search_focus', () {
      widget.onSearchFocusNodeCreated?.call(_searchFocusNode);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    _filterDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Start new debounce timer (300ms)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentFilter = _currentFilter.copyWith(searchKeyword: value.trim());
      });
      widget.onFilterChanged(_currentFilter);
    });
  }

  void _onStatusFilterChanged(Set<ShotStatusFilter> filters) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(statusFilters: filters);
    });
    
    // Cancel previous filter debounce timer
    _filterDebounceTimer?.cancel();
    
    // Start new debounce timer (200ms) for filter changes
    _filterDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onFilterChanged(_currentFilter);
    });
  }

  void _onQualityFilterChanged(Set<QualityFilter> filters) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(qualityFilters: filters);
    });
    
    // Cancel previous filter debounce timer
    _filterDebounceTimer?.cancel();
    
    // Start new debounce timer (200ms) for filter changes
    _filterDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      widget.onFilterChanged(_currentFilter);
    });
  }

  void _onSearchInSubtitlesChanged(bool value) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(searchInSubtitles: value);
    });
    widget.onFilterChanged(_currentFilter);
  }

  void _onSearchInVoiceoverChanged(bool value) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(searchInVoiceover: value);
    });
    widget.onFilterChanged(_currentFilter);
  }

  void _removeFilter(FilterTag tag) {
    setState(() {
      switch (tag.type) {
        case FilterTagType.status:
          final newFilters = Set<ShotStatusFilter>.from(_currentFilter.statusFilters);
          newFilters.remove(tag.value as ShotStatusFilter);
          _currentFilter = _currentFilter.copyWith(statusFilters: newFilters);
          break;
        case FilterTagType.quality:
          final newFilters = Set<QualityFilter>.from(_currentFilter.qualityFilters);
          newFilters.remove(tag.value as QualityFilter);
          _currentFilter = _currentFilter.copyWith(qualityFilters: newFilters);
          break;
        case FilterTagType.search:
          _searchController.clear();
          _currentFilter = _currentFilter.copyWith(searchKeyword: '');
          break;
      }
    });
    widget.onFilterChanged(_currentFilter);
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _currentFilter = FilterState.empty();
    });
    widget.onFilterChanged(_currentFilter);
  }

  void _savePreset() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (_currentFilter.isEmpty) {
      _showMessage(l10n.shortVideoFilterSnackbarNoActiveFilters);
      return;
    }

    // Show dialog to input preset name
    showStudioDialog<String>(
      context: context,
      builder: (context) => _SavePresetDialog(),
    ).then((name) {
      if (name != null && name.isNotEmpty) {
        final newPreset = FilterPreset(
          name: name,
          filter: _currentFilter,
          createdAt: DateTime.now(),
        );
        final updatedPresets = [...widget.presets, newPreset];
        widget.onPresetsChanged?.call(updatedPresets);
        _showMessage(l10n.shortVideoFilterSnackbarPresetSaved(name));
      }
    });
  }

  void _applyPreset(FilterPreset preset) {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _currentFilter = preset.filter;
      _searchController.text = preset.filter.searchKeyword;
    });
    widget.onFilterChanged(_currentFilter);
    _showMessage(l10n.shortVideoFilterSnackbarPresetApplied(preset.name));
  }

  void _deletePreset(FilterPreset preset) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final updatedPresets = widget.presets.where((p) => p != preset).toList();
    widget.onPresetsChanged?.call(updatedPresets);
    _showMessage(l10n.shortVideoFilterSnackbarPresetDeleted(preset.name));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<FilterTag> _getActiveFilterTags(AppLocalizations l10n) {
    final tags = <FilterTag>[];

    // Search keyword tag
    if (_currentFilter.searchKeyword.isNotEmpty) {
      tags.add(FilterTag(
        type: FilterTagType.search,
        label: l10n.shortVideoFilterActiveTagSearch(_currentFilter.searchKeyword),
        value: _currentFilter.searchKeyword,
      ));
    }

    // Status filter tags
    for (final filter in _currentFilter.statusFilters) {
      tags.add(FilterTag(
        type: FilterTagType.status,
        label: filter.localizedLabel(l10n),
        value: filter,
      ));
    }

    // Quality filter tags
    for (final filter in _currentFilter.qualityFilters) {
      tags.add(FilterTag(
        type: FilterTagType.quality,
        label: filter.localizedLabel(l10n),
        value: filter,
      ));
    }

    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final activeTags = _getActiveFilterTags(l10n);
    final hasActiveFilters = activeTags.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: studioPanelBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: StudioCollapsibleFilterPanel(
        subtitle: hasActiveFilters
            ? l10n.shortVideoFilterPanelDropdownSelectedCount(activeTags.length)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudioFilterRow(
              wideLayout: StudioFilterWideLayout.toolbarRow,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.shortVideoFilterPanelSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? StudioIconButton(
                              icon: Icons.clear,
                              label: MaterialLocalizations.of(context).clearButtonTooltip,
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _StatusFilterDropdown(
                    selectedFilters: _currentFilter.statusFilters,
                    onChanged: _onStatusFilterChanged,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _QualityFilterDropdown(
                    selectedFilters: _currentFilter.qualityFilters,
                    onChanged: _onQualityFilterChanged,
                  ),
                ),
                if (hasActiveFilters)
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: _clearAllFilters,
                    icon: const Icon(Icons.clear_all, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoFilterPanelClearButton),
                  ),
                if (hasActiveFilters)
                  OutlinedButton.icon(
                    style: studioFormOutlinedIconLabeledButtonStyle(context),
                    onPressed: _savePreset,
                    icon: const Icon(Icons.bookmark_add, size: StudioIconSize.sm),
                    label: Text(l10n.shortVideoFilterPanelSavePresetButton),
                  ),
                if (widget.presets.isNotEmpty)
                  StudioMenuAnchor(
                    menuChildren: [
                      for (final preset in widget.presets)
                        Builder(
                          builder: (menuContext) {
                            final menuController =
                                MenuController.maybeOf(menuContext);
                            final theme = Theme.of(menuContext);
                            final tokens = StudioTokens.of(menuContext);
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Material(
                                color: StudioPrimitives.transparent,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          StudioSpacing.radiusButton,
                                        ),
                                        onTap: () {
                                          menuController?.close();
                                          _applyPreset(preset);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                preset.name,
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                  color: tokens.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                preset.summarize(l10n),
                                                style: theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                  color: tokens.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    StudioIconButton(
                                      icon: Icons.delete,
                                      label: l10n
                                          .shortVideoFilterPanelDeletePresetTooltip,
                                      onPressed: () {
                                        menuController?.close();
                                        _deletePreset(preset);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                    builder: (context, controller, child) {
                      return StudioIconButton(
                        icon: Icons.bookmarks,
                        label: l10n.shortVideoFilterPanelApplyPresetTooltip,
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                      );
                    },
                  ),
              ],
            ),

          // Search options
          if (_currentFilter.searchKeyword.isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.xs),
            Wrap(
              spacing: StudioSpacing.xs,
              runSpacing: StudioSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.shortVideoFilterPanelSearchScopeLabel),
                StudioFilterChip(
                  label: Text(l10n.shortVideoFilterPanelSearchChipSubtitle),
                  selected: _currentFilter.searchInSubtitles,
                  onSelected: _onSearchInSubtitlesChanged,
                ),
                StudioFilterChip(
                  label: Text(l10n.shortVideoFilterPanelSearchChipVoiceover),
                  selected: _currentFilter.searchInVoiceover,
                  onSelected: _onSearchInVoiceoverChanged,
                ),
              ],
            ),
          ],

          // Active filter tags
          if (hasActiveFilters) ...[
            const SizedBox(height: StudioSpacing.sm),
            Wrap(
              spacing: StudioSpacing.xs,
              runSpacing: StudioSpacing.xs,
              children: [
                for (final tag in activeTags)
                  StudioInputChip(
                    label: Text(tag.label),
                    onDeleted: () => _removeFilter(tag),
                    deleteIcon: const Icon(Icons.close, size: StudioIconSize.sm),
                  ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}

/// Status filter dropdown widget
