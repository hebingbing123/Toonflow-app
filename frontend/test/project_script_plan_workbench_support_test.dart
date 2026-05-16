import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_editor/scripts/plan_workbench_support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  final zh = AppLocalizationsZh();

  test('summarizePlanEventCoverage reports event and chapter coverage', () {
    final summary = summarizePlanEventCoverage(
      l10n: zh,
      events: const [
        NovelEventRow(
          id: 'e1',
          projectId: 'p1',
          numericId: 1,
          name: '主角撞见秘密',
          detail: '身份暴露',
          chapterIndexes: [1, 2],
        ),
        NovelEventRow(
          id: 'e2',
          projectId: 'p1',
          numericId: 2,
          name: '反派施压',
          detail: '局势升级',
          chapterIndexes: [3],
        ),
      ],
      novels: [
        NovelRow(
          id: 'n1',
          numericId: 1,
          chapterIndex: 1,
          chapter: '第一章',
          chapterData: 'a',
          eventState: 0,
        ),
        NovelRow(
          id: 'n2',
          numericId: 2,
          chapterIndex: 2,
          chapter: '第二章',
          chapterData: 'b',
          eventState: 0,
        ),
        NovelRow(
          id: 'n3',
          numericId: 3,
          chapterIndex: 3,
          chapter: '第三章',
          chapterData: 'c',
          eventState: 0,
        ),
      ],
    );

    expect(summary, contains('当前 2 条事件'));
    expect(summary, contains('覆盖 3/3 条章节'));
    expect(summary, contains('主角撞见秘密'));
  });

  test('buildStorySkeletonSeedFromEvents uses current event rows', () {
    final seed = buildStorySkeletonSeedFromEvents(
      l10n: zh,
      events: const [
        NovelEventRow(
          id: 'e1',
          projectId: 'p1',
          numericId: 1,
          name: '主角撞见秘密',
          detail: '身份暴露，关系开始失衡。',
          chapterIndexes: [1, 2],
        ),
      ],
      novels: const [],
    );

    expect(seed, contains('核心推进'));
    expect(seed, contains('主角撞见秘密'));
    expect(seed, contains('身份暴露，关系开始失衡。'));
  });

  test('buildAdaptationStrategySeed includes deterministic constraints', () {
    final seed = buildAdaptationStrategySeedFromEvents(
      l10n: zh,
      events: const [],
      novels: const [],
    );

    expect(seed, contains('人物策略'));
    expect(seed, contains('节奏策略'));
    expect(seed, contains('对话要口语化'));
  });

  test('buildScriptDraftPackets derives draft scripts from events and plan', () {
    final drafts = buildScriptDraftPackets(
      l10n: zh,
      events: const [
        NovelEventRow(
          id: 'e1',
          projectId: 'p1',
          numericId: 1,
          name: '主角撞见秘密',
          detail: '身份暴露，关系开始失衡。',
          chapterIndexes: [1, 2],
        ),
        NovelEventRow(
          id: 'e2',
          projectId: 'p1',
          numericId: 2,
          name: '反派施压',
          detail: '主角被迫表态。',
          chapterIndexes: [3],
        ),
      ],
      novels: [
        NovelRow(
          id: 'n1',
          numericId: 1,
          chapterIndex: 1,
          chapter: '第一章',
          chapterData: '主角在宴会上看见了不该看见的人。',
          eventState: 0,
        ),
        NovelRow(
          id: 'n2',
          numericId: 2,
          chapterIndex: 2,
          chapter: '第二章',
          chapterData: '旧关系开始失衡，试探越来越明显。',
          eventState: 0,
        ),
        NovelRow(
          id: 'n3',
          numericId: 3,
          chapterIndex: 3,
          chapter: '第三章',
          chapterData: '反派逼主角站队，局势迅速升温。',
          eventState: 0,
        ),
      ],
      storySkeleton: '开场先抛钩子',
      adaptationStrategy: '对白口语化，情绪先压后扬',
      existingScripts: const [
        ScriptAgentPlanScriptRow(id: 1, name: '第1集', content: ''),
      ],
    );

    expect(drafts, isNotEmpty);
    expect(drafts.first.name, '第1集');
    expect(drafts.first.content, contains('【剧情节拍】'));
    expect(drafts.first.content, contains('主角撞见秘密'));
    expect(drafts.first.content, contains('对白口语化'));
  });

  test('summarizeScriptDraftPackets reports generated coverage', () {
    final summary = summarizeScriptDraftPackets(
      zh,
      const [
        ScriptDraftPacket(
          name: '第1集',
          content: 'a',
          chapterIndexes: [1, 2],
          eventNames: ['事件1'],
        ),
        ScriptDraftPacket(
          name: '第2集',
          content: 'b',
          chapterIndexes: [3],
          eventNames: ['事件2'],
        ),
      ],
    );

    expect(summary, contains('已生成 2 份剧本初稿'));
    expect(summary, contains('覆盖 3 条章节'));
  });

  test('buildStructuredRewriteGuidance adds anti-ai rewrite constraints', () {
    final guidanceRows = buildStructuredRewriteGuidance(
      l10n: zh,
      events: const [
        NovelEventRow(
          id: 'e1',
          projectId: 'p1',
          numericId: 1,
          name: '主角撞见秘密',
          detail: '身份暴露，关系开始失衡。',
          chapterIndexes: [1, 2],
        ),
      ],
      novels: [
        NovelRow(
          id: 'n1',
          numericId: 1,
          chapterIndex: 1,
          chapter: '第一章',
          chapterData: '主角在宴会上看见了不该看见的人。',
          eventState: 0,
        ),
      ],
      storySkeleton: '开场先抛钩子',
      adaptationStrategy: '对白口语化，情绪先压后扬',
      existingScripts: const [],
    );

    expect(guidanceRows, isNotEmpty);
    expect(guidanceRows.first.content, contains('【去 AI 味约束】'));
    expect(guidanceRows.first.content, contains('对白口语化'));
    expect(guidanceRows.first.content, contains('主角每场都要有明确刺激'));
  });

  test('summarizeStructuredRewriteGuidance reports generated count', () {
    final summary = summarizeStructuredRewriteGuidance(
      zh,
      const [
        StructuredRewriteGuidance(
          name: '第1集',
          chapterIndexes: [1],
          eventNames: ['事件1'],
          content: 'a',
        ),
      ],
    );

    expect(summary, contains('已生成 1 份结构化改写 guidance'));
  });
}
