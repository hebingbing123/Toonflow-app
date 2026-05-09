import 'dart:async';
import 'package:flutter/material.dart';

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
    
    // Notify parent about the focus node for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    if (_currentFilter.isEmpty) {
      _showMessage('当前没有活动的过滤条件');
      return;
    }

    // Show dialog to input preset name
    showDialog<String>(
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
        _showMessage('预设 "$name" 已保存');
      }
    });
  }

  void _applyPreset(FilterPreset preset) {
    setState(() {
      _currentFilter = preset.filter;
      _searchController.text = preset.filter.searchKeyword;
    });
    widget.onFilterChanged(_currentFilter);
    _showMessage('已应用预设 "${preset.name}"');
  }

  void _deletePreset(FilterPreset preset) {
    final updatedPresets = widget.presets.where((p) => p != preset).toList();
    widget.onPresetsChanged?.call(updatedPresets);
    _showMessage('预设 "${preset.name}" 已删除');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: '搜索字幕或旁白内容... (Ctrl+F / Cmd+F)',
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
              
              // Save preset button
              if (hasActiveFilters)
                const SizedBox(width: 8),
              if (hasActiveFilters)
                OutlinedButton.icon(
                  onPressed: _savePreset,
                  icon: const Icon(Icons.bookmark_add, size: 18),
                  label: const Text('保存预设'),
                ),

              // Presets dropdown
              if (widget.presets.isNotEmpty) ...[
                const SizedBox(width: 8),
                PopupMenuButton<FilterPreset>(
                  tooltip: '应用预设',
                  icon: const Icon(Icons.bookmarks),
                  onSelected: _applyPreset,
                  itemBuilder: (context) => [
                    for (final preset in widget.presets)
                      PopupMenuItem<FilterPreset>(
                        value: preset,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    preset.name,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  Text(
                                    preset.description,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _deletePreset(preset);
                              },
                              tooltip: '删除预设',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
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

/// Filter preset model
class FilterPreset {
  const FilterPreset({
    required this.name,
    required this.filter,
    required this.createdAt,
  });

  /// Preset name
  final String name;

  /// Filter state
  final FilterState filter;

  /// Creation timestamp
  final DateTime createdAt;

  /// Get preset description (summary of filters)
  String get description {
    final parts = <String>[];
    
    if (filter.searchKeyword.isNotEmpty) {
      parts.add('搜索: ${filter.searchKeyword}');
    }
    
    if (filter.statusFilters.isNotEmpty) {
      parts.add('${filter.statusFilters.length}个状态');
    }
    
    if (filter.qualityFilters.isNotEmpty) {
      parts.add('${filter.qualityFilters.length}个质量');
    }
    
    return parts.isEmpty ? '无过滤条件' : parts.join(', ');
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filter': {
        'searchKeyword': filter.searchKeyword,
        'statusFilters': filter.statusFilters.map((f) => f.name).toList(),
        'qualityFilters': filter.qualityFilters.map((f) => f.name).toList(),
        'searchInSubtitles': filter.searchInSubtitles,
        'searchInVoiceover': filter.searchInVoiceover,
      },
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      name: json['name'] as String,
      filter: FilterState(
        searchKeyword: json['filter']['searchKeyword'] as String? ?? '',
        statusFilters: (json['filter']['statusFilters'] as List<dynamic>?)
                ?.map((name) => ShotStatusFilter.values.firstWhere(
                      (f) => f.name == name,
                      orElse: () => ShotStatusFilter.enabled,
                    ))
                .toSet() ??
            {},
        qualityFilters: (json['filter']['qualityFilters'] as List<dynamic>?)
                ?.map((name) => QualityFilter.values.firstWhere(
                      (f) => f.name == name,
                      orElse: () => QualityFilter.hasBadExample,
                    ))
                .toSet() ??
            {},
        searchInSubtitles: json['filter']['searchInSubtitles'] as bool? ?? true,
        searchInVoiceover: json['filter']['searchInVoiceover'] as bool? ?? true,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Dialog for saving a filter preset
class _SavePresetDialog extends StatefulWidget {
  @override
  State<_SavePresetDialog> createState() => _SavePresetDialogState();
}

class _SavePresetDialogState extends State<_SavePresetDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存过滤预设'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: '预设名称',
          hintText: '例如：已启用且有视频',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop(name);
            }
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
