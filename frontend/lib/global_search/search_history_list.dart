import 'package:flutter/material.dart';

import '../rust_api/search/api.dart';

/// 搜索历史下拉列表组件
///
/// 在搜索框获得焦点时显示最近 5 条历史记录
/// 点击历史记录自动填充并触发搜索
/// 提供「清除历史」按钮
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
        // 只显示最近的 maxItems 条记录
        _history = history.take(widget.maxItems).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleClearHistory() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除搜索历史'),
        content: const Text('确定要清除所有搜索历史吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
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

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('搜索历史已清除')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  '加载历史失败',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: _loadHistory,
                child: const Text('重试'),
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
            '暂无搜索历史',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 历史记录列表
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
                  '${entry.resultCount} 条结果',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  _formatTime(entry.searchedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                onTap: () => widget.onHistorySelected(entry.query),
              );
            },
          ),
          const Divider(height: 1),
          // 清除历史按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextButton.icon(
              onPressed: _handleClearHistory,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('清除历史'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化时间显示
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return '刚刚';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} 分钟前';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} 小时前';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} 天前';
      } else {
        // 显示具体日期
        return '${dateTime.month}/${dateTime.day}';
      }
    } catch (_) {
      return '';
    }
  }
}
