import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_editor/novels/import_parser.dart';

void main() {
  final zh = AppLocalizationsZh();

  test('parseWholeBookNovelText splits Chinese chapter headers', () {
    final rows = parseWholeBookNovelText(zh, '''
第一章 初见
她推开门，看见了雨。

第二章 回响
他没有回答，只是笑了笑。
''');

    expect(rows.length, 2);
    expect(rows[0].chapter, '第一章 初见');
    expect(rows[0].chapterData, contains('她推开门'));
    expect(rows[1].chapter, '第二章 回响');
  });

  test('parseWholeBookNovelText falls back to single chapter', () {
    final rows = parseWholeBookNovelText(zh, '没有章节标题，只有一整段正文。');

    expect(rows.length, 1);
    expect(rows.first.chapter, zh.projectEditorNovelImportFallbackChapterTitle(1));
    expect(rows.first.chapterData, '没有章节标题，只有一整段正文。');
  });

  test(
    'extractCrawlerContentFromHtml removes script and keeps readable text',
    () {
      final extracted = extractCrawlerContentFromHtml(zh, '''
<html>
  <head>
    <title>测试小说</title>
    <script>window.bad = true;</script>
    <style>.hidden { display:none; }</style>
  </head>
  <body>
    <article>
      第一章 初见
      她推开门。
    </article>
  </body>
</html>
''');

      expect(extracted.title, '测试小说');
      expect(extracted.bodyText, contains('第一章 初见'));
      expect(extracted.bodyText, isNot(contains('window.bad')));
      expect(extracted.nextPageUrl, isNull);
      expect(extracted.chapterUrls, isEmpty);
    },
  );

  test('extractCrawlerContentFromHtml removes crawler junk lines', () {
    final extracted = extractCrawlerContentFromHtml(zh, '''
<html>
  <head><title>测试站</title></head>
  <body>
    <div>第一章 开端</div>
    <div>请记住本站</div>
    <div>她推开门。</div>
    <div>点击下一页继续阅读</div>
  </body>
</html>
''');

    expect(extracted.bodyText, contains('第一章 开端'));
    expect(extracted.bodyText, contains('她推开门。'));
    expect(extracted.bodyText, isNot(contains('请记住本站')));
    expect(extracted.bodyText, isNot(contains('点击下一页')));
  });

  test(
    'reindexParsedNovelChapters trims and renumbers edited preview rows',
    () {
      final rows = reindexParsedNovelChapters(zh, [
        const ParsedNovelChapter(
          chapterIndex: 9,
          chapter: '  ',
          chapterData: '  第一段  ',
        ),
        const ParsedNovelChapter(
          chapterIndex: 12,
          chapter: '第二章 回响',
          chapterData: '\n\n第二段\n',
        ),
      ]);

      expect(rows.length, 2);
      expect(rows[0].chapterIndex, 1);
      expect(rows[0].chapter, zh.projectEditorNovelImportFallbackChapterTitle(1));
      expect(rows[0].chapterData, '第一段');
      expect(rows[1].chapterIndex, 2);
      expect(rows[1].chapter, '第二章 回响');
      expect(rows[1].chapterData, '第二段');
    },
  );

  test('reindexParsedNovelChapters can drop empty bodies before import', () {
    final rows = reindexParsedNovelChapters(zh, [
      const ParsedNovelChapter(
        chapterIndex: 1,
        chapter: '第一章',
        chapterData: '',
      ),
      const ParsedNovelChapter(
        chapterIndex: 2,
        chapter: '第二章',
        chapterData: '正文',
      ),
    ], dropEmptyBodies: true);

    expect(rows.length, 1);
    expect(rows.first.chapterIndex, 1);
    expect(rows.first.chapter, '第二章');
  });

  test('parseWholeBookNovelText supports 序章 and 番外 headers', () {
    final rows = parseWholeBookNovelText(zh, '''
序章
雨从凌晨开始下。

番外
多年以后，她又回到这扇门前。
''');

    expect(rows.length, 2);
    expect(rows[0].chapter, '序章');
    expect(rows[1].chapter, '番外');
  });

  test('evaluateNovelImportQuality blocks too short imports', () {
    final report = evaluateNovelImportQuality(zh, [
      const ParsedNovelChapter(
        chapterIndex: 1,
        chapter: '第一章',
        chapterData: '太短',
      ),
    ]);

    expect(report.canImport, isFalse);
    expect(report.blockers, isNotEmpty);
  });

  test('evaluateNovelImportQuality warns duplicated chapter content', () {
    final report = evaluateNovelImportQuality(
      zh,
      [
        const ParsedNovelChapter(
          chapterIndex: 1,
          chapter: '第一章',
          chapterData: '这是第一章的正文，长度足够用于测试。',
        ),
        const ParsedNovelChapter(
          chapterIndex: 2,
          chapter: '第二章',
          chapterData: '这是第一章的正文，长度足够用于测试。',
        ),
        const ParsedNovelChapter(
          chapterIndex: 3,
          chapter: '第三章',
          chapterData: '这是第三章的正文，内容不同且长度同样足够。',
        ),
      ],
      minTotalChars: 30,
      minAverageChapterChars: 10,
    );

    expect(report.canImport, isTrue);
    expect(report.warnings.join(' '), contains('重复正文'));
  });

  test('extractCrawlerContentFromHtml discovers next page url', () {
    final extracted = extractCrawlerContentFromHtml(
      zh,
      '''
<html>
  <head><title>分页正文</title></head>
  <body>
    <div>第一章 片段</div>
    <a href="/book/1?page=2">下一页</a>
  </body>
</html>
''',
      pageUri: Uri.parse('https://example.com/book/1?page=1'),
    );

    expect(extracted.nextPageUrl, 'https://example.com/book/1?page=2');
  });

  test('extractCrawlerContentFromHtml discovers chapter links from toc', () {
    final extracted = extractCrawlerContentFromHtml(
      zh,
      '''
<html>
  <head><title>目录</title></head>
  <body>
    <a href="/book/1/chapter-1">第一章 初见</a>
    <a href="/book/1/chapter-2">第二章 回响</a>
    <a href="https://evil.example.org/chapter-3">第三章</a>
  </body>
</html>
''',
      pageUri: Uri.parse('https://example.com/book/1/toc'),
    );

    expect(extracted.chapterUrls.length, 2);
    expect(extracted.chapterUrls[0], 'https://example.com/book/1/chapter-1');
    expect(extracted.chapterUrls[1], 'https://example.com/book/1/chapter-2');
  });
}
