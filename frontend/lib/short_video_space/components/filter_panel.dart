import 'dart:async';
import 'package:flutter/material.dart';

/// Filter panel component for short video assembly
/// 
/// Provides multi-dimensional filtering and search functionality:
/// - Search input field with 300ms debounce
/// - Status filter dropdown (enabled/disabled, has video, has duration, has subtitle, has voiceover)
/// - Quality filter dropdown (has bad examples, review stage, quality degradation)
/// - Active filter tags display
/// - Clear all filters button
/// - Filter preset support
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.onFilterChanged,
    this.initialFilter,
  });

  /// Callback when filter criteria changes
  final ValueChanged<FilterState> onFilterChanged;

  /// Initial filter state
  final FilterState? initialFilter;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late final TextEditingController _searchController;
  late FilterState _currentFilter;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter ?? FilterState.empty();
    _searchController = TextEditingController(text: _currentFilter.searchKeyword);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new debounce timer (300ms)
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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
    widget.onFilterChanged(_currentFilter);
  }

  void _onQualityFilterChanged(Set<QualityFilter> filters) {
    setState(() {
      _currentFilter = _currentFilter.copyWith(qualityFilters: filters);
    });
    widget.onFilterChanged(_currentFilter);
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

  List<FilterTag> _getActiveFilterTags() {
    final tags = <FilterTag>[];

    // Search keyword tag
    if (_currentFilter.searchKeyword.isNotEmpty) {
      tags.add(FilterTag(
        type: FilterTagType.search,
        label: '搜索: ${_currentFilter.searchKeyword}',
        value: _currentFilter.searchKeyword,
      ));
    }

    // Status filter tags
    for (final filter in _currentFilter.statusFilters) {
      tags.add(FilterTag(
        type: FilterTagType.status,
        label: filter.label,
        value: filter,
      ));
    }

    // Quality filter tags
    for (final filter in _currentFilter.qualityFilters) {
      tags.add(FilterTag(
        type: FilterTagType.quality,
        label: filter.label,
        value: filter,
      ));
    }

    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final activeTags = _getActiveFilterTags();
    final hasActiveFilters = activeTags.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and filter controls
          Row(
            children: [
              // Search input field
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '搜索字幕或旁白内容...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
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
              const SizedBox(width: 12),

              // Status filter dropdown
              Expanded(
                flex: 2,
                child: _StatusFilterDropdown(
                  selectedFilters: _currentFilter.statusFilters,
                  onChanged: _onStatusFilterChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Quality filter dropdown
              Expanded(
                flex: 2,
                child: _QualityFilterDropdown(
                  selectedFilters: _currentFilter.qualityFilters,
                  onChanged: _onQualityFilterChanged,
                ),
              ),
              const SizedBox(width: 12),

              // Clear all filters button
              if (hasActiveFilters)
                OutlinedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('清除'),
                ),
            ],
          ),

          // Search options
          if (_currentFilter.searchKeyword.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('搜索范围：'),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('字幕'),
                  selected: _currentFilter.searchInSubtitles,
                  onSelected: _onSearchInSubtitlesChanged,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('旁白'),
                  selected: _currentFilter.searchInVoiceover,
                  onSelected: _onSearchInVoiceoverChanged,
                ),
              ],
            ),
          ],

          // Active filter tags
          if (hasActiveFilters) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in activeTags)
                  Chip(
                    label: Text(tag.label),
                    onDeleted: () => _removeFilter(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Status filter dropdown widget
class _StatusFilterDropdown extends StatelessWidget {
  const _StatusFilterDropdown({
    required this.selectedFilters,
    required this.onChanged,
  });

  final Set<ShotStatusFilter> selectedFilters;
  final ValueChanged<Set<ShotStatusFilter>> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShotStatusFilter>(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '状态过滤',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedFilters.isEmpty
              ? '全部'
              : '已选 ${selectedFilters.length} 项',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      onSelected: (filter) {
        final newFilters = Set<ShotStatusFilter>.from(selectedFilters);
        if (newFilters.contains(filter)) {
          newFilters.remove(filter);
        } else {
          newFilters.add(filter);
        }
        onChanged(newFilters);
      },
      itemBuilder: (context) => [
        for (final filter in ShotStatusFilter.values)
          CheckedPopupMenuItem<ShotStatusFilter>(
            value: filter,
            checked: selectedFilters.contains(filter),
            child: Text(filter.label),
          ),
      ],
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
    return PopupMenuButton<QualityFilter>(
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '质量过滤',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedFilters.isEmpty
              ? '全部'
              : '已选 ${selectedFilters.length} 项',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      onSelected: (filter) {
        final newFilters = Set<QualityFilter>.from(selectedFilters);
        if (newFilters.contains(filter)) {
          newFilters.remove(filter);
        } else {
          newFilters.add(filter);
        }
        onChanged(newFilters);
      },
      itemBuilder: (context) => [
        for (final filter in QualityFilter.values)
          CheckedPopupMenuItem<QualityFilter>(
            value: filter,
            checked: selectedFilters.contains(filter),
            child: Text(filter.label),
          ),
      ],
    );
  }
}

/// Filter state model
class FilterState {
  const FilterState({
    this.searchKeyword = '',
    this.statusFilters = const {},
    this.qualityFilters = const {},
    this.searchInSubtitles = true,
    this.searchInVoiceover = true,
  });

  /// Search keyword
  final String searchKeyword;

  /// Status filters
  final Set<ShotStatusFilter> statusFilters;

  /// Quality filters
  final Set<QualityFilter> qualityFilters;

  /// Whether to search in subtitles
  final bool searchInSubtitles;

  /// Whether to search in voiceover
  final bool searchInVoiceover;

  /// Create empty filter state
  factory FilterState.empty() => const FilterState();

  /// Copy with new values
  FilterState copyWith({
    String? searchKeyword,
    Set<ShotStatusFilter>? statusFilters,
    Set<QualityFilter>? qualityFilters,
    bool? searchInSubtitles,
    bool? searchInVoiceover,
  }) {
    return FilterState(
      searchKeyword: searchKeyword ?? this.searchKeyword,
      statusFilters: statusFilters ?? this.statusFilters,
      qualityFilters: qualityFilters ?? this.qualityFilters,
      searchInSubtitles: searchInSubtitles ?? this.searchInSubtitles,
      searchInVoiceover: searchInVoiceover ?? this.searchInVoiceover,
    );
  }

  /// Check if filter is empty
  bool get isEmpty =>
      searchKeyword.isEmpty &&
      statusFilters.isEmpty &&
      qualityFilters.isEmpty;

  /// Check if filter is not empty
  bool get isNotEmpty => !isEmpty;
}

/// Shot status filter enum
enum ShotStatusFilter {
  enabled('已启用'),
  disabled('已禁用'),
  hasVideo('有视频'),
  noVideo('无视频'),
  hasDuration('有时长'),
  noDuration('无时长'),
  hasSubtitle('有字幕'),
  noSubtitle('无字幕'),
  hasVoiceover('有配音'),
  noVoiceover('无配音'),
  voiceoverFailed('配音失败');

  const ShotStatusFilter(this.label);

  final String label;
}

/// Quality filter enum
enum QualityFilter {
  hasBadExample('有坏例'),
  noBadExample('无坏例'),
  generationStage('生成阶段'),
  postProductionStage('后期阶段'),
  hasDegradation('有退化'),
  noDegradation('无退化');

  const QualityFilter(this.label);

  final String label;
}

/// Filter tag model
class FilterTag {
  const FilterTag({
    required this.type,
    required this.label,
    required this.value,
  });

  final FilterTagType type;
  final String label;
  final Object value;
}

/// Filter tag type enum
enum FilterTagType {
  search,
  status,
  quality,
}
