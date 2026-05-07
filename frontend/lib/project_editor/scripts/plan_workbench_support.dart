import '../../rust_api.dart';

String summarizePlanEventCoverage({
  required List<NovelEventRow> events,
  required List<NovelRow> novels,
}) {
  if (events.isEmpty) {
    return novels.isEmpty
        ? '当前还没有章节与事件，可先从内容接入区导入并生成事件。'
        : '当前有 ${novels.length} 条章节，但还没有事件；建议先生成事件后再整理骨架。';
  }
  final coveredChapterIndexes = <int>{
    for (final event in events) ...event.chapterIndexes,
  };
  final totalChapters = novels.length;
  final coverageText = totalChapters == 0
      ? '暂未加载章节'
      : '覆盖 ${coveredChapterIndexes.length}/$totalChapters 条章节';
  final sample = events.take(3).map((row) => row.name).join(' / ');
  return '当前 ${events.length} 条事件，$coverageText${sample.isEmpty ? '' : ' · $sample'}';
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
