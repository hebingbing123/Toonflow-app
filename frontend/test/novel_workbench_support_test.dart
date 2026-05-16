import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_editor/novels/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  final zh = AppLocalizationsZh();

  test('summarizeNovelRows compacts loaded chapters', () {
    final summary = summarizeNovelRows(zh, [
      NovelRow(
        id: 'n1',
        numericId: 11,
        chapterIndex: 1,
        chapter: '第一章',
        chapterData: 'a',
        eventState: 0,
      ),
      NovelRow(
        id: 'n2',
        numericId: 12,
        chapterIndex: 2,
        chapter: '第二章',
        chapterData: 'b',
        eventState: 0,
      ),
      NovelRow(
        id: 'n3',
        numericId: 13,
        chapterIndex: 3,
        chapter: '第三章',
        chapterData: 'c',
        eventState: 0,
      ),
      NovelRow(
        id: 'n4',
        numericId: 14,
        chapterIndex: 4,
        chapter: '第四章',
        chapterData: 'd',
        eventState: 0,
      ),
      NovelRow(
        id: 'n5',
        numericId: 15,
        chapterIndex: 5,
        chapter: '第五章',
        chapterData: 'e',
        eventState: 0,
      ),
    ]);

    expect(
      summary,
      zh.projectEditorNovelsSummaryChaptersLine(
        5,
        '#11:第一章, #12:第二章, #13:第三章, #14:第四章',
        '…',
      ),
    );
  });

  test('summarizeNovelRows handles empty data', () {
    expect(summarizeNovelRows(zh, const []), zh.projectEditorNovelsSummaryNoChapters);
  });

  test('summarizeNovelIntakeRows reports status and source distribution', () {
    final summary = summarizeNovelIntakeRows(zh, [
      NovelRow(
        id: 'n1',
        numericId: 11,
        chapterIndex: 1,
        chapter: '第一章',
        chapterData: 'a',
        eventState: 0,
        intakeStatus: 'admitted',
        intakeSource: 'manual',
      ),
      NovelRow(
        id: 'n2',
        numericId: 12,
        chapterIndex: 2,
        chapter: '第二章',
        chapterData: 'b',
        eventState: 0,
        intakeStatus: 'pending_review',
        intakeSource: 'crawler_client',
      ),
      NovelRow(
        id: 'n3',
        numericId: 13,
        chapterIndex: 3,
        chapter: '第三章',
        chapterData: 'c',
        eventState: 0,
        intakeStatus: 'rejected',
        intakeSource: 'crawler_client',
      ),
      NovelRow(
        id: 'n4',
        numericId: 14,
        chapterIndex: 4,
        chapter: '第四章',
        chapterData: 'd',
        eventState: 0,
        intakeStatus: 'admitted',
        intakeSource: 'whole_book_import',
      ),
      NovelRow(
        id: 'n5',
        numericId: 15,
        chapterIndex: 5,
        chapter: '第五章',
        chapterData: 'e',
        eventState: 0,
        intakeStatus: 'pending_review',
        intakeSource: 'crawler_server',
      ),
    ]);

    expect(
      summary,
      zh.projectEditorNovelsSummaryIntakeCounts(2, 2, 1, 1, 1, 2, 1),
    );
  });

  test('summarizeNovelIntakeRows handles empty data', () {
    expect(
      summarizeNovelIntakeRows(zh, const []),
      zh.projectEditorNovelsSummaryIntakeEmptyBaseline,
    );
  });

  test('summarizeNovelEventRows compacts loaded events', () {
    final summary = summarizeNovelEventRows(zh, const [
      NovelEventRow(
        id: 'e1',
        projectId: 'p1',
        numericId: 21,
        name: '事件一',
        detail: 'a',
        chapterIndexes: [1],
      ),
      NovelEventRow(
        id: 'e2',
        projectId: 'p1',
        numericId: 22,
        name: '事件二',
        detail: 'b',
        chapterIndexes: [2],
      ),
      NovelEventRow(
        id: 'e3',
        projectId: 'p1',
        numericId: 23,
        name: '事件三',
        detail: 'c',
        chapterIndexes: [3],
      ),
      NovelEventRow(
        id: 'e4',
        projectId: 'p1',
        numericId: 24,
        name: '事件四',
        detail: 'd',
        chapterIndexes: [4],
      ),
    ]);

    expect(
      summary,
      zh.projectEditorNovelsSummaryEventsLine(
        4,
        '#21:事件一, #22:事件二, #23:事件三',
        '…',
      ),
    );
  });

  test('summarizeNovelEventRows handles empty data', () {
    expect(
      summarizeNovelEventRows(zh, const []),
      zh.projectEditorNovelsSummaryNoEvents,
    );
  });

  test('pickEventGeneratableNovelIds returns admitted chapters only', () {
    final ids = pickEventGeneratableNovelIds([
      NovelRow(
        id: 'n1',
        numericId: 11,
        chapterIndex: 1,
        chapter: '第一章',
        chapterData: 'a',
        eventState: 0,
        intakeStatus: 'pending_review',
      ),
      NovelRow(
        id: 'n2',
        numericId: 12,
        chapterIndex: 2,
        chapter: '第二章',
        chapterData: 'b',
        eventState: 0,
        intakeStatus: 'admitted',
      ),
      NovelRow(
        id: 'n3',
        numericId: 13,
        chapterIndex: 3,
        chapter: '第三章',
        chapterData: 'c',
        eventState: 0,
        intakeStatus: 'rejected',
      ),
      NovelRow(
        id: 'n4',
        numericId: 14,
        chapterIndex: 4,
        chapter: '第四章',
        chapterData: 'd',
        eventState: 0,
        intakeStatus: 'admitted',
      ),
    ], maxCount: 3);

    expect(ids, [12, 14]);
  });
}
