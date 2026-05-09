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
  
  final bool _isLoading = false;
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
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _loadHistory();
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
      final history = await getHistory(token);
      if (!mounted) return;
      
      setState(() {
        // Show only the 5 most recent entries
        _history = history.take(5).toList();
        _showHistory = _history.isNotEmpty;
      });

      if (_showHistory) {
        _showOverlay();
      }
    } catch (e) {
      // Silently fail - history is not critical
      if (mounted) {
        setState(() {
          _history = [];
          _showHistory = false;
        });
      }
    }
  }

  /// Show history dropdown overlay
  void _showOverlay() {
    _removeOverlay();

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
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _history.length + 1, // +1 for clear button
                itemBuilder: (context, index) {
                  if (index == _history.length) {
                    // Clear history button
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.delete_outline, size: 20),
                      title: const Text(
                        '清除历史',
                        style: TextStyle(fontSize: 14),
                      ),
                      onTap: _clearHistory,
                    );
                  }

                  final entry = _history[index];
                  return ListTile(
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
                  );
                },
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
    return query.length >= _minQueryLength && !_isLoading;
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
              IconButton(
                icon: Icon(
                  Icons.notifications_active_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: '恢复本机高风险操作确认提示',
                onPressed: () =>
                    unawaited(runResetRiskyOperationConfirmPrefsFlow(context)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              // Loading indicator or search button
              if (_isLoading)
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
