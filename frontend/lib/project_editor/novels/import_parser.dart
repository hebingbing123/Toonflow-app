class ParsedNovelChapter {
  const ParsedNovelChapter({
    required this.chapterIndex,
    required this.chapter,
    required this.chapterData,
  });

  final int chapterIndex;
  final String chapter;
  final String chapterData;
}

final RegExp _chapterHeaderPattern = RegExp(
  r'^\s*(第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷][^\n\r]*)\s*$',
  multiLine: true,
);

List<ParsedNovelChapter> parseWholeBookNovelText(
  String raw, {
  String fallbackChapterPrefix = '导入章节',
}) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return const <ParsedNovelChapter>[];
  }

  final matches = _chapterHeaderPattern.allMatches(normalized).toList();
  if (matches.isEmpty) {
    return <ParsedNovelChapter>[
      ParsedNovelChapter(
        chapterIndex: 1,
        chapter: '$fallbackChapterPrefix 1',
        chapterData: normalized,
      ),
    ];
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
    return <ParsedNovelChapter>[
      ParsedNovelChapter(
        chapterIndex: 1,
        chapter: '$fallbackChapterPrefix 1',
        chapterData: normalized,
      ),
    ];
  }
  return chapters;
}
