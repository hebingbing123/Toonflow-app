import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../rust_api.dart';
import '../utils/localized_formatting.dart';

/// Advanced filter panel for search results
///
/// **Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 9.7**
///
/// Features:
/// - Result type multi-select (Project/Script/Asset/Novel/Novel event)
/// - Time range selector (start date, end date)
/// - Apply and clear filter buttons
/// - Display count of active filters
/// - Auto re-search when filters change
/// - Mobile responsive: collapses to drawer menu
class AdvancedFilterPanel extends StatefulWidget {
  const AdvancedFilterPanel({
    super.key,
    required this.initialFilters,
    required this.onFiltersChanged,
    this.isMobile = false,
  });

  /// Initial filter state
  final SearchFilters initialFilters;

  /// Callback when filters are changed
  final ValueChanged<SearchFilters> onFiltersChanged;

  /// Whether to use mobile layout (drawer style)
  final bool isMobile;

  @override
  State<AdvancedFilterPanel> createState() => _AdvancedFilterPanelState();
}

class _AdvancedFilterPanelState extends State<AdvancedFilterPanel> {
  late SearchFilters _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = widget.initialFilters;
  }

  @override
  void didUpdateWidget(AdvancedFilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilters != widget.initialFilters) {
      setState(() {
        _currentFilters = widget.initialFilters;
      });
    }
  }

  /// Toggle result type filter
  void _toggleResultType(ResultType type) {
    setState(() {
      final newTypes = Set<ResultType>.from(_currentFilters.resultTypes);
      if (newTypes.contains(type)) {
        newTypes.remove(type);
      } else {
        newTypes.add(type);
      }
      _currentFilters = _currentFilters.copyWith(resultTypes: newTypes);
    });
  }

  /// Set time range start date
  Future<void> _selectStartDate() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentFilters.timeFrom ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: l10n.globalSearchChooseStartDate,
      cancelText: l10n.globalSearchCancel,
      confirmText: l10n.globalSearchConfirm,
    );

    if (picked != null) {
      setState(() {
        _currentFilters = _currentFilters.copyWith(timeFrom: picked);
      });
    }
  }

  /// Set time range end date
  Future<void> _selectEndDate() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentFilters.timeTo ?? DateTime.now(),
      firstDate: _currentFilters.timeFrom ?? DateTime(2020),
      lastDate: DateTime.now(),
      helpText: l10n.globalSearchChooseEndDate,
      cancelText: l10n.globalSearchCancel,
      confirmText: l10n.globalSearchConfirm,
    );

    if (picked != null) {
      setState(() {
        _currentFilters = _currentFilters.copyWith(timeTo: picked);
      });
    }
  }

  /// Clear time range filter
  void _clearTimeRange() {
    setState(() {
      _currentFilters = _currentFilters.copyWith(
        timeFrom: null,
        timeTo: null,
        clearTimeRange: true,
      );
    });
  }

  /// Apply current filters
  void _applyFilters() {
    final l10n = resolveAppLocalizationsForErrors(context);
    widget.onFiltersChanged(_currentFilters);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.globalSearchAppliedFilters(_currentFilters.activeFilterCount)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Clear all filters
  void _clearAllFilters() {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _currentFilters = SearchFilters.empty();
    });
    widget.onFiltersChanged(_currentFilters);
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.globalSearchClearedAllFilters),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  /// Build desktop layout (sidebar panel)
  Widget _buildDesktopLayout() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: studioPanelBorderColor(context),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(),
          
          const Divider(height: 1),
          
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildFilterContent(),
            ),
          ),
          
          const Divider(height: 1),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build mobile layout (drawer style)
  Widget _buildMobileLayout() {
    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(),
          
          const Divider(height: 1),
          
          // Filter content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildFilterContent(),
            ),
          ),
          
          const Divider(height: 1),
          
          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final activeCount = _currentFilters.activeFilterCount;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.globalSearchAdvancedFilterTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          if (activeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$activeCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build filter content
  Widget _buildFilterContent() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Result type filter
        _buildSectionTitle(l10n.globalSearchResultTypeSection),
        const SizedBox(height: 8),
        _buildResultTypeFilters(),
        
        const SizedBox(height: 24),
        
        // Time range filter
        _buildSectionTitle(l10n.globalSearchCreatedTimeSection),
        const SizedBox(height: 8),
        _buildTimeRangeFilters(),
      ],
    );
  }

  /// Build section title
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: StudioTokens.of(context).textSecondary,
          ),
    );
  }

  /// Build result type filter checkboxes
  Widget _buildResultTypeFilters() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      children: [
        CheckboxListTile(
          value: _currentFilters.resultTypes.contains(ResultType.project),
          onChanged: (_) => _toggleResultType(ResultType.project),
          title: Row(
            children: [
              Icon(Icons.folder, size: 18),
              SizedBox(width: 8),
              Text(l10n.globalSearchTypeProject),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _currentFilters.resultTypes.contains(ResultType.script),
          onChanged: (_) => _toggleResultType(ResultType.script),
          title: Row(
            children: [
              Icon(Icons.description, size: 18),
              SizedBox(width: 8),
              Text(l10n.globalSearchTypeScript),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _currentFilters.resultTypes.contains(ResultType.asset),
          onChanged: (_) => _toggleResultType(ResultType.asset),
          title: Row(
            children: [
              Icon(Icons.image, size: 18),
              SizedBox(width: 8),
              Text(l10n.globalSearchTypeAsset),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _currentFilters.resultTypes.contains(ResultType.novel),
          onChanged: (_) => _toggleResultType(ResultType.novel),
          title: Row(
            children: [
              Icon(Icons.menu_book, size: 18),
              SizedBox(width: 8),
              Text(l10n.globalSearchTypeNovel),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          value: _currentFilters.resultTypes.contains(ResultType.novelEvent),
          onChanged: (_) => _toggleResultType(ResultType.novelEvent),
          title: Row(
            children: [
              Icon(Icons.event_note, size: 18),
              SizedBox(width: 8),
              Text(l10n.globalSearchTypeNovelEventOutline),
            ],
          ),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  /// Build time range filter controls
  Widget _buildTimeRangeFilters() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Start date
        OutlinedButton.icon(
          onPressed: _selectStartDate,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            _currentFilters.timeFrom != null
                ? l10n.globalSearchStartDateLabel(_formatDate(_currentFilters.timeFrom!))
                : l10n.globalSearchChooseStartDate,
            style: const TextStyle(fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // End date
        OutlinedButton.icon(
          onPressed: _selectEndDate,
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(
            _currentFilters.timeTo != null
                ? l10n.globalSearchEndDateLabel(_formatDate(_currentFilters.timeTo!))
                : l10n.globalSearchChooseEndDate,
            style: const TextStyle(fontSize: 14),
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        
        // Clear time range button
        if (_currentFilters.timeFrom != null || _currentFilters.timeTo != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearTimeRange,
            icon: const Icon(Icons.clear, size: 18),
            label: Text(l10n.globalSearchClearTimeRange),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  /// Build action buttons
  Widget _buildActionButtons() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final hasActiveFilters = _currentFilters.hasActiveFilters;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Apply filters button
          FilledButton.icon(
            onPressed: _applyFilters,
            icon: const Icon(Icons.check, size: 18),
            label: Text(l10n.globalSearchApplyFilter),
          ),
          
          const SizedBox(height: 8),
          
          // Clear filters button
          OutlinedButton.icon(
            onPressed: hasActiveFilters ? _clearAllFilters : null,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(l10n.globalSearchClearFilters),
          ),
        ],
      ),
    );
  }

  /// Format date for display using localized formatting
  String _formatDate(DateTime date) {
    return LocalizedFormatting.formatShortDate(context, date);
  }
}

/// Search filters model
class SearchFilters {
  const SearchFilters({
    this.resultTypes = const {},
    this.timeFrom,
    this.timeTo,
  });

  /// Result type filters (project, script, asset, novel, novel_event)
  final Set<ResultType> resultTypes;

  /// Time range start filter
  final DateTime? timeFrom;

  /// Time range end filter
  final DateTime? timeTo;

  /// Create empty filter state
  factory SearchFilters.empty() => const SearchFilters();

  /// Copy with new values
  SearchFilters copyWith({
    Set<ResultType>? resultTypes,
    DateTime? timeFrom,
    DateTime? timeTo,
    bool clearTimeRange = false,
  }) {
    return SearchFilters(
      resultTypes: resultTypes ?? this.resultTypes,
      timeFrom: clearTimeRange ? null : (timeFrom ?? this.timeFrom),
      timeTo: clearTimeRange ? null : (timeTo ?? this.timeTo),
    );
  }

  /// Get count of active filters
  int get activeFilterCount {
    int count = 0;
    if (resultTypes.isNotEmpty) count++;
    if (timeFrom != null || timeTo != null) count++;
    return count;
  }

  /// Check if any filters are active
  bool get hasActiveFilters => activeFilterCount > 0;

  /// Check if filters are empty
  bool get isEmpty => !hasActiveFilters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilters &&
        other.resultTypes.length == resultTypes.length &&
        other.resultTypes.every((e) => resultTypes.contains(e)) &&
        other.timeFrom == timeFrom &&
        other.timeTo == timeTo;
  }

  @override
  int get hashCode => Object.hash(
        resultTypes,
        timeFrom,
        timeTo,
      );
}
