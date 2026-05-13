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
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  final chapterCount = novels.length;
  final header = <String>[
    '开场钩子：',
    chapterCount == 0
        ? '用一句话交代主角所处困局，并在前 30 秒抛出反常动作或危险信号。'
        : '围绕前 ${chapterCount >= 3 ? 3 : chapterCount} 条章节快速建立人物处境，并在首屏给出强钩子。',
    '',
    '核心推进：',
  ];
  final body = events.isEmpty
      ? <String>[
          '- 先从章节中提炼 3-5 个关键事件节点，按“冲突升级 -> 误判 -> 反转”排序。',
          '- 每个节点只保留推动人物关系或局势变化的动作，不要复述原文。',
        ]
      : events
            .take(6)
            .map(
              (event) =>
                  '- ${event.name}（章节 ${event.chapterIndexes.join(', ')}）：${event.detail.trim().isEmpty ? '补充该事件如何改变人物处境与下一步目标。' : event.detail.trim()}',
            )
            .toList();
  final footer = <String>['', '结尾翻点：', '- 让最后一个节点留下未兑现的情绪账或更大的外部压力，形成下一集追更动机。'];
  return [...header, ...body, ...footer].join('\n');
}

String buildAdaptationStrategySeedFromEvents({
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  final eventCount = events.length;
  final chapterCount = novels.length;
  return [
    '人物策略：',
    '- 主角情绪变化要有台阶，不要从头到尾同一强度；每次反应都对应具体刺激。',
    '- 配角只保留能放大主角选择压力的人物，避免信息型路人。',
    '',
    '节奏策略：',
    eventCount == 0
        ? '- 先按章节切出 3-5 个强动作节点，再压缩成短剧节奏。'
        : '- 当前已有 $eventCount 条事件，优先保留冲突强、身份变化大、情绪反差明显的节点。',
    chapterCount == 0
        ? '- 保持单集只解决一个核心问题，并把更大的危机留到尾部。'
        : '- 当前 $chapterCount 条章节不做平铺直叙，按“前快中压后翻”重排信息释放。',
    '',
    '表达策略：',
    '- 对话要口语化、有目的，避免解释剧情式复述。',
    '- 画面与动作优先服务人物状态和情绪变化，不做空镜头堆砌。',
  ].join('\n');
}

List<ScriptDraftPacket> buildScriptDraftPackets({
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
    final name = _resolveDraftName(existingScripts, index);
    final content = _buildDraftContent(
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
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
  required String storySkeleton,
  required String adaptationStrategy,
  required List<ScriptAgentPlanScriptRow> existingScripts,
}) {
  final drafts = buildScriptDraftPackets(
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

String _resolveDraftName(List<ScriptAgentPlanScriptRow> existingScripts, int index) {
  final existing = index < existingScripts.length
      ? existingScripts[index].name?.trim() ?? ''
      : '';
  if (existing.isNotEmpty) {
    return existing;
  }
  return '第${index + 1}集';
}

String _buildDraftContent({
  required String packetName,
  required _DraftChunk chunk,
  required List<int> chapterIndexes,
  required List<String> eventNames,
  required Map<int, NovelRow> novelByChapter,
  required String storySkeleton,
  required String adaptationStrategy,
}) {
  final chapterSummary = chapterIndexes.isEmpty
      ? '待补章节依据'
      : chapterIndexes
            .map((index) {
              final novel = novelByChapter[index];
              final title = novel?.chapter.trim();
              return title == null || title.isEmpty ? '章节 $index' : '章节 $index《$title》';
            })
            .join(' / ');
  final skeletonHint = _firstMeaningfulLine(
    storySkeleton,
    fallback: '前段快速抛钩子，中段连续加压，尾段留下更大的情绪账。',
  );
  final strategyHint = _firstMeaningfulLine(
    adaptationStrategy,
    fallback: '对白口语化、动作带情绪、信息通过冲突释放。',
  );
  final beatLines = chunk.events.isEmpty
      ? chapterIndexes
            .map((index) {
              final novel = novelByChapter[index];
              return '- 从 ${novel?.chapter.trim().isEmpty ?? true ? '章节 $index' : '《${novel!.chapter.trim()}》'} 提炼一个能推动关系或处境变化的动作节点。';
            })
            .toList(growable: false)
      : chunk.events
            .map(
              (event) => '- ${event.name.trim().isEmpty ? '关键事件' : event.name.trim()}：${event.detail.trim().isEmpty ? '补充该事件带来的情绪变化、行动选择和局势变化。' : event.detail.trim()}',
            )
            .toList(growable: false);
  final scenePrompts = _buildScenePrompts(
    chapterIndexes: chapterIndexes,
    novelByChapter: novelByChapter,
  );
  final endingHook = eventNames.isEmpty
      ? '在最后一个动作后补一个未说透的发现、误会或反击前奏。'
      : '把“${eventNames.last}”后的余波留到结尾，让人物以为稳住了，实际更危险。';
  return [
    '【剧本定位】',
    '$packetName：围绕 $chapterSummary 压缩成一集短剧，首屏先给冲突，结尾必须留钩子。',
    '',
    '【骨架约束】',
    skeletonHint,
    '',
    '【改编口径】',
    strategyHint,
    '',
    '【剧情节拍】',
    ...beatLines,
    '',
    '【场次草稿】',
    ...scenePrompts,
    '',
    '【对白要求】',
    '- 每段对白都带目的，不解释观众已经能从动作看懂的信息。',
    '- 人物情绪要有起伏，先忍、再顶、再露底牌，避免全程一个腔调。',
    '',
    '【结尾钩子】',
    endingHook,
  ].join('\n');
}

String _buildStructuredRewriteContent({
  required ScriptDraftPacket draft,
  required Map<int, NovelRow> novelByChapter,
  required String storySkeleton,
  required String adaptationStrategy,
}) {
  final skeletonHint = _firstMeaningfulLine(
    storySkeleton,
    fallback: '先把主角困局和最大冲突抛到最前面，别平推背景说明。',
  );
  final strategyHint = _firstMeaningfulLine(
    adaptationStrategy,
    fallback: '对白口语化、动作外化情绪、信息跟着冲突走。',
  );
  final chapterLines = draft.chapterIndexes.isEmpty
      ? const <String>['- 优先围绕最强冲突改写，不够戏剧性的原文说明直接压缩。']
      : draft.chapterIndexes.map((index) {
          final novel = novelByChapter[index];
          final excerpt = _compactText(novel?.chapterData ?? '', maxChars: 42);
          final title = novel?.chapter.trim();
          return '- 章节 $index${title == null || title.isEmpty ? '' : '《$title》'}：${excerpt.isEmpty ? '只保留能推动冲突或人物关系变化的动作。' : '围绕“$excerpt”改成可拍的动作和情绪交锋。'}';
        }).toList(growable: false);
  final eventLines = draft.eventNames.isEmpty
      ? const <String>[
          '- 先补出 3 个节点：抛钩子、压迫升级、尾部反转或悬念。',
        ]
      : draft.eventNames
          .map((name) => '- 事件“$name”必须带来情绪或局势变化，不能只做信息通报。')
          .toList(growable: false);
  return [
    '【改写目标】',
    skeletonHint,
    '',
    '【改写策略】',
    strategyHint,
    '',
    '【章节压缩指令】',
    ...chapterLines,
    '',
    '【事件改写指令】',
    ...eventLines,
    '',
    '【人物情绪】',
    '- 主角每场都要有明确刺激、反应和下一步动作，情绪不能整集一个平面。',
    '- 配角发言要推动主角选择，不留解释剧情的空对白。',
    '',
    '【去 AI 味约束】',
    '- 少写总结句、价值判断句和书面连接词，改成口语化冲突表达。',
    '- 画面先写动作、视线、停顿、压迫感来源，再补必要对白。',
    '- 同一场里不要连续三句都在解释背景，让信息藏进试探、误会和逼问。',
  ].join('\n');
}

List<String> _buildScenePrompts({
  required List<int> chapterIndexes,
  required Map<int, NovelRow> novelByChapter,
}) {
  if (chapterIndexes.isEmpty) {
    return const <String>[
      '- 场1：用一个反常动作或外部威胁开场，把主角直接推入选择。',
      '- 场2：让关键关系失衡，冲突不要靠旁白解释。',
      '- 场3：用情绪反转收尾，并留下下一集必须追的悬念。',
    ];
  }
  return List<String>.generate(chapterIndexes.length, (index) {
    final chapterIndex = chapterIndexes[index];
    final novel = novelByChapter[chapterIndex];
    final title = novel?.chapter.trim();
    final excerpt = _compactText(novel?.chapterData ?? '', maxChars: 56);
    return '- 场${index + 1}：${title == null || title.isEmpty ? '章节 $chapterIndex' : '《$title》'}${excerpt.isEmpty ? '' : '，抓住“$excerpt”里的动作和情绪做可拍场面'}。';
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
