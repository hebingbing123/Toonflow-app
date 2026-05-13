import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
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
    this.currentWorkspaceName,
    this.currentWorkspaceId,
    this.onNavigateToResults,
  });

  /// Access token for API calls
  final String? accessToken;
  final String? currentWorkspaceName;

  /// Current workspace UUID (optional); persisted with saved views for server-side membership checks.
  final String? currentWorkspaceId;

  /// Callback when navigating to search results page
  /// If null, uses Navigator.pushNamed with '/search' route
  final void Function(
    String query, {
    List<ResultType> initialResultTypes,
    DateTime? initialTimeFrom,
    DateTime? initialTimeTo,
  })?
  onNavigateToResults;

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  static const _savedSearchViewsKey = 'global_search.saved_views.v1';
  static const List<_QuickSearchTemplate> _quickTemplates =
      <_QuickSearchTemplate>[
        _QuickSearchTemplate(id: 'recent-7d', daysBack: 7),
        _QuickSearchTemplate(
          id: 'projects-30d',
          resultTypes: <ResultType>{ResultType.project},
          daysBack: 30,
        ),
        _QuickSearchTemplate(
          id: 'scripts-30d',
          resultTypes: <ResultType>{ResultType.script},
          daysBack: 30,
        ),
      ];
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  bool _loadingHistory = false;
  bool _loadingSuggestions = false;
  Timer? _suggestionDebounce;
  List<SearchResult> _suggestions = [];
  bool _showHistory = false;
  List<HistoryEntry> _history = [];
  List<_PinnedSearchView> _pinnedViews = [];
  List<_PinnedSearchView> _recentViews = [];
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
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loadingSuggestions = true;
    });
    try {
      final response = await search(token, l10n: l10n, query: q, pageSize: 8, page: 1);
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
      await _loadPinnedViews();
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
      await _loadPinnedViews();
      if (mounted && _focusNode.hasFocus) {
        _showOverlay();
      }
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
        jsonEncode(
          remote.map((SearchSavedViewItem e) => e.toJson()).toList(),
        ),
      );
    } catch (_) {
      // Offline or API error — keep existing SharedPreferences snapshot.
    }
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
    } catch (_) {
      // Best-effort sync; local prefs remain authoritative until next successful PUT.
    }
  }

  Future<void> _loadPinnedViews() async {
    await _pullRemoteSavedViewsIntoPrefs();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedSearchViewsKey);
      if (raw == null || raw.isEmpty) {
        if (mounted) {
          setState(() {
            _pinnedViews = const <_PinnedSearchView>[];
          });
        }
        return;
      }
      final list = jsonDecode(raw) as List<dynamic>;
      final workspaceName = widget.currentWorkspaceName?.trim().toLowerCase();
      final views =
          list
              .map(
                (item) => _PinnedSearchView.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(growable: false)
            ..sort((a, b) {
              final aWorkspace = (a.workspaceName ?? '').trim().toLowerCase();
              final bWorkspace = (b.workspaceName ?? '').trim().toLowerCase();
              final aMatches =
                  workspaceName != null &&
                  workspaceName.isNotEmpty &&
                  aWorkspace == workspaceName;
              final bMatches =
                  workspaceName != null &&
                  workspaceName.isNotEmpty &&
                  bWorkspace == workspaceName;
              if (aMatches != bMatches) {
                return aMatches ? -1 : 1;
              }
              final bTime = b.lastUsedAt ?? b.updatedAt;
              final aTime = a.lastUsedAt ?? a.updatedAt;
              final byTime = bTime.compareTo(aTime);
              if (byTime != 0) {
                return byTime;
              }
              return b.useCount.compareTo(a.useCount);
            });
      final pinnedViews = views
          .where((item) => item.pinned)
          .toList(growable: false);
      final recentViews = views
          .where((item) => !item.pinned)
          .take(4)
          .toList(growable: false);
      if (mounted) {
        setState(() {
          _pinnedViews = pinnedViews.take(5).toList(growable: false);
          _recentViews = recentViews;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pinnedViews = const <_PinnedSearchView>[];
          _recentViews = const <_PinnedSearchView>[];
        });
      }
    }
  }

  String _workspaceGroupLabel(String? workspaceName) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = (workspaceName ?? '').trim();
    final current = (widget.currentWorkspaceName ?? '').trim();
    if (trimmed.isEmpty) {
      return l10n.globalSearchWorkspaceUnlabeled;
    }
    if (current.isNotEmpty && trimmed == current) {
      return l10n.globalSearchWorkspaceCurrent;
    }
    return trimmed;
  }

  Widget _buildViewRow(
    BuildContext context,
    _PinnedSearchView view, {
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pinActionLabel = view.pinned
        ? l10n.globalSearchUnpin
        : l10n.globalSearchPinnedViewsTitle;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(
        view.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        [
          view.query,
          if ((view.workspaceName ?? '').isNotEmpty) view.workspaceName!,
          if (view.resultTypes.isNotEmpty) view.resultTypes.join(','),
          l10n.globalSearchSavedUsed(view.useCount),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<_SavedViewAction>(
        tooltip: l10n.globalSearchViewActions,
        icon: const Icon(Icons.more_horiz, size: 18),
        onSelected: (_SavedViewAction action) {
          switch (action) {
            case _SavedViewAction.rename:
              unawaited(_renameSavedView(view));
            case _SavedViewAction.togglePin:
              unawaited(_toggleSavedViewPin(view));
            case _SavedViewAction.delete:
              unawaited(_deleteSavedView(view));
          }
        },
        itemBuilder: (menuContext) => <PopupMenuEntry<_SavedViewAction>>[
          PopupMenuItem<_SavedViewAction>(
            value: _SavedViewAction.rename,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text(l10n.globalSearchRename),
            ),
          ),
          PopupMenuItem<_SavedViewAction>(
            value: _SavedViewAction.togglePin,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                view.pinned
                    ? Icons.push_pin_outlined
                    : Icons.bookmark_add_outlined,
                size: 18,
              ),
              title: Text(pinActionLabel),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<_SavedViewAction>(
            value: _SavedViewAction.delete,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              title: Text(
                l10n.globalSearchDeleteView,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
      onTap: () => _openPinnedView(view),
    );
  }

  List<Widget> _buildGroupedViewTiles(
    BuildContext context,
    List<_PinnedSearchView> views, {
    required IconData icon,
    required TextStyle? headerStyle,
  }) {
    final grouped = <String, List<_PinnedSearchView>>{};
    for (final view in views) {
      final key = _workspaceGroupLabel(view.workspaceName);
      grouped.putIfAbsent(key, () => <_PinnedSearchView>[]).add(view);
    }
    final orderedKeys = grouped.keys.toList(growable: false)
      ..sort((a, b) {
        final currentLabel = _workspaceGroupLabel(widget.currentWorkspaceName);
        if (a == currentLabel) return -1;
        if (b == currentLabel) return 1;
        return a.compareTo(b);
      });
    final widgets = <Widget>[];
    for (final key in orderedKeys) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 2, 16, 2),
          child: Text(key, style: headerStyle),
        ),
      );
      widgets.addAll(
        grouped[key]!.map((view) => _buildViewRow(context, view, icon: icon)),
      );
    }
    return widgets;
  }

  Future<void> _renameSavedView(_PinnedSearchView view) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: view.title);
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.globalSearchRenameViewTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.globalSearchViewNameField,
            hintText: l10n.globalSearchRenameViewHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.globalSearchCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.globalSearchSave),
          ),
        ],
      ),
    );
    if (approved != true) {
      return;
    }
    final nextTitle = controller.text.trim();
    if (nextTitle.isEmpty || nextTitle == view.title) {
      return;
    }
    final updated = await _mutateSavedViews((list) {
      final now = DateTime.now().toUtc().toIso8601String();
      var changed = false;
      final next = list
          .map((item) {
            if ((item['id'] as String?) != view.id) {
              return item;
            }
            changed = true;
            return <String, dynamic>{
              ...item,
              'title': nextTitle,
              'updatedAt': now,
            };
          })
          .toList(growable: false);
      return changed ? next : null;
    });
    if (!updated) {
      return;
    }
    await _refreshSavedViewsOverlay();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.globalSearchRenamedView)));
  }

  Future<bool> _mutateSavedViews(
    List<Map<String, dynamic>>? Function(List<Map<String, dynamic>> list)
    mutate,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedSearchViewsKey);
    if (raw == null || raw.isEmpty) {
      return false;
    }
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
    final next = mutate(list);
    if (next == null) {
      return false;
    }
    await prefs.setString(_savedSearchViewsKey, jsonEncode(next));
    unawaited(_pushSavedViewsToServer());
    return true;
  }

  Future<void> _refreshSavedViewsOverlay() async {
    await _loadPinnedViews();
    if (!mounted) {
      return;
    }
    if (_focusNode.hasFocus) {
      _showOverlay();
    }
  }

  Future<void> _toggleSavedViewPin(_PinnedSearchView view) async {
    final l10n = AppLocalizations.of(context)!;
    final updated = await _mutateSavedViews((list) {
      final now = DateTime.now().toUtc().toIso8601String();
      var changed = false;
      final next = list
          .map((item) {
            if ((item['id'] as String?) != view.id) {
              return item;
            }
            changed = true;
            return <String, dynamic>{
              ...item,
              'pinned': !view.pinned,
              'updatedAt': now,
              'lastUsedAt': now,
            };
          })
          .toList(growable: false);
      return changed ? next : null;
    });
    if (!updated) {
      return;
    }
    await _refreshSavedViewsOverlay();
    if (!mounted) {
      return;
    }
    final message = view.pinned
        ? l10n.globalSearchUnpinnedView
        : l10n.globalSearchPinnedToSearchBar;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteSavedView(_PinnedSearchView view) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.globalSearchDeleteViewTitle),
        content: Text(
          (widget.accessToken?.trim().isNotEmpty ?? false)
              ? l10n.globalSearchDeleteViewConfirmRemote(view.title)
              : l10n.globalSearchDeleteViewConfirmLocal(view.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.globalSearchCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.globalSearchDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final updated = await _mutateSavedViews((list) {
      final next = list
          .where((item) => (item['id'] as String?) != view.id)
          .toList(growable: false);
      if (next.length == list.length) {
        return null;
      }
      return next;
    });
    if (!updated) {
      return;
    }
    await _refreshSavedViewsOverlay();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.globalSearchViewDeleted)));
  }

  /// Show history dropdown overlay
  void _showOverlay() {
    final l10n = AppLocalizations.of(context)!;
    _removeOverlay();

    final queryLen = _controller.text.trim().length;
    final showSuggestionsPanel =
        queryLen >= _minQueryLength &&
        (_loadingSuggestions || _suggestions.isNotEmpty);
    final showPinnedPanel =
        queryLen < _minQueryLength && _pinnedViews.isNotEmpty;
    final showRecentViewsPanel =
        queryLen < _minQueryLength && _recentViews.isNotEmpty;
    final showTemplatePanel = queryLen < _minQueryLength;
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
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
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
                  if (showPinnedPanel) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(l10n.globalSearchPinnedViewsTitle, style: headerStyle),
                    ),
                    ..._buildGroupedViewTiles(
                      context,
                      _pinnedViews,
                      icon: Icons.push_pin,
                      headerStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (_showHistory || showSuggestionsPanel)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                  if (showRecentViewsPanel) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(l10n.globalSearchRecentViewsTitle, style: headerStyle),
                    ),
                    ..._buildGroupedViewTiles(
                      context,
                      _recentViews,
                      icon: Icons.schedule,
                      headerStyle: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (_showHistory ||
                        showSuggestionsPanel ||
                        showTemplatePanel)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                  if (showTemplatePanel) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(l10n.globalSearchQuickTemplatesTitle, style: headerStyle),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickTemplates
                          .map(
                            (template) => Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 8,
                                bottom: 8,
                              ),
                              child: ActionChip(
                                label: Text(_quickTemplateLabel(l10n, template.id)),
                                onPressed: () => _openQuickTemplate(template),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (_showHistory || showSuggestionsPanel)
                      Divider(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                  ],
                  if (showSuggestionsPanel) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(l10n.globalSearchLiveSuggestionsTitle, style: headerStyle),
                    ),
                    ..._suggestions.map(
                      (r) => ListTile(
                        dense: true,
                        leading: Icon(switch (r.resultType) {
                          ResultType.project => Icons.folder_outlined,
                          ResultType.script => Icons.article_outlined,
                          ResultType.asset => Icons.widgets_outlined,
                          ResultType.novel => Icons.menu_book_outlined,
                          ResultType.novelEvent => Icons.event_note_outlined,
                        }, size: 20),
                        title: Text(
                          r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          switch (r.resultType) {
                            ResultType.project => l10n.globalSearchTypeProject,
                            ResultType.script => l10n.globalSearchTypeScript,
                            ResultType.asset => l10n.globalSearchTypeAsset,
                            ResultType.novel => l10n.globalSearchTypeNovel,
                            ResultType.novelEvent => l10n.globalSearchTypeNovelEvent,
                          },
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                      child: Text(l10n.globalSearchRecentSearchTitle, style: headerStyle),
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
                          l10n.globalSearchFoundResults(entry.resultCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () => _selectHistoryEntry(entry.query),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.delete_outline, size: 20),
                      title: Text(
                        l10n.globalSearchClearHistory,
                        style: const TextStyle(fontSize: 14),
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
                            ? l10n.globalSearchNoPreviewHint
                            : l10n.globalSearchMinCharsHint,
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

  Future<void> _openPinnedView(_PinnedSearchView view) async {
    _hideHistory();
    _focusNode.unfocus();
    final resultTypes = view.resultTypes
        .map(_resultTypeFromWireName)
        .whereType<ResultType>()
        .toList(growable: false);
    if (widget.onNavigateToResults != null) {
      widget.onNavigateToResults!(
        view.query,
        initialResultTypes: resultTypes,
        initialTimeFrom: view.timeFrom,
        initialTimeTo: view.timeTo,
      );
    } else {
      Navigator.pushNamed(context, '/search', arguments: {'query': view.query});
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedSearchViewsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final list = jsonDecode(raw) as List<dynamic>;
    final next = list
        .map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if ((map['id'] as String?) == view.id) {
            map['lastUsedAt'] = now;
            map['useCount'] = ((map['useCount'] as num?)?.toInt() ?? 0) + 1;
          }
          return map;
        })
        .toList(growable: false);
    await prefs.setString(_savedSearchViewsKey, jsonEncode(next));
    unawaited(_pushSavedViewsToServer());
    unawaited(_loadPinnedViews());
  }

  void _openQuickTemplate(_QuickSearchTemplate template) {
    final l10n = AppLocalizations.of(context)!;
    _hideHistory();
    _focusNode.unfocus();
    final now = DateTime.now();
    final start = template.daysBack == null
        ? null
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(Duration(days: template.daysBack!));
    final resultTypes = template.resultTypes.toList(growable: false);
    final query = _controller.text.trim();
    if (widget.onNavigateToResults != null) {
      widget.onNavigateToResults!(
        query.isEmpty ? l10n.globalSearchTypeProject : query,
        initialResultTypes: resultTypes,
        initialTimeFrom: start,
        initialTimeTo: now,
      );
    } else {
      Navigator.pushNamed(
        context,
        '/search',
        arguments: {'query': query.isEmpty ? l10n.globalSearchTypeProject : query},
      );
    }
  }

  String _quickTemplateLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'recent-7d':
        return l10n.globalSearchTemplateRecent7d;
      case 'projects-30d':
        return l10n.globalSearchTemplateProjects30d;
      case 'scripts-30d':
        return l10n.globalSearchTemplateScripts30d;
      default:
        return id;
    }
  }

  /// Clear all search history
  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context)!;
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
          SnackBar(
            content: Text(l10n.globalSearchHistoryCleared),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.globalSearchClearHistoryFailed(describeUserVisibleApiError(l10n, e))),
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
    final l10n = AppLocalizations.of(context)!;
    final query = _controller.text.trim();

    if (query.length < _minQueryLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.globalSearchEnterAtLeastChars(2)),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (query.length > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.globalSearchMaxCharsHint(200)),
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
      Navigator.pushNamed(context, '/search', arguments: {'query': query});
    }
  }

  /// Handle keyboard shortcuts
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    // Ctrl+K / Cmd+K: Focus search box
    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed ||
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
    final l10n = AppLocalizations.of(context)!;
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
                    hintText: l10n.globalSearchInputHint,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
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
              RiskyOperationConfirmPrefsOverflowMenu(
                icon: Icons.tune,
                tooltip: l10n.globalSearchLocalClientPrefsTooltip,
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
                        : theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.3,
                          ),
                  ),
                  onPressed: _canSearch ? _performSearch : null,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                  tooltip: _canSearch
                      ? l10n.globalSearchActionSearch
                      : l10n.globalSearchEnterAtLeastChars(2),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedSearchView {
  const _PinnedSearchView({
    required this.id,
    required this.title,
    required this.query,
    required this.workspaceName,
    this.workspaceId,
    required this.pinned,
    required this.resultTypes,
    required this.timeFrom,
    required this.timeTo,
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
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int useCount;

  factory _PinnedSearchView.fromJson(Map<String, dynamic> json) {
    return _PinnedSearchView(
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
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class _QuickSearchTemplate {
  const _QuickSearchTemplate({
    required this.id,
    this.resultTypes = const <ResultType>{},
    this.daysBack,
  });

  final String id;
  final Set<ResultType> resultTypes;
  final int? daysBack;
}

enum _SavedViewAction { rename, togglePin, delete }
