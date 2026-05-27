import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/product_demo_mode.dart';
import '../design_system/studio_typography.dart';
import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_tap.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/studio_responsive_layout.dart';
import '../design_system/tokens.dart';
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
    this.compact = false,
    this.titleBarDense = false,
    this.showLocalPrefsMenu = true,
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
  final bool compact;
  /// VS Code–style title-bar search: ~28px tall, 12px text, no fixed width.
  final bool titleBarDense;
  final bool showLocalPrefsMenu;

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
  Timer? _overlayTextDebounce;
  List<SearchResult> _suggestions = [];
  bool _showHistory = false;
  List<HistoryEntry> _history = [];
  List<_PinnedSearchView> _pinnedViews = [];
  List<_PinnedSearchView> _recentViews = [];
  OverlayEntry? _overlayEntry;
  int _paletteSelectedIndex = 0;

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
    _overlayTextDebounce?.cancel();
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _paletteSelectedIndex = 0;
    _overlayTextDebounce?.cancel();
    _overlayTextDebounce = Timer(const Duration(milliseconds: 48), () {
      if (!mounted) {
        return;
      }
      _refreshOverlay();
    });
    _scheduleSuggestionFetch();
  }

  /// Rebuild overlay list without tearing down the input field (avoids focus loss).
  void _refreshOverlay() {
    if (!mounted || !_focusNode.hasFocus) {
      return;
    }
    if (_overlayEntry == null) {
      _showOverlay();
      return;
    }
    _overlayEntry!.markNeedsBuild();
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
        _refreshOverlay();
      } else if (_focusNode.hasFocus && q.isEmpty) {
        _refreshOverlay();
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
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      if (!mounted) return;
      setState(() {
        _suggestions = const <SearchResult>[];
        _loadingSuggestions = false;
      });
      return;
    }
    if (!mounted) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _loadingSuggestions = true;
    });
    try {
      final response = await search(
        token,
        l10n: l10n,
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
        _refreshOverlay();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _loadingSuggestions = false;
      });
      if (_focusNode.hasFocus) {
        _refreshOverlay();
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
        _refreshOverlay();
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
        _refreshOverlay();
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
        jsonEncode(remote.map((SearchSavedViewItem e) => e.toJson()).toList()),
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

  double _overlayPanelWidth(BuildContext context, Size fieldSize) {
    // Title-bar search: palette width tracks the field (not screen/3).
    if (widget.titleBarDense) {
      final w = fieldSize.width;
      return w > 0 ? w : 280;
    }
    return math.max(fieldSize.width, 320);
  }

  /// Read-only query strip in the palette (typing stays in the title-bar field).
  Widget _buildPaletteQueryHeader(
    AppLocalizations l10n,
    ThemeData theme,
    StudioTokens tokens,
  ) {
    final typography = StudioTypography.of(context);
    final hintStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: typography.body,
      color: tokens.textSecondary.withValues(alpha: 0.78),
    );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: typography.body,
      color: tokens.textPrimary.withValues(alpha: 0.92),
      fontWeight: FontWeight.w400,
    );
    final query = _controller.text;
    final label = query.isEmpty ? l10n.globalSearchInputHint : query;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.primary.withValues(alpha: 0.55)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        StudioSpacing.radiusComfort,
        StudioSpacing.xs,
        StudioSpacing.radiusComfort,
        StudioSpacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: StudioIconSize.xs,
            color: tokens.textSecondary.withValues(alpha: 0.88),
          ),
          const SizedBox(width: StudioSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: query.isEmpty ? hintStyle : textStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaletteRow({
    required ThemeData theme,
    required StudioTokens tokens,
    required String title,
    String? trailing,
    IconData? icon,
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final typography = StudioTypography.of(context);
    final rowStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: typography.body,
      color: tokens.textPrimary.withValues(alpha: 0.92),
    );
    final trailingStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: typography.meta,
      color: tokens.textMuted.withValues(alpha: 0.85),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? tokens.bgInset.withValues(alpha: 0.95) : null,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: StudioTap(
        onTap: onTap,
        minSize: StudioSpacing.touchTarget,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: StudioIconSize.xs, color: tokens.textSecondary),
              const SizedBox(width: StudioSpacing.xs),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: rowStyle,
              ),
            ),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: StudioSpacing.xs),
              Text(trailing, style: trailingStyle),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaletteDivider(StudioTokens tokens) {
    return Divider(height: StudioControlSize.dividerThickness, thickness: 1, color: tokens.surfaceHighlight);
  }

  List<Widget> _buildPaletteOverlayList({
    required BuildContext context,
    required AppLocalizations l10n,
    required ThemeData theme,
    required StudioTokens tokens,
    required int queryLen,
    required bool showSuggestionsPanel,
    required bool showPinnedPanel,
    required bool showRecentViewsPanel,
    required bool showTemplatePanel,
  }) {
    var row = 0;
    final items = <Widget>[];
    final entranceKey = Object.hash(
      queryLen,
      showSuggestionsPanel,
      showPinnedPanel,
      showRecentViewsPanel,
      showTemplatePanel,
      _suggestions.length,
      _history.length,
      _pinnedViews.length,
      _recentViews.length,
      _loadingSuggestions,
      _loadingHistory,
    );

    void addRow(
      Widget Function(bool selected) build, {
      bool dividerBefore = false,
    }) {
      if (dividerBefore && items.isNotEmpty) {
        items.add(_buildPaletteDivider(tokens));
      }
      final index = row;
      items.add(
        studioStaggeredItem(
          index,
          entranceKey: entranceKey,
          child: build(index == _paletteSelectedIndex),
        ),
      );
      row++;
    }

    if (_loadingSuggestions && queryLen >= _minQueryLength) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: StudioSpacing.xs,
          ),
          child: StudioListSkeleton(itemCount: 3, scrollable: false),
        ),
      );
      return items;
    }

    if (showTemplatePanel) {
      for (final template in _quickTemplates) {
        addRow(
          (selected) => _buildPaletteRow(
            theme: theme,
            tokens: tokens,
            title: _quickTemplateLabel(l10n, template.id),
            icon: Icons.search,
            selected: selected,
            onTap: () => _openQuickTemplate(template),
          ),
        );
      }
    }

    if (showPinnedPanel) {
      addRow(
        (selected) => _buildPaletteRow(
          theme: theme,
          tokens: tokens,
          title: l10n.globalSearchPinnedViewsTitle,
          icon: Icons.push_pin_outlined,
          selected: selected,
          onTap: () {},
        ),
        dividerBefore: items.isNotEmpty,
      );
      for (final view in _pinnedViews) {
        addRow(
          (selected) => _buildPaletteRow(
            theme: theme,
            tokens: tokens,
            title: view.title,
            trailing: view.workspaceName,
            icon: Icons.bookmark_outline,
            selected: selected,
            onTap: () => _openPinnedView(view),
          ),
        );
      }
    }

    if (showRecentViewsPanel) {
      addRow(
        (selected) => _buildPaletteRow(
          theme: theme,
          tokens: tokens,
          title: l10n.globalSearchRecentViewsTitle,
          icon: Icons.schedule,
          selected: selected,
          onTap: () {},
        ),
        dividerBefore: items.isNotEmpty,
      );
      for (final view in _recentViews) {
        addRow(
          (selected) => _buildPaletteRow(
            theme: theme,
            tokens: tokens,
            title: view.title,
            trailing: l10n.globalSearchSavedUsed(view.useCount),
            icon: Icons.history,
            selected: selected,
            onTap: () => _openPinnedView(view),
          ),
        );
      }
    }

    if (showSuggestionsPanel) {
      addRow(
        (selected) => _buildPaletteRow(
          theme: theme,
          tokens: tokens,
          title: l10n.globalSearchLiveSuggestionsTitle,
          icon: Icons.manage_search,
          selected: selected,
          onTap: () {},
        ),
        dividerBefore: items.isNotEmpty,
      );
      for (final r in _suggestions) {
        addRow(
          (selected) => _buildPaletteRow(
            theme: theme,
            tokens: tokens,
            title: r.title,
            trailing: switch (r.resultType) {
              ResultType.project => l10n.globalSearchTypeProject,
              ResultType.script => l10n.globalSearchTypeScript,
              ResultType.asset => l10n.globalSearchTypeAsset,
              ResultType.novel => l10n.globalSearchTypeNovel,
              ResultType.novelEvent => l10n.globalSearchTypeNovelEvent,
            },
            icon: switch (r.resultType) {
              ResultType.project => Icons.folder_outlined,
              ResultType.script => Icons.article_outlined,
              ResultType.asset => Icons.widgets_outlined,
              ResultType.novel => Icons.menu_book_outlined,
              ResultType.novelEvent => Icons.event_note_outlined,
            },
            selected: selected,
            onTap: _performSearch,
          ),
        );
      }
    }

    if (_loadingHistory) {
      items.add(
        const Padding(
          padding: EdgeInsets.all(StudioSpacing.sm),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: StudioControlSize.progressStroke),
            ),
          ),
        ),
      );
      return items;
    }

    if (_showHistory && queryLen < _minQueryLength) {
      addRow(
        (selected) => _buildPaletteRow(
          theme: theme,
          tokens: tokens,
          title: l10n.globalSearchRecentSearchTitle,
          icon: Icons.history,
          selected: selected,
          onTap: () {},
        ),
        dividerBefore: items.isNotEmpty,
      );
      for (final entry in _history) {
        addRow(
          (selected) => _buildPaletteRow(
            theme: theme,
            tokens: tokens,
            title: entry.query,
            trailing: l10n.globalSearchFoundResults(entry.resultCount),
            icon: Icons.history,
            selected: selected,
            onTap: () => _selectHistoryEntry(entry.query),
          ),
        );
      }
      addRow(
        (selected) => _buildPaletteRow(
          theme: theme,
          tokens: tokens,
          title: l10n.globalSearchClearHistory,
          icon: Icons.delete_outline,
          selected: selected,
          onTap: _clearHistory,
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        StudioEmptyState(
          title: queryLen >= _minQueryLength
              ? l10n.globalSearchNoPreviewHint
              : l10n.globalSearchMinCharsHint,
          variant: StudioEmptyStateVariant.noResults,
          weight: StudioEmptyStateWeight.quiet,
        ),
      );
    }

    return items;
  }

  /// VS Code command-palette style overlay (search header + flat result list).
  void _showOverlay() {
    _removeOverlay();
    _paletteSelectedIndex = 0;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final l10n = resolveAppLocalizationsForErrors(context);
        final theme = Theme.of(context);
        final tokens = StudioTokens.of(context);
        final renderBox = context.findRenderObject() as RenderBox?;
        final fieldSize = renderBox?.size ?? const Size(400, 40);
        final queryLen = _controller.text.trim().length;
        final showSuggestionsPanel =
            queryLen >= _minQueryLength &&
            (_loadingSuggestions || _suggestions.isNotEmpty);
        final showPinnedPanel =
            queryLen < _minQueryLength && _pinnedViews.isNotEmpty;
        final showRecentViewsPanel =
            queryLen < _minQueryLength && _recentViews.isNotEmpty;
        final showTemplatePanel = queryLen < _minQueryLength;
        final panelWidth = _overlayPanelWidth(context, fieldSize);
        final listChildren = _buildPaletteOverlayList(
          context: context,
          l10n: l10n,
          theme: theme,
          tokens: tokens,
          queryLen: queryLen,
          showSuggestionsPanel: showSuggestionsPanel,
          showPinnedPanel: showPinnedPanel,
          showRecentViewsPanel: showRecentViewsPanel,
          showTemplatePanel: showTemplatePanel,
        );

        return Positioned(
          width: panelWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(
              0,
              fieldSize.height +
                  (widget.titleBarDense
                      ? StudioSpacing.chromeActionGap
                      : StudioSpacing.xs),
            ),
            child: Material(
              color: StudioPrimitives.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 440),
                decoration: BoxDecoration(
                  color: tokens.bgElevated.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  border: Border.all(
                    color: tokens.primary.withValues(alpha: 0.38),
                  ),
                  boxShadow: studioInsetElevationShadow(
                    context,
                    alpha: 0.38,
                    blurRadius: StudioSpacing.md,
                    offset: const Offset(0, StudioSpacing.radiusComfort),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (!widget.titleBarDense)
                      _buildPaletteQueryHeader(l10n, theme, tokens),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: studioAdaptiveDialogHeight(
                          context,
                          fraction: widget.titleBarDense ? 0.48 : 0.44,
                          min: StudioLayoutSize.fieldStandard,
                          max: widget.titleBarDense ? 480 : 440,
                        ),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          StudioLayoutSpacing.titleTight,
                          widget.titleBarDense
                              ? StudioLayoutSpacing.microGap
                              : StudioLayoutSpacing.titleTight,
                          StudioLayoutSpacing.titleTight,
                          StudioLayoutSpacing.titleTight,
                        ),
                        shrinkWrap: true,
                        itemCount: listChildren.length,
                        itemBuilder: (context, index) => listChildren[index],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
        arguments: {
          'query': query.isEmpty ? l10n.globalSearchTypeProject : query,
        },
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
      case 'assets-30d':
        return l10n.globalSearchTemplateAssets30d;
      default:
        return id;
    }
  }

  /// Clear all search history
  Future<void> _clearHistory() async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
            content: Text(
              l10n.globalSearchClearHistoryFailed(
                describeUserVisibleApiErrorResolved(context, e),
              ),
            ),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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

  static const InputBorder _titleBarSearchNoBorder = InputBorder.none;

  InputDecoration _titleBarSearchDecoration({
    required String hintText,
    required TextStyle hintStyle,
    EdgeInsets contentPadding = const EdgeInsets.fromLTRB(
      0,
      StudioSpacing.chromeActionGap,
      0,
      StudioSpacing.xs,
    ),
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: hintStyle,
      isDense: true,
      filled: false,
      border: _titleBarSearchNoBorder,
      enabledBorder: _titleBarSearchNoBorder,
      focusedBorder: _titleBarSearchNoBorder,
      disabledBorder: _titleBarSearchNoBorder,
      errorBorder: _titleBarSearchNoBorder,
      focusedErrorBorder: _titleBarSearchNoBorder,
      contentPadding: contentPadding,
      alignLabelWithHint: true,
    );
  }

  void _requestTitleBarSearchFocus() {
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  /// macOS title-bar search — VS Code layout: one rounded box; icon + hint centered;
  /// the full box is tappable (not only the narrow TextField).
  Widget _buildTitleBarDenseSearch(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    StudioTokens tokens,
  ) {
    const barHeight = 30.0;
    final typography = StudioTypography.of(context);
    const fieldRadius = StudioSpacing.radiusDense;
    const iconGap = StudioSpacing.xs;
    final textColor = tokens.textPrimary.withValues(alpha: 0.92);
    final iconColor = tokens.textSecondary.withValues(alpha: 0.88);
    final fieldBorder = _focusNode.hasFocus
        ? tokens.accent.withValues(alpha: 0.55)
        : tokens.surfaceHighlight.withValues(alpha: 0.4);
    const fieldContentPadding = EdgeInsets.symmetric(vertical: StudioSpacing.xs);
    final hintStyle = (studioHintStyle(context) ?? const TextStyle()).copyWith(
      fontSize: typography.body,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: tokens.textSecondary.withValues(alpha: 0.86),
    );
    final textStyle =
        (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontSize: typography.body,
      color: textColor,
      fontWeight: FontWeight.w500,
      height: 1.2,
    );

    Widget searchGlyph({required Color color}) {
      return studioDecorativeIcon(
        Icons.search_rounded,
        size: StudioIconSize.xs,
        color: color,
      );
    }

    Widget trailingSlot() {
      if (_loadingSuggestions) {
        return SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: StudioControlSize.progressStroke,
            color: tokens.accent,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(fieldRadius),
          border: Border.all(color: fieldBorder),
        ),
        child: StudioTap(
          minSize: barHeight,
          borderRadius: BorderRadius.circular(fieldRadius),
          onTap: _requestTitleBarSearchFocus,
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const trailingSlotWidth = 15.0;
              final glyphColor = _focusNode.hasFocus
                  ? tokens.accent.withValues(alpha: 0.92)
                  : iconColor;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  searchGlyph(color: glyphColor),
                  const SizedBox(width: iconGap),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 1,
                      textAlign: TextAlign.left,
                      textAlignVertical: TextAlignVertical.center,
                      style: textStyle,
                      cursorColor: tokens.accent,
                      decoration: _titleBarSearchDecoration(
                        hintText: l10n.globalSearchInputHint,
                        hintStyle: hintStyle,
                        contentPadding: fieldContentPadding,
                      ),
                      onSubmitted: (_) {
                        if (_canSearch) {
                          _performSearch();
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: trailingSlotWidth,
                    child: Center(child: trailingSlot()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final titleBarDense = widget.titleBarDense;
    if (titleBarDense) {
      return Focus(
        onKeyEvent: _handleKeyEvent,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: _buildTitleBarDenseSearch(context, l10n, theme, tokens),
        ),
      );
    }
    final compact = widget.compact || titleBarDense;
    final barHeight = titleBarDense ? 30.0 : (compact ? 38.0 : 40.0);
    final barRadius = titleBarDense
        ? StudioSpacing.radiusDense
        : (compact ? StudioSpacing.radiusCard : StudioSpacing.sm);
    final iconSize = titleBarDense
        ? StudioSpacing.sm
        : (compact ? StudioSpacing.radiusComfort : StudioSpacing.sm);
    final leadingPadding = titleBarDense
        ? StudioSpacing.xs
        : (compact ? StudioSpacing.xs : StudioSpacing.radiusComfort);
    final iconGap = titleBarDense
        ? StudioSpacing.chromeActionGap
        : StudioSpacing.xs;
    final textPadding = titleBarDense
        ? StudioSpacing.xs
        : (compact ? StudioSpacing.xs : StudioSpacing.radiusComfort);
    final fontSize = titleBarDense ? 12.0 : (compact ? 13.0 : 14.0);
    final mutedFieldColor = tokens.textMuted.withValues(
      alpha: titleBarDense ? 0.52 : 1.0,
    );
    final mutedHintColor = tokens.textMuted.withValues(
      alpha: titleBarDense ? 0.42 : 1.0,
    );
    final mutedIconColor = tokens.textMuted.withValues(
      alpha: titleBarDense ? 0.48 : 1.0,
    );

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final resolvedWidth = titleBarDense
                ? null
                : compact && constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(160.0, 400.0)
                : 400.0;
            return Container(
              width: resolvedWidth,
              height: barHeight,
              decoration: BoxDecoration(
            color: titleBarDense
                ? tokens.bgInset.withValues(alpha: 0.92)
                : null,
            gradient: titleBarDense
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      tokens.bgSurface.withValues(alpha: 0.96),
                      tokens.bgInset.withValues(alpha: 0.98),
                    ],
                  ),
            borderRadius: BorderRadius.circular(barRadius),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? tokens.accent
                  : tokens.surfaceHighlight,
              width: _focusNode.hasFocus ? (titleBarDense ? 1.0 : 1.5) : 1,
            ),
            boxShadow: titleBarDense || !_focusNode.hasFocus
                ? const <BoxShadow>[]
                : studioInsetElevationShadow(
                    context,
                    alpha: 0.14,
                    blurRadius: StudioSpacing.xs,
                    spreadRadius: -2,
                    offset: const Offset(0, StudioSpacing.chromeActionGap),
                  ),
          ),
          child: Row(
            children: [
              // Search icon
              Padding(
                padding: EdgeInsets.only(left: leadingPadding, right: iconGap),
                child: studioDecorativeIcon(
                  Icons.search_rounded,
                  size: iconSize,
                  color: _focusNode.hasFocus
                      ? tokens.accent.withValues(alpha: titleBarDense ? 0.75 : 1.0)
                      : (titleBarDense ? mutedIconColor : tokens.textMuted),
                ),
              ),

              // Text input
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: l10n.globalSearchInputHint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: fontSize,
                      color: titleBarDense ? mutedHintColor : tokens.textMuted,
                      fontWeight: titleBarDense ? FontWeight.w400 : null,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: textPadding),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: fontSize,
                    color: titleBarDense
                        ? (_controller.text.isEmpty
                              ? mutedHintColor
                              : mutedFieldColor)
                        : null,
                    fontWeight: titleBarDense ? FontWeight.w400 : null,
                  ),
                  onSubmitted: (_) {
                    if (_canSearch) {
                      _performSearch();
                    }
                  },
                ),
              ),
              if (widget.showLocalPrefsMenu)
                RiskyOperationConfirmPrefsOverflowMenu(
                  icon: Icons.tune,
                  tooltip: l10n.globalSearchLocalClientPrefsTooltip,
                ),
              // Loading indicator or search button
              if (_loadingSuggestions)
                Padding(
                  padding: EdgeInsets.only(right: compact ? StudioLayoutSpacing.inlineGap : StudioLayoutSpacing.insetDense),
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: StudioControlSize.progressStroke,
                      color: tokens.accent,
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.arrow_outward_rounded,
                    size: iconSize,
                    fill: titleBarDense ? 0.15 : 0.0,
                    color: _canSearch
                        ? theme.colorScheme.onPrimary
                        : (titleBarDense
                              ? mutedIconColor
                              : tokens.textMuted.withValues(alpha: 0.35)),
                  ),
                  onPressed: _canSearch ? _performSearch : null,
                  style: IconButton.styleFrom(
                    backgroundColor: _canSearch
                        ? tokens.primary.withValues(
                            alpha: titleBarDense ? 0.82 : 1.0,
                          )
                        : StudioPrimitives.transparent,
                    foregroundColor: _canSearch
                        ? theme.colorScheme.onPrimary
                        : tokens.textMuted,
                  ),
                  padding: EdgeInsets.all(
                    titleBarDense
                        ? StudioSpacing.chromeActionGap
                        : StudioSpacing.xs,
                  ),
                  constraints: BoxConstraints(
                    minWidth: titleBarDense ? 26 : 0,
                    minHeight: titleBarDense ? 26 : 0,
                  ),
                  tooltip: _canSearch
                      ? l10n.globalSearchActionSearch
                      : l10n.globalSearchEnterAtLeastChars(2),
                ),
            ],
          ),
            );
          },
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
