import 'package:flutter/material.dart';

import '../../rust_api/project/publish_models.dart';

/// Side-by-side comparison for 2–4 [PublishDraftRow] (title, copy, schedule, assets).
Future<void> showPublishDraftCompareDialog(
  BuildContext context, {
  required List<PublishDraftRow> drafts,
}) async {
  if (drafts.length < 2 || drafts.length > 4) {
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (ctx) => _PublishDraftCompareDialog(drafts: drafts),
  );
}

String _shortId(String id) {
  final t = id.trim();
  if (t.length <= 12) {
    return t;
  }
  return '${t.substring(0, 10)}…';
}

String _emptyAsDash(String? value) {
  final t = value?.trim() ?? '';
  return t.isEmpty ? '—' : t;
}

String _formatScheduled(String? iso) {
  if (iso == null || iso.trim().isEmpty) {
    return '—';
  }
  final parsed = DateTime.tryParse(iso.trim());
  if (parsed == null) {
    return iso;
  }
  final local = parsed.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

List<String> _allPlatformIdsSorted(List<PublishDraftRow> drafts) {
  final ids = <String>{};
  for (final d in drafts) {
    final pc = d.platformCopy;
    if (pc != null) {
      ids.addAll(pc.keys);
    }
  }
  final sorted = ids.toList()..sort();
  return sorted;
}

Map<String, dynamic>? _copyBlock(
  Map<String, dynamic>? platformCopy,
  String platformId,
) {
  if (platformCopy == null) {
    return null;
  }
  final raw = platformCopy[platformId];
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return null;
}

String _tagsLine(List<String> tags) {
  if (tags.isEmpty) {
    return '—';
  }
  return tags.join(', ');
}

class _PublishDraftCompareDialog extends StatelessWidget {
  const _PublishDraftCompareDialog({required this.drafts});

  final List<PublishDraftRow> drafts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformIds = _allPlatformIdsSorted(drafts);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.compare_arrows),
          const SizedBox(width: 8),
          Expanded(
            child: Text('发布草稿对比（${drafts.length}）'),
          ),
        ],
      ),
      content: SizedBox(
        width: 960,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '按当前多选顺序展示。可核对标题、定时、资产键与分平台文案差异。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useRow = constraints.maxWidth >= 720;
                  if (useRow) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: drafts
                            .map(
                              (d) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 220,
                                  child: _DraftCompareCard(draft: d),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: drafts
                        .map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DraftCompareCard(draft: d),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              if (platformIds.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '分平台文案（title / description / tags）',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...platformIds.map((pid) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlatformCopyCompareSection(
                      platformId: pid,
                      drafts: drafts,
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _DraftCompareCard extends StatelessWidget {
  const _DraftCompareCard({required this.draft});

  final PublishDraftRow draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.title.trim().isEmpty ? '（无标题）' : draft.title,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'ID: ${_shortId(draft.id)}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            _kv(context, '状态', draft.draftStatus),
            _kv(context, '定时', _formatScheduled(draft.scheduledAt)),
            _kv(context, '剧本', _emptyAsDash(draft.scriptId)),
            _kv(context, '视频资产', _emptyAsDash(draft.videoAssetKey)),
            _kv(context, '封面', _emptyAsDash(draft.coverAssetKey)),
            const SizedBox(height: 8),
            Text('简介', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              draft.description.trim().isEmpty ? '—' : draft.description,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('标签', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              _tagsLine(draft.tags),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              k,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(v, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _PlatformCopyCompareSection extends StatelessWidget {
  const _PlatformCopyCompareSection({
    required this.platformId,
    required this.drafts,
  });

  final String platformId;
  final List<PublishDraftRow> drafts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '平台 $platformId',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...drafts.map((d) {
              final block = _copyBlock(d.platformCopy, platformId);
              final title = _emptyAsDash(block?['title'] as String?);
              final desc = _emptyAsDash(block?['description'] as String?);
              final tagsRaw = block?['tags'];
              var tags = '—';
              if (tagsRaw is List) {
                tags = tagsRaw.map((e) => '$e').join(', ');
                if (tags.isEmpty) {
                  tags = '—';
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortId(d.id),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('title: $title', style: theme.textTheme.bodySmall),
                    Text('description: $desc', style: theme.textTheme.bodySmall),
                    Text('tags: $tags', style: theme.textTheme.bodySmall),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
