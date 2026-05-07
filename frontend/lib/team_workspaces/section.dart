import 'package:flutter/material.dart';

import '../rust_api.dart';

/// Team / enterprise workspace lifecycle (**W1.1–W1.4** 最小入口)。
class TeamWorkspacesSection extends StatefulWidget {
  const TeamWorkspacesSection({super.key, required this.accessToken});

  final String? accessToken;

  @override
  State<TeamWorkspacesSection> createState() => _TeamWorkspacesSectionState();
}

class _TeamWorkspacesSectionState extends State<TeamWorkspacesSection> {
  final _nameController = TextEditingController();
  List<WorkspaceListItem>? _items;
  String? _error;
  bool _loading = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final token = widget.accessToken;
    if (token != null && token.isNotEmpty) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant TeamWorkspacesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = widget.accessToken;
    final oldToken = oldWidget.accessToken;
    if (token != oldToken) {
      if (token == null || token.isEmpty) {
        setState(() {
          _items = null;
          _error = null;
          _loading = false;
        });
      } else {
        _load();
      }
    }
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await fetchWorkspacesV1(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入企业空间名称')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      await createWorkspaceV1(token, CreateWorkspaceBody(name: name));
      _nameController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建企业空间')),
      );
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.accessToken;
    final theme = Theme.of(context);
    if (token == null || token.isEmpty) {
      return Text(
        '登录后可管理企业工作区。',
        style: theme.textTheme.bodyMedium,
      );
    }

    final items = _items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '团队工作区',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '列出你可访问的空间（含 Personal），并创建新的 enterprise 空间。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '企业空间名称',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _creating ? null : _create,
              child: Text(_creating ? '创建中…' : '创建'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_loading ? '加载中…' : '刷新列表'),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          SelectableText(
            _error!,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 8),
        if (items == null && !_loading)
          Text('尚无列表数据；点「刷新列表」。', style: theme.textTheme.bodySmall),
        if (items != null && items.isEmpty)
          Text('暂无空间（异常）；通常至少有 Personal。', style: theme.textTheme.bodySmall),
        if (items != null && items.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = items[index];
              final w = row.workspace;
              return ListTile(
                dense: true,
                title: Text(w.name),
                subtitle: Text(
                  '${w.workspaceType} · 角色 ${row.role}',
                ),
                trailing: Chip(
                  label: Text(row.role),
                  visualDensity: VisualDensity.compact,
                ),
              );
            },
          ),
      ],
    );
  }
}
