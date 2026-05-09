import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api/search/api.dart';
import '../rust_api/core.dart';
import 'search_result_card.dart';
import 'advanced_filter_panel.dart';

/// Search results page displaying grouped search results by type.
///
/// **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.7, 9.2, 9.3, 9.4, 9.5**
///
/// Features:
/// - Display search keyword and total result count at the top
/// - Loading state with skeleton screen or loading animation
/// - Call RustApiSearch.search() to fetch results
/// - Group results by type (projects, scripts, assets)
/// - Pagination controls (previous/next page)
/// - Handle no results scenario: "未找到匹配结果,请尝试其他关键词"
/// - Handle error scenario: display error message and retry button
/// - Keyboard navigation: Arrow keys to select results, Enter to open
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    required this.accessToken,
    this.onNavigateToDetail,
  });

  /// Search query keyword
  final String query;

  /// Access token for API calls
  final String? accessToken;

  /// Callback when navigating to detail page
  /// Parameters: (resultType, id)
  final void Function(ResultType type, String id)? onNavigateToDetail;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  SearchResponse? _response;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  static const int _pageSize = 20;
  CancellationToken? _cancellationToken;

  // Filters
  SearchFilters _filters = SearchFilters.empty();
  bool _showFilterPanel = false;

  // Keyboard navigation state
  int _selectedResultIndex = -1; // -1 means no selection
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _performSearch();
    // Request focus for keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// Perform search with current filters and pagination
  Future<void> _performSearch() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = '请先登录';
        _isLoading = false;
      });
      return;
    }

    // Cancel any ongoing request
    _cancellationToken?.cancel();
    _cancellationToken = CancellationToken();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await search(
        token,
        query: widget.query,
        resultTypes: _filters.resultTypes.isEmpty ? null : _filters.resultTypes.toList(),
        page: _currentPage,
        pageSize: _pageSize,
        timeFrom: _filters.timeFrom,
        timeTo: _filters.timeTo,
        cancellationToken: _cancellationToken,
      );

      if (!mounted) return;

      setState(() {
        _response = response;
        _isLoading = false;
        _selectedResultIndex = -1; // Reset selection on new results
      });
    } on RustApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = '搜索失败: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Navigate to previous page
  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _performSearch();
    }
  }

  /// Navigate to next page
  void _nextPage() {
    if (_response?.hasMore ?? false) {
      setState(() {
        _currentPage++;
      });
      _performSearch();
    }
  }

  /// Clear all filters
  void _clearFilters() {
    setState(() {
      _filters = SearchFilters.empty();
      _currentPage = 1;
    });
    _performSearch();
  }

  /// Handle filter changes from AdvancedFilterPanel
  void _onFiltersChanged(SearchFilters newFilters) {
    setState(() {
      _filters = newFilters;
      _currentPage = 1; // Reset to first page when filters change
    });
    _performSearch();
  }

  /// Toggle filter panel visibility
  void _toggleFilterPanel() {
    setState(() {
      _showFilterPanel = !_showFilterPanel;
    });
  }

  /// Group results by type
  Map<ResultType, List<SearchResult>> _groupResultsByType() {
    final grouped = <ResultType, List<SearchResult>>{};
    
    if (_response == null) return grouped;

    for (final result in _response!.results) {
      grouped.putIfAbsent(result.resultType, () => []).add(result);
    }

    return grouped;
  }

  /// Get display name for result type
  String _getTypeDisplayName(ResultType type) {
    switch (type) {
      case ResultType.project:
        return '项目';
      case ResultType.script:
        return '剧本';
      case ResultType.asset:
        return '资产';
    }
  }

  /// Get icon for result type
  IconData _getTypeIcon(ResultType type) {
    switch (type) {
      case ResultType.project:
        return Icons.folder_outlined;
      case ResultType.script:
        return Icons.description_outlined;
      case ResultType.asset:
        return Icons.image_outlined;
    }
  }

  /// Navigate to detail page
  void _navigateToDetail(ResultType type, String id) {
    if (widget.onNavigateToDetail != null) {
      widget.onNavigateToDetail!(type, id);
    } else {
      // Default navigation logic
      String route;
      switch (type) {
        case ResultType.project:
          route = '/projects/$id';
          break;
        case ResultType.script:
          route = '/scripts/$id';
          break;
        case ResultType.asset:
          route = '/assets/$id';
          break;
      }
      Navigator.pushNamed(context, route);
    }
  }

  /// Handle keyboard navigation
  ///
  /// **Validates: Requirements 9.5**
  ///
  /// Supports:
  /// - Arrow Up: Select previous result
  /// - Arrow Down: Select next result
  /// - Enter: Open selected result detail page
  KeyEventResult _handleKeyboardNavigation(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Only handle keyboard navigation when we have results
    if (_response == null || _response!.results.isEmpty) {
      return KeyEventResult.ignored;
    }

    final totalResults = _response!.results.length;

    // Arrow Down: Select next result
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        if (_selectedResultIndex < totalResults - 1) {
          _selectedResultIndex++;
        } else {
          // Wrap to first result
          _selectedResultIndex = 0;
        }
      });
      return KeyEventResult.handled;
    }

    // Arrow Up: Select previous result
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        if (_selectedResultIndex > 0) {
          _selectedResultIndex--;
        } else if (_selectedResultIndex == -1) {
          // If no selection, select last result
          _selectedResultIndex = totalResults - 1;
        } else {
          // Wrap to last result
          _selectedResultIndex = totalResults - 1;
        }
      });
      return KeyEventResult.handled;
    }

    // Enter: Open selected result
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedResultIndex >= 0 && _selectedResultIndex < totalResults) {
        final selectedResult = _response!.results[_selectedResultIndex];
        _navigateToDetail(selectedResult.resultType, selectedResult.id);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _handleKeyboardNavigation(event),
      child: Scaffold(
        appBar: AppBar(
          title: Text('搜索: ${widget.query}'),
          actions: [
            // Filter button
            IconButton(
              icon: Badge(
                isLabelVisible: _filters.hasActiveFilters,
                label: Text('${_filters.activeFilterCount}'),
                child: const Icon(Icons.filter_list),
              ),
              onPressed: isMobile ? _showMobileFilterDrawer : _toggleFilterPanel,
              tooltip: '过滤',
            ),
            const RiskyOperationConfirmPrefsOverflowMenu(),
          ],
        ),
        body: Row(
          children: [
            // Main content
            Expanded(
              child: Column(
                children: [
                  // Search summary header
                  if (!_isLoading && _response != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '找到 ${_response!.total} 个结果',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_filters.hasActiveFilters)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear, size: 16),
                              label: const Text('清除过滤'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Main content
                  Expanded(
                    child: _buildContent(),
                  ),

                  // Pagination controls
                  if (!_isLoading && _response != null && _response!.total > 0)
                    _buildPaginationControls(),
                ],
              ),
            ),
            
            // Desktop filter panel (sidebar)
            if (!isMobile && _showFilterPanel)
              AdvancedFilterPanel(
                initialFilters: _filters,
                onFiltersChanged: _onFiltersChanged,
                isMobile: false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Loading state
    if (_isLoading) {
      return _buildLoadingState();
    }

    // Error state
    if (_error != null) {
      return _buildErrorState();
    }

    // No results state
    if (_response == null || _response!.results.isEmpty) {
      return _buildNoResultsState();
    }

    // Results grouped by type
    return _buildResultsList();
  }

  /// Build loading skeleton screen
  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 200,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build error state with retry button
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '搜索出错',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '未知错误',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no results state
  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配结果',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '请尝试其他关键词',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build results list grouped by type
  Widget _buildResultsList() {
    final grouped = _groupResultsByType();
    int currentIndex = 0;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Display results grouped by type
        for (final entry in grouped.entries) ...[
          _buildTypeHeader(entry.key, entry.value.length),
          const SizedBox(height: 8),
          ...entry.value.map((result) {
            final index = currentIndex++;
            return _buildResultCard(result, index);
          }),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Build type section header
  Widget _buildTypeHeader(ResultType type, int count) {
    return Row(
      children: [
        Icon(
          _getTypeIcon(type),
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '${_getTypeDisplayName(type)} ($count)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  /// Build individual result card
  Widget _buildResultCard(SearchResult result, int index) {
    final isSelected = index == _selectedResultIndex;
    
    return SearchResultCard(
      result: result,
      onTap: () => _navigateToDetail(result.resultType, result.id),
      isSelected: isSelected,
    );
  }

  /// Build pagination controls
  Widget _buildPaginationControls() {
    final theme = Theme.of(context);
    final hasMore = _response?.hasMore ?? false;
    final canGoPrevious = _currentPage > 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton.outlined(
            onPressed: canGoPrevious ? _previousPage : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一页',
          ),
          
          const SizedBox(width: 16),
          
          // Page indicator
          Text(
            '第 $_currentPage 页',
            style: theme.textTheme.bodyMedium,
          ),
          
          const SizedBox(width: 16),
          
          // Next button
          IconButton.outlined(
            onPressed: hasMore ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一页',
          ),
        ],
      ),
    );
  }

  /// Show filter dialog
  Future<void> _showMobileFilterDrawer() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AdvancedFilterPanel(
          initialFilters: _filters,
          onFiltersChanged: (newFilters) {
            _onFiltersChanged(newFilters);
            Navigator.of(context).pop();
          },
          isMobile: true,
        ),
      ),
    );
  }
}
