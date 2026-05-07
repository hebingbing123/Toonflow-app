import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/scripts/plan_workbench_support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('summarizePlanEventCoverage reports event and chapter coverage', () {
    final summary = summarizePlanEventCoverage(
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
      events: const [],
      novels: const [],
    );

    expect(seed, contains('人物策略'));
    expect(seed, contains('节奏策略'));
    expect(seed, contains('对话要口语化'));
  });
}
