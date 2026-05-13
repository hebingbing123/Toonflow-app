import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';

class ScriptDraftPacket {
  const ScriptDraftPacket({
    required this.name,
    required this.content,
    required this.chapterIndexes,
    required this.eventNames,
  });

  final String name;
  final String content;
  final List<int> chapterIndexes;
  final List<String> eventNames;
}

class StructuredRewriteGuidance {
  const StructuredRewriteGuidance({
    required this.name,
    required this.chapterIndexes,
    required this.eventNames,
    required this.content,
  });

  final String name;
  final List<int> chapterIndexes;
  final List<String> eventNames;
  final String content;
}

String summarizePlanEventCoverage({
  required AppLocalizations l10n,
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  if (events.isEmpty) {
    return novels.isEmpty
        ? l10n.projectScriptPlanCoverageNoChaptersNoEvents
        : l10n.projectScriptPlanCoverageChaptersNoEventsYet(novels.length);
  }
  final coveredChapterIndexes = <int>{
    for (final event in events) ...event.chapterIndexes,
  };
  final totalChapters = novels.length;
  final coverageText = totalChapters == 0
      ? l10n.projectScriptPlanCoverageChaptersNotLoaded
      : l10n.projectScriptPlanCoverageChaptersProgress(
          coveredChapterIndexes.length,
          totalChapters,
        );
  final sample = events.take(3).map((row) => row.name).join(' / ');
  final sampleSuffix = sample.isEmpty ? '' : ' · $sample';
  return l10n.projectScriptPlanCoverageEventsSummary(
    events.length,
    coverageText,
    sampleSuffix,
  );
}

String buildStorySkeletonSeedFromEvents({
  required AppLocalizations l10n,
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  final chapterCount = novels.length;
  final chapterSpan = chapterCount >= 3 ? 3 : chapterCount;
  final header = <String>[
    l10n.projectScriptPlanSkeletonOpeningHookLabel,
    chapterCount == 0
        ? l10n.projectScriptPlanSkeletonOpeningHookZeroChapters
        : l10n.projectScriptPlanSkeletonOpeningHookWithChapters(chapterSpan),
    '',
    l10n.projectScriptPlanSkeletonCorePushLabel,
  ];
  final body = events.isEmpty
      ? <String>[
          l10n.projectScriptPlanSkeletonCoreEmptyLine1,
          l10n.projectScriptPlanSkeletonCoreEmptyLine2,
        ]
      : events
            .take(6)
            .map(
              (event) => l10n.projectScriptPlanSkeletonEventLine(
                event.name,
                event.chapterIndexes.join(', '),
                event.detail.trim().isEmpty
                    ? l10n.projectScriptPlanSkeletonEventDetailFallback
                    : event.detail.trim(),
              ),
            )
            .toList();
  final footer = <String>[
    '',
    l10n.projectScriptPlanSkeletonClosingLabel,
    l10n.projectScriptPlanSkeletonClosingBullet,
  ];
  return [...header, ...body, ...footer].join('\n');
}

String buildAdaptationStrategySeedFromEvents({
  required AppLocalizations l10n,
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  final eventCount = events.length;
  final chapterCount = novels.length;
  return [
    l10n.projectScriptPlanAdaptPeopleLabel,
    l10n.projectScriptPlanAdaptPeopleLine1,
    l10n.projectScriptPlanAdaptPeopleLine2,
    '',
    l10n.projectScriptPlanAdaptPacingLabel,
    eventCount == 0
        ? l10n.projectScriptPlanAdaptPacingNoEvents
        : l10n.projectScriptPlanAdaptPacingWithEvents(eventCount),
    chapterCount == 0
        ? l10n.projectScriptPlanAdaptPacingNoChapters
        : l10n.projectScriptPlanAdaptPacingWithChapters(chapterCount),
    '',
    l10n.projectScriptPlanAdaptVoiceLabel,
    l10n.projectScriptPlanAdaptVoiceLine1,
    l10n.projectScriptPlanAdaptVoiceLine2,
  ].join('\n');
}

List<ScriptDraftPacket> buildScriptDraftPackets({
  required AppLocalizations l10n,
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
  required String storySkeleton,
  required String adaptationStrategy,
  required List<ScriptAgentPlanScriptRow> existingScripts,
}) {
  final sortedNovels = [...novels]..sort(
    (left, right) => left.chapterIndex.compareTo(right.chapterIndex),
  );
  final novelByChapter = <int, NovelRow>{
    for (final novel in sortedNovels) novel.chapterIndex: novel,
  };
  final cleanedSkeleton = storySkeleton.trim();
  final cleanedStrategy = adaptationStrategy.trim();
  final chunks = events.isNotEmpty
      ? _buildEventChunks(events: events, existingScripts: existingScripts)
      : _buildNovelChunks(novels: sortedNovels, existingScripts: existingScripts);
  return List<ScriptDraftPacket>.generate(chunks.length, (index) {
    final chunk = chunks[index];
    final chapterIndexes = <int>{
      for (final event in chunk.events) ...event.chapterIndexes,
      ...chunk.chapterIndexes,
    }.toList()
      ..sort();
    final eventNames = chunk.events
        .map((event) => event.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final name = _resolveDraftName(l10n, existingScripts, index);
    final content = _buildDraftContent(
      l10n: l10n,
      packetName: name,
      chunk: chunk,
      chapterIndexes: chapterIndexes,
      eventNames: eventNames,
      novelByChapter: novelByChapter,
      storySkeleton: cleanedSkeleton,
      adaptationStrategy: cleanedStrategy,
    );
    return ScriptDraftPacket(
      name: name,
      content: content,
      chapterIndexes: chapterIndexes,
      eventNames: eventNames,
    );
  }, growable: false);
}

String summarizeScriptDraftPackets(
  AppLocalizations l10n,
  List<ScriptDraftPacket> drafts,
) {
  if (drafts.isEmpty) {
    return l10n.projectScriptPlanDraftsSummaryEmpty;
  }
  final chapterCoverage = <int>{for (final draft in drafts) ...draft.chapterIndexes};
  final sample = drafts.take(3).map((draft) => draft.name).join(' / ');
  final sampleSuffix = sample.isEmpty ? '' : ' · $sample';
  return l10n.projectScriptPlanDraftsSummary(
    drafts.length,
    chapterCoverage.length,
    sampleSuffix,
  );
}

List<StructuredRewriteGuidance> buildStructuredRewriteGuidance({
  required AppLocalizations l10n,
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
  required String storySkeleton,
  required String adaptationStrategy,
  required List<ScriptAgentPlanScriptRow> existingScripts,
}) {
  final drafts = buildScriptDraftPackets(
    l10n: l10n,
    events: events,
    novels: novels,
    storySkeleton: storySkeleton,
    adaptationStrategy: adaptationStrategy,
    existingScripts: existingScripts,
  );
  final sortedNovels = [...novels]..sort(
    (left, right) => left.chapterIndex.compareTo(right.chapterIndex),
  );
  final novelByChapter = <int, NovelRow>{
    for (final novel in sortedNovels) novel.chapterIndex: novel,
  };
  return drafts
      .map(
        (draft) => StructuredRewriteGuidance(
          name: draft.name,
          chapterIndexes: draft.chapterIndexes,
          eventNames: draft.eventNames,
          content: _buildStructuredRewriteContent(
            l10n: l10n,
            draft: draft,
            novelByChapter: novelByChapter,
            storySkeleton: storySkeleton,
            adaptationStrategy: adaptationStrategy,
          ),
        ),
      )
      .toList(growable: false);
}

String summarizeStructuredRewriteGuidance(
  AppLocalizations l10n,
  List<StructuredRewriteGuidance> guidanceRows,
) {
  if (guidanceRows.isEmpty) {
    return l10n.projectScriptPlanGuidanceSummaryEmpty;
  }
  final sample = guidanceRows.take(3).map((row) => row.name).join(' / ');
  final sampleSuffix = sample.isEmpty ? '' : ' · $sample';
  return l10n.projectScriptPlanGuidanceSummary(
    guidanceRows.length,
    sampleSuffix,
  );
}

class _DraftChunk {
  const _DraftChunk({
    required this.events,
    required this.chapterIndexes,
  });

  final List<NovelEventRow> events;
  final List<int> chapterIndexes;
}

List<_DraftChunk> _buildEventChunks({
  required List<NovelEventRow> events,
  required List<ScriptAgentPlanScriptRow> existingScripts,
}) {
  final sortedEvents = [...events]..sort(
    (left, right) => left.numericId.compareTo(right.numericId),
  );
  final targetCount = existingScripts.isNotEmpty
      ? existingScripts.length.clamp(1, 8)
      : ((sortedEvents.length + 1) ~/ 2).clamp(1, 8);
  final chunkSize = (sortedEvents.length / targetCount).ceil().clamp(1, 3);
  final chunks = <_DraftChunk>[];
  for (var start = 0; start < sortedEvents.length; start += chunkSize) {
    final slice = sortedEvents.sublist(
      start,
      (start + chunkSize).clamp(0, sortedEvents.length),
    );
    final chapterIndexes = <int>{
      for (final event in slice) ...event.chapterIndexes,
    }.toList()
      ..sort();
    chunks.add(_DraftChunk(events: slice, chapterIndexes: chapterIndexes));
  }
  return chunks;
}

List<_DraftChunk> _buildNovelChunks({
  required List<NovelRow> novels,
  required List<ScriptAgentPlanScriptRow> existingScripts,
}) {
  if (novels.isEmpty) {
    return const <_DraftChunk>[];
  }
  final targetCount = existingScripts.isNotEmpty
      ? existingScripts.length.clamp(1, 8)
      : (novels.length / 3).ceil().clamp(1, 8);
  final chunkSize = (novels.length / targetCount).ceil().clamp(1, 4);
  final chunks = <_DraftChunk>[];
  for (var start = 0; start < novels.length; start += chunkSize) {
    final slice = novels.sublist(
      start,
      (start + chunkSize).clamp(0, novels.length),
    );
    chunks.add(
      _DraftChunk(
        events: const <NovelEventRow>[],
        chapterIndexes: slice
            .map((novel) => novel.chapterIndex)
            .toList(growable: false),
      ),
    );
  }
  return chunks;
}

String _resolveDraftName(
  AppLocalizations l10n,
  List<ScriptAgentPlanScriptRow> existingScripts,
  int index,
) {
  final existing = index < existingScripts.length
      ? existingScripts[index].name?.trim() ?? ''
      : '';
  if (existing.isNotEmpty) {
    return existing;
  }
  return l10n.projectScriptPlanDraftEpisodeNumbered(index + 1);
}

String _buildDraftContent({
  required AppLocalizations l10n,
  required String packetName,
  required _DraftChunk chunk,
  required List<int> chapterIndexes,
  required List<String> eventNames,
  required Map<int, NovelRow> novelByChapter,
  required String storySkeleton,
  required String adaptationStrategy,
}) {
  final chapterSummary = chapterIndexes.isEmpty
      ? l10n.projectScriptPlanDraftChapterPendingSummary
      : chapterIndexes
            .map((index) {
              final novel = novelByChapter[index];
              final title = novel?.chapter.trim();
              return title == null || title.isEmpty
                  ? l10n.projectScriptPlanDraftChapterSummaryPlainIndex(index)
                  : l10n.projectScriptPlanDraftChapterSummaryTitled(index, title);
            })
            .join(' / ');
  final skeletonHint = _firstMeaningfulLine(
    storySkeleton,
    fallback: l10n.projectScriptPlanDraftSkeletonFallback,
  );
  final strategyHint = _firstMeaningfulLine(
    adaptationStrategy,
    fallback: l10n.projectScriptPlanDraftStrategyFallback,
  );
  final beatLines = chunk.events.isEmpty
      ? chapterIndexes
            .map((index) {
              final novel = novelByChapter[index];
              final plain = (novel?.chapter ?? '').trim().isEmpty;
              return plain
                  ? l10n.projectScriptPlanDraftBeatFromChapterPlain(index)
                  : l10n.projectScriptPlanDraftBeatFromChapterTitled(
                      novel!.chapter.trim(),
                    );
            })
            .toList(growable: false)
      : chunk.events
            .map(
              (event) {
                final name = event.name.trim().isEmpty
                    ? l10n.projectScriptPlanDraftEventNameFallback
                    : event.name.trim();
                final detail = event.detail.trim().isEmpty
                    ? l10n.projectScriptPlanDraftEventDetailFallback
                    : event.detail.trim();
                return l10n.projectScriptPlanDraftEventBeat(name, detail);
              },
            )
            .toList(growable: false);
  final scenePrompts = _buildScenePrompts(
    l10n: l10n,
    chapterIndexes: chapterIndexes,
    novelByChapter: novelByChapter,
  );
  final endingHook = eventNames.isEmpty
      ? l10n.projectScriptPlanDraftEndingNoEvents
      : l10n.projectScriptPlanDraftEndingAfterEvent(eventNames.last);
  return [
    l10n.projectScriptPlanDraftHdrPositioning,
    l10n.projectScriptPlanDraftPositioningBody(packetName, chapterSummary),
    '',
    l10n.projectScriptPlanDraftHdrSkeleton,
    skeletonHint,
    '',
    l10n.projectScriptPlanDraftHdrAdaptation,
    strategyHint,
    '',
    l10n.projectScriptPlanDraftHdrBeats,
    ...beatLines,
    '',
    l10n.projectScriptPlanDraftHdrScenes,
    ...scenePrompts,
    '',
    l10n.projectScriptPlanDraftHdrDialogue,
    l10n.projectScriptPlanDraftDialogueLine1,
    l10n.projectScriptPlanDraftDialogueLine2,
    '',
    l10n.projectScriptPlanDraftHdrEnding,
    endingHook,
  ].join('\n');
}

String _buildStructuredRewriteContent({
  required AppLocalizations l10n,
  required ScriptDraftPacket draft,
  required Map<int, NovelRow> novelByChapter,
  required String storySkeleton,
  required String adaptationStrategy,
}) {
  final skeletonHint = _firstMeaningfulLine(
    storySkeleton,
    fallback: l10n.projectScriptPlanRewriteSkeletonFallback,
  );
  final strategyHint = _firstMeaningfulLine(
    adaptationStrategy,
    fallback: l10n.projectScriptPlanRewriteStrategyFallback,
  );
  final chapterLines = draft.chapterIndexes.isEmpty
      ? <String>[l10n.projectScriptPlanRewriteChapterWhenNoIndexes]
      : draft.chapterIndexes.map((index) {
          final novel = novelByChapter[index];
          final excerpt = _compactText(novel?.chapterData ?? '', maxChars: 42);
          final title = novel?.chapter.trim();
          if (title == null || title.isEmpty) {
            return excerpt.isEmpty
                ? l10n.projectScriptPlanRewriteChapterPlainEmptyExcerpt(index)
                : l10n.projectScriptPlanRewriteChapterPlainWithExcerpt(
                    index,
                    excerpt,
                  );
          }
          return excerpt.isEmpty
              ? l10n.projectScriptPlanRewriteChapterTitledEmptyExcerpt(index, title)
              : l10n.projectScriptPlanRewriteChapterTitledWithExcerpt(
                  index,
                  title,
                  excerpt,
                );
        }).toList(growable: false);
  final eventLines = draft.eventNames.isEmpty
      ? <String>[l10n.projectScriptPlanRewriteEventDefault]
      : draft.eventNames
          .map((name) => l10n.projectScriptPlanRewriteEventNamed(name))
          .toList(growable: false);
  return [
    l10n.projectScriptPlanRewriteHdrGoal,
    skeletonHint,
    '',
    l10n.projectScriptPlanRewriteHdrStrategy,
    strategyHint,
    '',
    l10n.projectScriptPlanRewriteHdrChapters,
    ...chapterLines,
    '',
    l10n.projectScriptPlanRewriteHdrEvents,
    ...eventLines,
    '',
    l10n.projectScriptPlanRewriteHdrPeople,
    l10n.projectScriptPlanRewritePeopleLine1,
    l10n.projectScriptPlanRewritePeopleLine2,
    '',
    l10n.projectScriptPlanRewriteHdrDeAi,
    l10n.projectScriptPlanRewriteDeAiLine1,
    l10n.projectScriptPlanRewriteDeAiLine2,
    l10n.projectScriptPlanRewriteDeAiLine3,
  ].join('\n');
}

List<String> _buildScenePrompts({
  required AppLocalizations l10n,
  required List<int> chapterIndexes,
  required Map<int, NovelRow> novelByChapter,
}) {
  if (chapterIndexes.isEmpty) {
    return <String>[
      l10n.projectScriptPlanDraftSceneDefault1,
      l10n.projectScriptPlanDraftSceneDefault2,
      l10n.projectScriptPlanDraftSceneDefault3,
    ];
  }
  return List<String>.generate(chapterIndexes.length, (index) {
    final sceneNumber = index + 1;
    final chapterIndex = chapterIndexes[index];
    final novel = novelByChapter[chapterIndex];
    final title = novel?.chapter.trim();
    final excerpt = _compactText(novel?.chapterData ?? '', maxChars: 56);
    if (title == null || title.isEmpty) {
      return l10n.projectScriptPlanDraftSceneChapterOnly(sceneNumber, chapterIndex);
    }
    if (excerpt.isEmpty) {
      return l10n.projectScriptPlanDraftSceneTitleNoExcerpt(sceneNumber, title);
    }
    return l10n.projectScriptPlanDraftSceneTitleWithExcerpt(
      sceneNumber,
      title,
      excerpt,
    );
  }, growable: false);
}

String _firstMeaningfulLine(String raw, {required String fallback}) {
  for (final line in raw.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final compact = trimmed.startsWith('- ') ? trimmed.substring(2).trim() : trimmed;
    if (compact.isNotEmpty) {
      return compact;
    }
  }
  return fallback;
}

String _compactText(String raw, {required int maxChars}) {
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxChars) {
    return compact;
  }
  return '${compact.substring(0, maxChars)}...';
}
