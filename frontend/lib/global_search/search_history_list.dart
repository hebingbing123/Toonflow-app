import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../rust_api/search/api.dart';
import '../utils/localized_formatting.dart';

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
        final loc = AppLocalizations.of(context)!;
        _error = describeUserVisibleApiError(loc, e);
        _loading = false;
      });
    }
  }

  Future<void> _handleClearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    // Confirm before clearing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

      final msg = describeUserVisibleApiError(l10n, e);
      setState(() {
        _error = msg;
        _loading = false;
      });

      // Error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.globalSearchClearHistoryFailed(msg))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.globalSearchLoadHistoryFailed,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: _loadHistory,
                child: Text(l10n.globalSearchRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            l10n.globalSearchNoSearchHistory,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // History rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = _history[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.history, size: 20),
                title: Text(
                  entry.query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  l10n.globalSearchResultRows(entry.resultCount),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  _formatTime(entry.searchedAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                onTap: () => widget.onHistorySelected(entry.query),
              );
            },
          ),
          const Divider(height: 1),
          // Clear history
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextButton.icon(
              onPressed: _handleClearHistory,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(l10n.globalSearchClearHistory),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
        ],
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
