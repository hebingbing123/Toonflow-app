import 'package:html/parser.dart' as html_parser;

class ParsedNovelChapter {
  const ParsedNovelChapter({
    required this.chapterIndex,
    required this.chapter,
    required this.chapterData,
  });

  final int chapterIndex;
  final String chapter;
  final String chapterData;

  ParsedNovelChapter copyWith({
    int? chapterIndex,
    String? chapter,
    String? chapterData,
  }) {
    return ParsedNovelChapter(
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapter: chapter ?? this.chapter,
      chapterData: chapterData ?? this.chapterData,
    );
  }
}

class ExtractedCrawlerContent {
  const ExtractedCrawlerContent({required this.title, required this.bodyText});

  final String title;
  final String bodyText;
}

final RegExp _chapterHeaderPattern = RegExp(
  r'^\s*(第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷][^\n\r]*)\s*$',
  multiLine: true,
);

ExtractedCrawlerContent extractCrawlerContentFromHtml(
  String rawHtml, {
  String fallbackTitle = '抓取正文',
}) {
  final document = html_parser.parse(rawHtml);
  document.querySelectorAll('script,style,noscript').forEach((node) {
    node.remove();
  });

  final title = (document.querySelector('title')?.text ?? fallbackTitle).trim();
  final bodyText = _normalizeExtractedText(document.body?.text ?? '');
  return ExtractedCrawlerContent(
    title: title.isEmpty ? fallbackTitle : title,
    bodyText: bodyText,
  );
}

String _normalizeExtractedText(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

List<ParsedNovelChapter> reindexParsedNovelChapters(
  Iterable<ParsedNovelChapter> rows, {
  bool dropEmptyBodies = false,
  String fallbackChapterPrefix = '导入章节',
}) {
  final normalized = <ParsedNovelChapter>[];
  for (final row in rows) {
    final chapter = row.chapter.trim();
    final chapterData = _normalizeExtractedText(row.chapterData);
    if (dropEmptyBodies && chapterData.isEmpty) {
      continue;
    }
    normalized.add(
      ParsedNovelChapter(
        chapterIndex: normalized.length + 1,
        chapter: chapter.isEmpty
            ? '$fallbackChapterPrefix ${normalized.length + 1}'
            : chapter,
        chapterData: chapterData,
      ),
    );
  }
  return normalized;
}

List<ParsedNovelChapter> parseWholeBookNovelText(
  String raw, {
  String fallbackChapterPrefix = '导入章节',
}) {
  final normalized = _normalizeExtractedText(raw);
  if (normalized.isEmpty) {
    return const <ParsedNovelChapter>[];
  }

  final matches = _chapterHeaderPattern.allMatches(normalized).toList();
  if (matches.isEmpty) {
    return reindexParsedNovelChapters(
      <ParsedNovelChapter>[
        ParsedNovelChapter(
          chapterIndex: 1,
          chapter: '$fallbackChapterPrefix 1',
          chapterData: normalized,
        ),
      ],
      dropEmptyBodies: true,
      fallbackChapterPrefix: fallbackChapterPrefix,
    );
  }

  final chapters = <ParsedNovelChapter>[];
  for (var i = 0; i < matches.length; i += 1) {
    final match = matches[i];
    final title = match.group(1)?.trim() ?? '$fallbackChapterPrefix ${i + 1}';
    final bodyStart = match.end;
    final bodyEnd = i + 1 < matches.length
        ? matches[i + 1].start
        : normalized.length;
    final body = normalized.substring(bodyStart, bodyEnd).trim();
    if (body.isEmpty) {
      continue;
    }
    chapters.add(
      ParsedNovelChapter(
        chapterIndex: chapters.length + 1,
        chapter: title,
        chapterData: body,
      ),
    );
  }

  if (chapters.isEmpty) {
    return reindexParsedNovelChapters(
      <ParsedNovelChapter>[
        ParsedNovelChapter(
          chapterIndex: 1,
          chapter: '$fallbackChapterPrefix 1',
          chapterData: normalized,
        ),
      ],
      dropEmptyBodies: true,
      fallbackChapterPrefix: fallbackChapterPrefix,
    );
  }
  return reindexParsedNovelChapters(
    chapters,
    dropEmptyBodies: true,
    fallbackChapterPrefix: fallbackChapterPrefix,
  );
}
