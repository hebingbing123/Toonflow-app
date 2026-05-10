import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';

/// Global search bar component for the main navigation bar.
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 9.1, 9.6**
///
/// Features:
/// - Search input with minimum 2 character validation
/// - Enter key and search button trigger
/// - Keyboard shortcut support (Ctrl/Cmd + K to focus)
/// - Loading state indicator
/// - Search history dropdown (displays recent 5 entries)
/// - Debounced live suggestions (top matches from the same search API)
/// - Navigation to search results page with query parameters
class GlobalSearchBar extends StatefulWidget {
  const GlobalSearchBar({
    super.key,
    required this.accessToken,
    this.onNavigateToResults,
  });

  /// Access token for API calls
  final String? accessToken;

  /// Callback when navigating to search results page
  /// If null, uses Navigator.pushNamed with '/search' route
  final void Function(String query)? onNavigateToResults;

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  bool _loadingHistory = false;
  bool _loadingSuggestions = false;
  Timer? _suggestionDebounce;
  List<SearchResult> _suggestions = [];
  bool _showHistory = false;
  List<HistoryEntry> _history = [];
  OverlayEntry? _overlayEntry;

  /// Minimum characters required to trigger search
  static const int _minQueryLength = 2;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    _scheduleSuggestionFetch();
  }

  void _scheduleSuggestionFetch() {
    _suggestionDebounce?.cancel();
    final q = _controller.text.trim();
    if (q.length < _minQueryLength) {
      setState(() {
        _suggestions = [];
        _loadingSuggestions = false;
      });
      if (_focusNode.hasFocus && (_history.isNotEmpty || _loadingHistory)) {
        _showOverlay();
      } else if (_focusNode.hasFocus && q.isEmpty) {
        _showOverlay();
      }
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_fetchSuggestions(q));
    });
  }

  Future<void> _fetchSuggestions(String q) async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty || q.length < _minQueryLength) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadingSuggestions = true;
    });
    try {
      final response = await search(
        token,
        query: q,
        pageSize: 8,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = response.results;
        _loadingSuggestions = false;
      });
      if (_focusNode.hasFocus) {
        _showOverlay();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _loadingSuggestions = false;
      });
      if (_focusNode.hasFocus) {
        _showOverlay();
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      final token = widget.accessToken;
      if (token == null || token.isEmpty) {
        _showOverlay();
      } else {
        unawaited(_loadHistory());
      }
      _scheduleSuggestionFetch();
    } else {
      _hideHistory();
    }
  }

  /// Load search history from API
  Future<void> _loadHistory() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      setState(() => _loadingHistory = true);
      final history = await getHistory(token);
      if (!mounted) return;

      setState(() {
        _loadingHistory = false;
        // Show only the 5 most recent entries
        _history = history.take(5).toList();
        _showHistory = _history.isNotEmpty;
      });
      if (mounted && _focusNode.hasFocus) {
        _showOverlay();
      }
    } catch (e) {
      // Silently fail - history is not critical
      if (mounted) {
        setState(() {
          _loadingHistory = false;
          _history = [];
          _showHistory = false;
        });
      }
      if (mounted && _focusNode.hasFocus) {
        _showOverlay();
      }
    }
  }

  /// Show history dropdown overlay
  void _showOverlay() {
    _removeOverlay();

    final queryLen = _controller.text.trim().length;
    final showSuggestionsPanel =
        queryLen >= _minQueryLength &&
            (_loadingSuggestions || _suggestions.isNotEmpty);
    final headerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 400, // Match search bar width
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48), // Position below search bar
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (_loadingSuggestions && queryLen >= _minQueryLength)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (showSuggestionsPanel) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text('实时建议', style: headerStyle),
                    ),
                    ..._suggestions.map(
                      (r) => ListTile(
                        dense: true,
                        leading: Icon(
                          switch (r.resultType) {
                            ResultType.project => Icons.folder_outlined,
                            ResultType.script => Icons.article_outlined,
                            ResultType.asset => Icons.widgets_outlined,
                            ResultType.novel => Icons.menu_book_outlined,
                            ResultType.novelEvent => Icons.event_note_outlined,
                          },
                          size: 20,
                        ),
                        title: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          switch (r.resultType) {
                            ResultType.project => '项目',
                            ResultType.script => '剧本',
                            ResultType.asset => '资产',
                            ResultType.novel => '小说章节',
                            ResultType.novelEvent => '小说事件',
                          },
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: _performSearch,
                      ),
                    ),
                    if (_showHistory)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                  if (_loadingHistory)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  if (_showHistory) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text('最近搜索', style: headerStyle),
                    ),
                    ..._history.map(
                      (entry) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(
                          entry.query,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${entry.resultCount} 个结果',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => _selectHistoryEntry(entry.query),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.delete_outline, size: 20),
                      title: const Text(
                        '清除历史',
                        style: TextStyle(fontSize: 14),
                      ),
                      onTap: _clearHistory,
                    ),
                  ],
                  if (!showSuggestionsPanel &&
                      !_showHistory &&
                      !_loadingHistory &&
                      !_loadingSuggestions)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        queryLen >= _minQueryLength
                            ? '暂无匹配预览，按 Enter 查看完整结果'
                            : '输入至少 2 个字符以搜索',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Remove history dropdown overlay
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Hide history dropdown
  void _hideHistory() {
    _suggestionDebounce?.cancel();
    setState(() {
      _showHistory = false;
    });
    _removeOverlay();
  }

  /// Select a history entry and trigger search
  void _selectHistoryEntry(String query) {
    _controller.text = query;
    _hideHistory();
    _performSearch();
  }

  /// Clear all search history
  Future<void> _clearHistory() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await deleteHistory(token);
      if (!mounted) return;
      
      setState(() {
        _history = [];
        _showHistory = false;
      });
      _removeOverlay();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('搜索历史已清除'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除历史失败: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Check if search can be triggered
  bool get _canSearch {
    final query = _controller.text.trim();
    return query.length >= _minQueryLength;
  }

  /// Perform search and navigate to results page
  void _performSearch() {
    final query = _controller.text.trim();
    
    if (query.length < _minQueryLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入至少 2 个字符'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (query.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('搜索关键词过长，请限制在200字符以内'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _hideHistory();
    _focusNode.unfocus();

    // Navigate to search results page
    if (widget.onNavigateToResults != null) {
      widget.onNavigateToResults!(query);
    } else {
      // Default navigation using named route
      Navigator.pushNamed(
        context,
        '/search',
        arguments: {'query': query},
      );
    }
  }

  /// Handle keyboard shortcuts
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Ctrl+K / Cmd+K: Focus search box
    final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    
    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
      _focusNode.requestFocus();
      return KeyEventResult.handled;
    }

    // Enter: Trigger search
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_canSearch) {
        _performSearch();
        return KeyEventResult.handled;
      }
    }

    // Escape: Clear focus and hide history
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _focusNode.unfocus();
      _hideHistory();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          width: 400,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: _focusNode.hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Search icon
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              // Text input
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: '搜索项目、剧本、资产...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) {
                    if (_canSearch) {
                      _performSearch();
                    }
                  },
                ),
              ),
              const RiskyOperationConfirmPrefsOverflowMenu(
                icon: Icons.tune,
                tooltip: '本机客户端偏好（查看已静默 / 恢复确认）',
              ),
              // Loading indicator or search button
              if (_loadingSuggestions)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward,
                    size: 20,
                    color: _canSearch
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  onPressed: _canSearch ? _performSearch : null,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: _canSearch ? '搜索' : '请输入至少 2 个字符',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
