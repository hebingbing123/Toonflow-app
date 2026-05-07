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
  const ExtractedCrawlerContent({
    required this.title,
    required this.bodyText,
    this.nextPageUrl,
    this.chapterUrls = const <String>[],
  });

  final String title;
  final String bodyText;
  final String? nextPageUrl;
  final List<String> chapterUrls;
}

class NovelImportQualityReport {
  const NovelImportQualityReport({
    required this.blockers,
    required this.warnings,
  });

  final List<String> blockers;
  final List<String> warnings;

  bool get canImport => blockers.isEmpty;
}

final RegExp _chapterHeaderPattern = RegExp(
  r'^\s*((?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|(?:序章|尾声|番外))(?:[^\n\r]{0,36}))\s*$',
  multiLine: true,
);

final RegExp _junkLinePattern = RegExp(
  r'(?:收藏本站|最新网址|手机阅读|本章未完|点击下一页|上一章|下一章|广告|版权归|请记住本站)',
  caseSensitive: false,
);

ExtractedCrawlerContent extractCrawlerContentFromHtml(
  String rawHtml, {
  String fallbackTitle = '抓取正文',
  Uri? pageUri,
}) {
  final document = html_parser.parse(rawHtml);
  document.querySelectorAll('script,style,noscript').forEach((node) {
    node.remove();
  });

  final title = (document.querySelector('title')?.text ?? fallbackTitle).trim();
  final bodyText = _normalizeExtractedText(document.body?.text ?? '');
  final nextPageUrl = _discoverNextPageUrl(document, pageUri);
  final chapterUrls = _discoverChapterUrls(document, pageUri);
  return ExtractedCrawlerContent(
    title: title.isEmpty ? fallbackTitle : title,
    bodyText: bodyText,
    nextPageUrl: nextPageUrl,
    chapterUrls: chapterUrls,
  );
}

String? _discoverNextPageUrl(dynamic document, Uri? pageUri) {
  final anchors = document.querySelectorAll('a');
  for (final anchor in anchors) {
    final rel = (anchor.attributes['rel'] ?? '').toLowerCase().trim();
    final text = (anchor.text ?? '').trim().toLowerCase();
    if (rel == 'next' ||
        text.contains('下一页') ||
        text.contains('下页') ||
        text == 'next') {
      final href = (anchor.attributes['href'] ?? '').trim();
      final normalized = _normalizeDiscoveredUrl(href, pageUri);
      if (normalized != null) {
        return normalized;
      }
    }
  }
  return null;
}

List<String> _discoverChapterUrls(dynamic document, Uri? pageUri) {
  final chapterLabelPattern = RegExp(
    r'(?:第[0-9零一二三四五六七八九十百千万两〇]+[章节回集部篇卷]|序章|尾声|番外)',
  );
  final discovered = <String>{};
  final anchors = document.querySelectorAll('a');
  for (final anchor in anchors) {
    final text = (anchor.text ?? '').trim();
    final href = (anchor.attributes['href'] ?? '').trim();
    if (text.isEmpty || href.isEmpty) {
      continue;
    }
    final seemsChapter = chapterLabelPattern.hasMatch(text);
    final lowerHref = href.toLowerCase();
    final seemsChapterHref =
        lowerHref.contains('/chapter') ||
        lowerHref.contains('/read') ||
        lowerHref.contains('chapter=');
    if (!seemsChapter && !seemsChapterHref) {
      continue;
    }
    final normalized = _normalizeDiscoveredUrl(href, pageUri);
    if (normalized == null) {
      continue;
    }
    discovered.add(normalized);
    if (discovered.length >= 80) {
      break;
    }
  }
  return discovered.toList(growable: false);
}

String? _normalizeDiscoveredUrl(String href, Uri? pageUri) {
  if (href.isEmpty ||
      href.startsWith('#') ||
      href.startsWith('javascript:') ||
      href.startsWith('mailto:')) {
    return null;
  }
  final uri = Uri.tryParse(href);
  if (uri == null) {
    return null;
  }
  final resolved = pageUri == null
      ? uri
      : (uri.hasScheme ? uri : pageUri.resolveUri(uri));
  if (!(resolved.isScheme('http') || resolved.isScheme('https'))) {
    return null;
  }
  if (pageUri != null && resolved.host != pageUri.host) {
    return null;
  }
  return resolved.toString();
}

String _normalizeExtractedText(String raw) {
  final normalized = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\u00a0', ' ')
      .replaceAll('\u200b', '')
      .replaceAll('\u3000', ' ');
  final lines = normalized
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .where((line) => !_junkLinePattern.hasMatch(line))
      .toList(growable: false);
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

NovelImportQualityReport evaluateNovelImportQuality(
  Iterable<ParsedNovelChapter> rows, {
  int minTotalChars = 200,
  int minAverageChapterChars = 50,
  int maxDuplicateBodyRatioPercent = 40,
}) {
  final chapters = reindexParsedNovelChapters(rows, dropEmptyBodies: true);
  if (chapters.isEmpty) {
    return const NovelImportQualityReport(
      blockers: <String>['没有可导入的正文章节'],
      warnings: <String>[],
    );
  }

  final blockers = <String>[];
  final warnings = <String>[];
  final bodyTexts = chapters
      .map((row) => _normalizeExtractedText(row.chapterData))
      .where((body) => body.isNotEmpty)
      .toList(growable: false);
  final totalChars = bodyTexts.fold<int>(0, (sum, body) => sum + body.length);
  final avgChars = totalChars ~/ bodyTexts.length;

  if (totalChars < minTotalChars) {
    blockers.add('正文总字数过少（$totalChars），疑似抽取失败');
  }
  if (avgChars < minAverageChapterChars) {
    blockers.add('平均章节字数过少（$avgChars），请先检查切章结果');
  }

  final uniqueBodies = bodyTexts.toSet();
  final duplicateCount = bodyTexts.length - uniqueBodies.length;
  final duplicateRatioPercent = (duplicateCount * 100) ~/ bodyTexts.length;
  if (duplicateRatioPercent >= maxDuplicateBodyRatioPercent) {
    blockers.add('章节正文重复比例过高（$duplicateRatioPercent%）');
  } else if (duplicateRatioPercent > 0) {
    warnings.add('检测到部分重复正文（$duplicateRatioPercent%）');
  }

  if (chapters.length == 1) {
    warnings.add('仅识别到 1 章，可能是整本未正确切章');
  }
  if (chapters.length > 300) {
    warnings.add('章节数较多（${chapters.length}），建议抽样检查切章准确性');
  }

  return NovelImportQualityReport(
    blockers: blockers,
    warnings: warnings,
  );
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
