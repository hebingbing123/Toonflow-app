import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api/search/api.dart';
import '../rust_api/search/saved_views.dart';
import 'search_result_card.dart';
import 'advanced_filter_panel.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/layout_breakpoints.dart';
import 'package:openflow_app/design_system/tokens.dart';

/// Search results page displaying grouped search results by type.
///
/// **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.7, 9.2, 9.3, 9.4, 9.5**
///
/// Features:
/// - Display search keyword and total result count at the top
/// - Loading state with skeleton screen or loading animation
/// - Call RustApiSearch.search() to fetch results
/// - Group results by type (projects, scripts, assets, novels, novel events)
/// - Pagination controls (previous/next page)
/// - Handle no results scenario: "未找到匹配结果,请尝试其他关键词"
/// - Handle error scenario: display error message and retry button
/// - Keyboard navigation: Arrow keys to select results, Enter to open
class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({
    super.key,
    required this.query,
    required this.accessToken,
    this.currentWorkspaceName,
    this.currentWorkspaceId,
    this.initialResultTypes = const <ResultType>[],
    this.initialTimeFrom,
    this.initialTimeTo,
    this.onNavigateToDetail,
  });

  /// Search query keyword
  final String query;

  /// Access token for API calls
  final String? accessToken;
  final String? currentWorkspaceName;
  final String? currentWorkspaceId;
  final List<ResultType> initialResultTypes;
  final DateTime? initialTimeFrom;
  final DateTime? initialTimeTo;

  /// Callback when navigating to detail page.
  /// [metadata] 来自服务端（如 `project_numeric_id`、`project_id` UUID）。
  final void Function(
    ResultType type,
    String id, {
    Map<String, dynamic>? metadata,
  })?
  onNavigateToDetail;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  static const _savedSearchViewsKey = 'global_search.saved_views.v1';
  SearchResponse? _response;
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  static const int _pageSize = 20;
  CancellationToken? _cancellationToken;

  // Filters
  SearchFilters _filters = SearchFilters.empty();
  bool _showFilterPanel = false;
  bool _didScheduleInitialSearch = false;

  // Keyboard navigation state
  int _selectedResultIndex = -1; // -1 means no selection
  final FocusNode _focusNode = FocusNode();

  static const List<_SearchViewTemplate> _templates = <_SearchViewTemplate>[
    _SearchViewTemplate(id: 'recent-7d', daysBack: 7),
    _SearchViewTemplate(
      id: 'projects-30d',
      resultTypes: <ResultType>{ResultType.project},
      daysBack: 30,
    ),
    _SearchViewTemplate(
      id: 'scripts-30d',
      resultTypes: <ResultType>{ResultType.script},
      daysBack: 30,
    ),
    _SearchViewTemplate(
      id: 'assets-30d',
      resultTypes: <ResultType>{ResultType.asset},
      daysBack: 30,
    ),
  ];

  String _searchViewTemplateLabel(
    AppLocalizations l10n,
    _SearchViewTemplate template,
  ) {
    switch (template.id) {
      case 'recent-7d':
        return l10n.globalSearchTemplateRecent7d;
      case 'projects-30d':
        return l10n.globalSearchTemplateProjects30d;
      case 'scripts-30d':
        return l10n.globalSearchTemplateScripts30d;
      case 'assets-30d':
        return l10n.globalSearchTemplateAssets30d;
      default:
        return template.id;
    }
  }

  @override
  void initState() {
    super.initState();
    _filters = SearchFilters(
      resultTypes: widget.initialResultTypes.toSet(),
      timeFrom: widget.initialTimeFrom,
      timeTo: widget.initialTimeTo,
    );
    final token = widget.accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      // First frame shows loading skeleton (avoid a flash of empty-state before setState).
      _isLoading = true;
    }
    // Request focus for keyboard navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    unawaited(_pullRemoteSavedViewsIntoPrefs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleInitialSearch) {
      return;
    }
    _didScheduleInitialSearch = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_performSearch());
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = l10n.globalSearchErrSignInFirst;
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
        l10n: l10n,
        query: widget.query,
        resultTypes: _filters.resultTypes.isEmpty
            ? null
            : _filters.resultTypes.toList(),
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = l10n.globalSearchErrSearchFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
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

  Future<void> _copySearchLink() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final queryParts = <String>[
      'q=${Uri.encodeQueryComponent(widget.query)}',
      ..._filters.resultTypes.map(
        (item) => 'type=${Uri.encodeQueryComponent(item.wireName)}',
      ),
      if (_filters.timeFrom != null)
        'timeFrom=${Uri.encodeQueryComponent(_filters.timeFrom!.toUtc().toIso8601String())}',
      if (_filters.timeTo != null)
        'timeTo=${Uri.encodeQueryComponent(_filters.timeTo!.toUtc().toIso8601String())}',
    ];
    final uri = Uri.parse('/product/search?${queryParts.join('&')}');
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.globalSearchCopiedDeepLink)));
  }

  String _formatFilterDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }

  String _buildDefaultViewTitle() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final workspace = (widget.currentWorkspaceName ?? '').trim();
    final typeJoiner = l10n.globalSearchViewTitleTypesJoiner;
    final typeSummary = _filters.resultTypes.isEmpty
        ? l10n.globalSearchAllTypes
        : _filters.resultTypes.map(_getTypeDisplayName).join(typeJoiner);
    final timeSummary = (_filters.timeFrom != null || _filters.timeTo != null)
        ? l10n.globalSearchViewTitleTimeRange(
            _filters.timeFrom != null
                ? _formatFilterDate(_filters.timeFrom!)
                : l10n.globalSearchTimeStart,
            _filters.timeTo != null
                ? _formatFilterDate(_filters.timeTo!)
                : l10n.globalSearchTimeNow,
          )
        : l10n.globalSearchAllTime;
    final querySummary = widget.query.length > 18
        ? '${widget.query.substring(0, 18)}${l10n.globalSearchQueryTruncationSuffix}'
        : widget.query;
    final sep = l10n.globalSearchViewTitlePartSeparator;
    if (workspace.isNotEmpty) {
      return [workspace, typeSummary, timeSummary, querySummary].join(sep);
    }
    return [typeSummary, timeSummary, querySummary].join(sep);
  }

  void _applyTemplate(_SearchViewTemplate template) {
    final now = DateTime.now();
    final nextFilters = SearchFilters(
      resultTypes: template.resultTypes,
      timeFrom: template.daysBack == null
          ? null
          : DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: template.daysBack!)),
      timeTo: now,
    );
    _onFiltersChanged(nextFilters);
  }

  ResultType? _resultTypeFromWireName(String raw) {
    switch (raw) {
      case 'project':
        return ResultType.project;
      case 'script':
        return ResultType.script;
      case 'asset':
        return ResultType.asset;
      case 'novel':
        return ResultType.novel;
      case 'novel_event':
        return ResultType.novelEvent;
      default:
        return null;
    }
  }

  Future<void> _pullRemoteSavedViewsIntoPrefs() async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final remote = await getSearchSavedViews(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _savedSearchViewsKey,
        jsonEncode(remote.map((SearchSavedViewItem e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _pushSavedViewsToServer() async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedSearchViewsKey);
      if (raw == null || raw.isEmpty) {
        await putSearchSavedViews(token, const <SearchSavedViewItem>[]);
        return;
      }
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map(
            (dynamic item) => SearchSavedViewItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      await putSearchSavedViews(token, items);
    } catch (_) {}
  }

  Future<List<_SavedSearchView>> _loadSavedViews() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedSearchViewsKey);
      if (raw == null || raw.isEmpty) {
        return const <_SavedSearchView>[];
      }
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => _SavedSearchView.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <_SavedSearchView>[];
    }
  }

  Future<void> _persistSavedViews(List<_SavedSearchView> views) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedSearchViewsKey,
      jsonEncode(views.map((item) => item.toJson()).toList(growable: false)),
    );
    unawaited(_pushSavedViewsToServer());
  }

  List<_SavedSearchView> _sortSavedViews(List<_SavedSearchView> views) {
    final next = List<_SavedSearchView>.from(views);
    next.sort((a, b) {
      final bTime = b.lastUsedAt ?? b.updatedAt;
      final aTime = a.lastUsedAt ?? a.updatedAt;
      final byTime = bTime.compareTo(aTime);
      if (byTime != 0) {
        return byTime;
      }
      return b.useCount.compareTo(a.useCount);
    });
    return next;
  }

  String _formatSavedViewTimestamp(DateTime? value) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (value == null) {
      return l10n.globalSearchNeverUsed;
    }
    final local = value.toLocal();
    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCurrentView() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final titleController = TextEditingController(
      text: _buildDefaultViewTitle(),
    );
    final approved = await showStudioDialog<bool>(
      context: context,
      builder: (dialogContext) => StudioAlertDialog(
        title: Text(l10n.globalSearchSaveViewTitle),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.globalSearchViewNameField,
            hintText: l10n.globalSearchViewNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.globalSearchCancel),
          ),
          FilledButton(
            style: studioFormPrimaryButtonStyle(dialogContext),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.globalSearchSave),
          ),
        ],
      ),
    );
    if (approved != true) {
      return;
    }
    final title = titleController.text.trim();
    if (title.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.globalSearchViewNameRequired)),
      );
      return;
    }
    final current = await _loadSavedViews();
    _SavedSearchView? existing;
    for (final item in current) {
      if (item.title == title) {
        existing = item;
        break;
      }
    }
    final now = DateTime.now();
    final next = _sortSavedViews(
      <_SavedSearchView>[
        _SavedSearchView(
          id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
          title: title,
          query: widget.query,
          workspaceName: widget.currentWorkspaceName,
          workspaceId: widget.currentWorkspaceId ?? existing?.workspaceId,
          pinned: existing?.pinned ?? false,
          resultTypes: _filters.resultTypes
              .map((item) => item.wireName)
              .toList(growable: false),
          timeFrom: _filters.timeFrom,
          timeTo: _filters.timeTo,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          lastUsedAt: existing?.lastUsedAt,
          useCount: existing?.useCount ?? 0,
        ),
        ...current.where((item) => item.title != title),
      ].take(20).toList(growable: false),
    );
    await _persistSavedViews(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.globalSearchViewSaved)));
  }

  Future<void> _openSavedViews() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final views = _sortSavedViews(await _loadSavedViews());
    if (!mounted) {
      return;
    }
    await showStudioBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (views.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(24),
            child: Text(l10n.globalSearchNoSavedViews),
          );
        }
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: views
                .map(
                  (view) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      view.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        view.query,
                        if ((view.workspaceName ?? '').isNotEmpty)
                          l10n.globalSearchSavedViewWorkspaceLine(
                            view.workspaceName!.trim(),
                          ),
                        if (view.resultTypes.isNotEmpty)
                          l10n.globalSearchSavedViewTypesLine(
                            view.resultTypes.join(','),
                          ),
                        if (view.timeFrom != null || view.timeTo != null)
                          l10n.globalSearchTimeChip(
                            view.timeFrom != null
                                ? _formatFilterDate(view.timeFrom!)
                                : l10n.globalSearchTimeStart,
                            view.timeTo != null
                                ? _formatFilterDate(view.timeTo!)
                                : l10n.globalSearchTimeNow,
                          ),
                        l10n.globalSearchSavedUsed(view.useCount),
                        l10n.globalSearchSavedViewLastUsedLine(
                          _formatSavedViewTimestamp(view.lastUsedAt),
                        ),
                        if (view.pinned) l10n.globalSearchPinned,
                      ].join(' · '),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(
                            view.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                          ),
                          tooltip: view.pinned
                              ? l10n.globalSearchUnpin
                              : l10n.globalSearchPinToSearchBar,
                          onPressed: () async {
                            final next = _sortSavedViews(
                              views
                                  .map(
                                    (item) => item.id == view.id
                                        ? item.copyWith(pinned: !item.pinned)
                                        : item,
                                  )
                                  .toList(growable: false),
                            );
                            await _persistSavedViews(next);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  view.pinned
                                      ? l10n.globalSearchUnpinnedView
                                      : l10n.globalSearchPinnedToSearchBar,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.globalSearchDelete,
                          onPressed: () async {
                            final next = views
                                .where((item) => item.id != view.id)
                                .toList(growable: false);
                            await _persistSavedViews(next);
                            if (!sheetContext.mounted) {
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.globalSearchViewDeleted),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      final now = DateTime.now();
                      final updatedViews = _sortSavedViews(
                        views
                            .map(
                              (item) => item.id == view.id
                                  ? item.copyWith(
                                      lastUsedAt: now,
                                      useCount: item.useCount + 1,
                                    )
                                  : item,
                            )
                            .toList(growable: false),
                      );
                      unawaited(_persistSavedViews(updatedViews));
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (context) => SearchResultsPage(
                            query: view.query,
                            accessToken: widget.accessToken,
                            currentWorkspaceName: view.workspaceName,
                            currentWorkspaceId:
                                view.workspaceId ?? widget.currentWorkspaceId,
                            initialResultTypes: view.resultTypes
                                .map(_resultTypeFromWireName)
                                .whereType<ResultType>()
                                .toList(growable: false),
                            initialTimeFrom: view.timeFrom,
                            initialTimeTo: view.timeTo,
                            onNavigateToDetail: widget.onNavigateToDetail,
                          ),
                        ),
                      );
                    },
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  void _toggleHeaderResultType(ResultType type) {
    final next = Set<ResultType>.from(_filters.resultTypes);
    if (next.contains(type)) {
      next.remove(type);
    } else {
      next.add(type);
    }
    _onFiltersChanged(_filters.copyWith(resultTypes: next));
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
    final l10n = resolveAppLocalizationsForErrors(context);
    switch (type) {
      case ResultType.project:
        return l10n.globalSearchTypeProject;
      case ResultType.script:
        return l10n.globalSearchTypeScript;
      case ResultType.asset:
        return l10n.globalSearchTypeAsset;
      case ResultType.novel:
        return l10n.globalSearchTypeNovel;
      case ResultType.novelEvent:
        return l10n.globalSearchTypeNovelEvent;
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
      case ResultType.novel:
        return Icons.menu_book_outlined;
      case ResultType.novelEvent:
        return Icons.event_note_outlined;
    }
  }

  /// Navigate to detail page
  void _navigateToDetail(SearchResult result) {
    if (widget.onNavigateToDetail != null) {
      widget.onNavigateToDetail!(
        result.resultType,
        result.id,
        metadata: result.metadata,
      );
    } else {
      // Default navigation logic（主导航未注入回调时的兜底）
      switch (result.resultType) {
        case ResultType.project:
          unawaited(Navigator.pushNamed(context, '/projects/${result.id}'));
          break;
        case ResultType.script:
          unawaited(Navigator.pushNamed(context, '/scripts/${result.id}'));
          break;
        case ResultType.asset:
          unawaited(Navigator.pushNamed(context, '/assets/${result.id}'));
          break;
        case ResultType.novel:
        case ResultType.novelEvent:
          if (!context.mounted) {
            return;
          }
          final loc = resolveAppLocalizationsForErrors(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.globalSearchNovelOrEventNavigatedHint)),
          );
          break;
      }
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
        _navigateToDetail(selectedResult);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < kStudioHandsetMaxWidth;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) => _handleKeyboardNavigation(event),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(l10n.globalSearchTitle(widget.query)),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_add_outlined),
              onPressed: _saveCurrentView,
              tooltip: l10n.globalSearchTooltipSaveCurrentView,
            ),
            IconButton(
              icon: const Icon(Icons.collections_bookmark_outlined),
              onPressed: _openSavedViews,
              tooltip: l10n.globalSearchTooltipSavedViews,
            ),
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: _copySearchLink,
              tooltip: l10n.globalSearchTooltipCopyDeepLink,
            ),
            // Filter button
            IconButton(
              icon: Badge(
                isLabelVisible: _filters.hasActiveFilters,
                label: Text(l10n.l10nBatch_775383c7b6(_filters.activeFilterCount)),
                child: const Icon(Icons.filter_list),
              ),
              onPressed: isMobile
                  ? _showMobileFilterDrawer
                  : _toggleFilterPanel,
              tooltip: l10n.globalSearchTooltipFilter,
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
                            color: studioPanelBorderColor(context),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: StudioTokens.of(context).textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.globalSearchFoundResults(_response!.total),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: StudioTokens.of(context).textSecondary,
                              ),
                            ),
                          ),
                          if (_filters.hasActiveFilters)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear_outlined),
                              label: Text(l10n.globalSearchClearFilters),
                              style: studioFormTextButtonIconStyle(context),
                            ),
                        ],
                      ),
                    ),
                  if (!_isLoading &&
                      _response != null &&
                      (_filters.timeFrom != null || _filters.timeTo != null))
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StudioChip(
                          label: Text(
                            l10n.globalSearchTimeChip(
                              _filters.timeFrom != null
                                  ? _formatFilterDate(_filters.timeFrom!)
                                  : l10n.globalSearchTimeStart,
                              _filters.timeTo != null
                                  ? _formatFilterDate(_filters.timeTo!)
                                  : l10n.globalSearchTimeNow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_isLoading && _response != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: studioPanelBorderColor(context),
                          ),
                        ),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in const <ResultType>[
                            ResultType.project,
                            ResultType.script,
                            ResultType.asset,
                            ResultType.novel,
                            ResultType.novelEvent,
                          ])
                            StudioFilterChip(
                              avatar: Icon(_getTypeIcon(type), size: 16),
                              label: Text(
                                l10n.globalSearchTypeCountChipLabel(
                                  _getTypeDisplayName(type),
                                  _groupResultsByType()[type]?.length ?? 0,
                                ),
                              ),
                              selected: _filters.resultTypes.contains(type),
                              onSelected: (_) => _toggleHeaderResultType(type),
                            ),
                        ],
                      ),
                    ),
                  if (!_isLoading && _response != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _templates
                            .map(
                              (template) => StudioActionChip(
                                label: Text(
                                  _searchViewTemplateLabel(l10n, template),
                                ),
                                onPressed: () => _applyTemplate(template),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),

                  // Main content
                  Expanded(child: _buildContent()),

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
    // Eager children (not ListView.builder) so first frame builds placeholders.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List<Widget>.generate(
        6,
        (index) => Card(
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
                        color: StudioTokens.of(context).borderSubtle,
                        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                      ),
                    ),
                    const SizedBox(width: StudioSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 16,
                            decoration: BoxDecoration(
                              color: StudioTokens.of(context).borderSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: StudioSpacing.xs),
                          Container(
                            width: 200,
                            height: 12,
                            decoration: BoxDecoration(
                              color: StudioTokens.of(context).borderSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StudioSpacing.sm),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: StudioTokens.of(context).borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: StudioTokens.of(context).borderSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build error state with retry button
  Widget _buildErrorState() {
    final l10n = resolveAppLocalizationsForErrors(context);
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
              l10n.globalSearchErrorTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? l10n.globalSearchUnknownError,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StudioTokens.of(context).textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: studioFormIconLabeledButtonStyle(context),
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.globalSearchRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// Build no results state
  Widget _buildNoResultsState() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioEmptyState.noResults(
      title: l10n.globalSearchNoResultsTitle,
      subtitle: l10n.globalSearchNoResultsHint,
    );
  }

  /// Build results list grouped by type
  Widget _buildResultsList() {
    final grouped = _groupResultsByType();
    int currentIndex = 0;
    const typeOrder = <ResultType>[
      ResultType.project,
      ResultType.script,
      ResultType.asset,
      ResultType.novel,
      ResultType.novelEvent,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final t in typeOrder) ...[
          if (grouped[t] != null && grouped[t]!.isNotEmpty) ...[
            _buildTypeHeader(t, grouped[t]!.length),
            const SizedBox(height: 8),
            ...grouped[t]!.map((result) {
              final index = currentIndex++;
              return _buildResultCard(result, index);
            }),
            const SizedBox(height: 24),
          ],
        ],
      ],
    );
  }

  /// Build type section header
  Widget _buildTypeHeader(ResultType type, int count) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Row(
      children: [
        Icon(
          _getTypeIcon(type),
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.globalSearchTypeSectionHeader(
            _getTypeDisplayName(type),
            count,
          ),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Build individual result card
  Widget _buildResultCard(SearchResult result, int index) {
    final isSelected = index == _selectedResultIndex;

    return SearchResultCard(
      result: result,
      onTap: () => _navigateToDetail(result),
      isSelected: isSelected,
    );
  }

  /// Build pagination controls
  Widget _buildPaginationControls() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final hasMore = _response?.hasMore ?? false;
    final canGoPrevious = _currentPage > 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: studioPanelBorderColor(context)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton.outlined(
            onPressed: canGoPrevious ? _previousPage : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.globalSearchPrevPage,
          ),

          const SizedBox(width: 16),

          // Page indicator
          Text(
            l10n.globalSearchCurrentPage(_currentPage),
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(width: 16),

          // Next button
          IconButton.outlined(
            onPressed: hasMore ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.globalSearchNextPage,
          ),
        ],
      ),
    );
  }

  /// Show filter dialog
  Future<void> _showMobileFilterDrawer() async {
    await showStudioBottomSheet<void>(
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

class _SavedSearchView {
  const _SavedSearchView({
    required this.id,
    required this.title,
    required this.query,
    required this.workspaceName,
    this.workspaceId,
    required this.pinned,
    required this.resultTypes,
    required this.timeFrom,
    required this.timeTo,
    required this.createdAt,
    required this.updatedAt,
    required this.lastUsedAt,
    required this.useCount,
  });

  final String id;
  final String title;
  final String query;
  final String? workspaceName;
  final String? workspaceId;
  final bool pinned;
  final List<String> resultTypes;
  final DateTime? timeFrom;
  final DateTime? timeTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int useCount;

  _SavedSearchView copyWith({
    String? id,
    String? title,
    String? query,
    String? workspaceName,
    String? workspaceId,
    bool? pinned,
    List<String>? resultTypes,
    DateTime? timeFrom,
    DateTime? timeTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    int? useCount,
  }) {
    return _SavedSearchView(
      id: id ?? this.id,
      title: title ?? this.title,
      query: query ?? this.query,
      workspaceName: workspaceName ?? this.workspaceName,
      workspaceId: workspaceId ?? this.workspaceId,
      pinned: pinned ?? this.pinned,
      resultTypes: resultTypes ?? this.resultTypes,
      timeFrom: timeFrom ?? this.timeFrom,
      timeTo: timeTo ?? this.timeTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
    );
  }

  factory _SavedSearchView.fromJson(Map<String, dynamic> json) {
    return _SavedSearchView(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      query: json['query'] as String? ?? '',
      workspaceName: json['workspaceName'] as String?,
      workspaceId: json['workspaceId'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      resultTypes: (json['resultTypes'] as List? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
      timeFrom: DateTime.tryParse(json['timeFrom'] as String? ?? ''),
      timeTo: DateTime.tryParse(json['timeTo'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'query': query,
      'workspaceName': workspaceName,
      if (workspaceId != null && workspaceId!.isNotEmpty)
        'workspaceId': workspaceId,
      'pinned': pinned,
      'resultTypes': resultTypes,
      'timeFrom': timeFrom?.toUtc().toIso8601String(),
      'timeTo': timeTo?.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastUsedAt': lastUsedAt?.toUtc().toIso8601String(),
      'useCount': useCount,
    };
  }
}

class _SearchViewTemplate {
  const _SearchViewTemplate({
    required this.id,
    this.resultTypes = const <ResultType>{},
    this.daysBack,
  });

  final String id;
  final Set<ResultType> resultTypes;
  final int? daysBack;
}
