import 'package:flutter/material.dart';

import '../l10n/rust_api_error_format.dart';
import '../rust_api/search/api.dart';
import '../utils/localized_formatting.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/tokens.dart';

/// Search history dropdown: shows recent queries on focus, tap to fill and search, clear button.
class SearchHistoryList extends StatefulWidget {
  const SearchHistoryList({
    super.key,
    required this.accessToken,
    required this.onHistorySelected,
    required this.onClearHistory,
    this.maxItems = 5,
  });

  final String accessToken;
  final ValueChanged<String> onHistorySelected;
  final VoidCallback onClearHistory;
  final int maxItems;

  @override
  State<SearchHistoryList> createState() => _SearchHistoryListState();
}

class _SearchHistoryListState extends State<SearchHistoryList> {
  List<HistoryEntry> _history = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final history = await getHistory(widget.accessToken);
      if (!mounted) return;

      setState(() {
        // Keep only the most recent maxItems entries
        _history = history.take(widget.maxItems).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = describeUserVisibleApiErrorResolved(context, e);
        _loading = false;
      });
    }
  }

  Future<void> _handleClearHistory() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    // Confirm before clearing
    final confirmed = await showStudioDialog<bool>(
      context: context,
      builder: (context) => StudioAlertDialog(
        title: Text(l10n.globalSearchClearSearchHistoryTitle),
        content: Text(l10n.globalSearchClearSearchHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.globalSearchCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.globalSearchConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await deleteHistory(widget.accessToken);
      if (!mounted) return;

      setState(() {
        _history = [];
        _loading = false;
      });

      widget.onClearHistory();

      // Success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.globalSearchHistoryCleared)),
        );
      }
    } catch (e) {
      if (!mounted) return;

      final loc = resolveAppLocalizationsForErrors(context);
      final msg = describeUserVisibleApiErrorResolved(context, e);
      setState(() {
        _error = msg;
        _loading = false;
      });

      // Error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.globalSearchClearHistoryFailed(msg))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioAsyncDataView(
      loading: _loading,
      error: _error,
      onRetry: _loadHistory,
      isEmpty: _history.isEmpty,
      empty: StudioEmptyState.emptyData(
        title: l10n.globalSearchNoSearchHistory,
        icon: Icons.history,
      ),
      loadingPlaceholder: StudioLoadingPlaceholder.list,
      loadingItemCount: 3,
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // History rows (Column avoids nested ListView shrinkWrap scroll issues)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              itemBuilder: (context, i) {
                return studioStaggeredItem(
                  i,
                  entranceKey: _history.length,
                  child: StudioListRow(
                    dense: true,
                    leading: const Icon(Icons.history, size: StudioIconSize.md),
                    title: Text(
                      _history[i].query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      l10n.globalSearchResultRows(_history[i].resultCount),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Text(
                      _formatTime(_history[i].searchedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StudioTokens.of(context).textMuted,
                      ),
                    ),
                    onTap: () => widget.onHistorySelected(_history[i].query),
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const Divider(height: StudioControlSize.dividerThickness),
            ),
            const Divider(height: StudioControlSize.dividerThickness),
            // Clear history
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.xs,
                vertical: StudioSpacing.chromeActionGap,
              ),
              child: TextButton.icon(
                onPressed: _handleClearHistory,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.globalSearchClearHistory),
                style: studioFormTextButtonIconStyle(context).merge(
                  TextButton.styleFrom(
                    foregroundColor: StudioTokens.of(context).danger,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Relative time label using locale-aware formatting.
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return LocalizedFormatting.formatRelativeTime(context, dateTime);
    } catch (_) {
      return '';
    }
  }
}
