import 'package:flutter/material.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import 'package:openflow_app/design_system/studio_responsive_layout.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../rust_api.dart';
import '../view.dart' show shortVideoPublishDraftStatusLabel;
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/tokens.dart';

/// Side-by-side comparison for 2–4 [PublishDraftRow] (title, copy, schedule, assets).
Future<void> showPublishDraftCompareDialog(
  BuildContext context, {
  required List<PublishDraftRow> drafts,
}) async {
  if (drafts.length < 2 || drafts.length > 4) {
    return;
  }
  await showStudioDialog<void>(
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final platformIds = _allPlatformIdsSorted(drafts);

    return StudioAlertDialog(
      title: Row(
        children: [
          const Icon(Icons.compare_arrows),
          const SizedBox(width: StudioSpacing.xs),
          Expanded(
            child: Text(l10n.shortVideoPublishDraftCompareTitle(drafts.length)),
          ),
        ],
      ),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 960),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.shortVideoPublishDraftCompareIntro,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: studioPanelMutedColor(context),
                ),
              ),
              const SizedBox(height: StudioSpacing.sm),
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
                                padding: const EdgeInsets.only(right: StudioSpacing.radiusComfort),
                                child: SizedBox(
                                  width: studioWrapTileWidth(
                                    constraints.maxWidth,
                                    maxColumns: drafts.length.clamp(1, 4),
                                    minTileWidth: 200,
                                    maxTileWidth: 280,
                                    gap: StudioSpacing.radiusComfort,
                                  ),
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
                            padding: const EdgeInsets.only(bottom: StudioSpacing.radiusComfort),
                            child: _DraftCompareCard(draft: d),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
              if (platformIds.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.sm),
                Text(
                  l10n.shortVideoPublishDraftComparePerPlatformHeading,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                ...platformIds.map((pid) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: StudioSpacing.radiusComfort),
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
          child: Text(l10n.shortVideoSpaceClose),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              draft.title.trim().isEmpty ? l10n.shortVideoPublishPanelUntitledDraft : draft.title,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.shortVideoPublishDraftCompareIdLine(_shortId(draft.id)),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            _kv(
              context,
              l10n.shortVideoPublishDraftCompareFieldStatus,
              shortVideoPublishDraftStatusLabel(l10n, draft.draftStatus),
            ),
            _kv(context, l10n.shortVideoPublishDraftCompareFieldScheduled, _formatScheduled(draft.scheduledAt)),
            _kv(context, l10n.shortVideoPublishDraftCompareFieldScript, _emptyAsDash(draft.scriptId)),
            _kv(context, l10n.shortVideoPublishDraftCompareFieldVideoAsset, _emptyAsDash(draft.videoAssetKey)),
            _kv(context, l10n.shortVideoPublishDraftCompareFieldCover, _emptyAsDash(draft.coverAssetKey)),
            const SizedBox(height: StudioSpacing.xs),
            Text(l10n.shortVideoPublishDraftCompareFieldSummary, style: theme.textTheme.labelSmall),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              draft.description.trim().isEmpty ? '—' : draft.description,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(l10n.shortVideoPublishDraftCompareFieldTags, style: theme.textTheme.labelSmall),
            const SizedBox(height: StudioSpacing.xs),
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
      padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              k,
              style: theme.textTheme.labelSmall?.copyWith(
                color: studioPanelMutedColor(context),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shortVideoPublishDraftComparePlatformTitle(platformId),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: StudioSpacing.xs),
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
                padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.inlineGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shortId(d.id),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoPublishDraftCompareCopyLineTitle(title),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      l10n.shortVideoPublishDraftCompareCopyLineDescription(desc),
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      l10n.shortVideoPublishDraftCompareCopyLineTags(tags),
                      style: theme.textTheme.bodySmall,
                    ),
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
