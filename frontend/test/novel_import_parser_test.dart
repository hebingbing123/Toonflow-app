import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/novels/import_parser.dart';

void main() {
  test('parseWholeBookNovelText splits Chinese chapter headers', () {
    final rows = parseWholeBookNovelText('''
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
    final rows = parseWholeBookNovelText('没有章节标题，只有一整段正文。');

    expect(rows.length, 1);
    expect(rows.first.chapter, '导入章节 1');
    expect(rows.first.chapterData, '没有章节标题，只有一整段正文。');
  });

  test('extractCrawlerContentFromHtml removes script and keeps readable text', () {
    final extracted = extractCrawlerContentFromHtml('''
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
  });
}
