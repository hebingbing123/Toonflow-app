import 'package:html/parser.dart' as html_parser;

import '../../l10n/app_localizations.dart';
import '../../platform/studio_content_heuristics.dart';

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

ExtractedCrawlerContent extractCrawlerContentFromHtml(
  AppLocalizations l10n,
  String rawHtml, {
  String? fallbackTitle,
  Uri? pageUri,
}) {
  final resolvedFallback =
      (fallbackTitle == null || fallbackTitle.trim().isEmpty)
      ? l10n.projectEditorNovelImportCrawlerBodyFallbackTitle
      : fallbackTitle.trim();
  final document = html_parser.parse(rawHtml);
  document.querySelectorAll('script,style,noscript').forEach((node) {
    node.remove();
  });

  final title = (document.querySelector('title')?.text ?? resolvedFallback).trim();
  final bodyText = _normalizeExtractedText(document.body?.text ?? '');
  final nextPageUrl = _discoverNextPageUrl(document, pageUri);
  final chapterUrls = _discoverChapterUrls(document, pageUri);
  return ExtractedCrawlerContent(
    title: title.isEmpty ? resolvedFallback : title,
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
        studioContentContainsAny(text, kNovelCrawlNextPageLinkTexts) ||
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
  final chapterLabelPattern = kNovelCrawlChapterLabelPattern;
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
      .where((line) => !kNovelCrawlJunkLinePattern.hasMatch(line))
      .toList(growable: false);
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

NovelImportQualityReport evaluateNovelImportQuality(
  AppLocalizations l10n,
  Iterable<ParsedNovelChapter> rows, {
  int minTotalChars = 200,
  int minAverageChapterChars = 50,
  int maxDuplicateBodyRatioPercent = 40,
}) {
  final chapters = reindexParsedNovelChapters(
    l10n,
    rows,
    dropEmptyBodies: true,
  );
  if (chapters.isEmpty) {
    return NovelImportQualityReport(
      blockers: <String>[l10n.projectEditorNovelImportQualityNoChaptersBlocker],
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
    blockers.add(
      l10n.projectEditorNovelImportQualityTotalCharsTooLowBlocker(totalChars),
    );
  }
  if (avgChars < minAverageChapterChars) {
    blockers.add(
      l10n.projectEditorNovelImportQualityAvgCharsTooLowBlocker(avgChars),
    );
  }

  final uniqueBodies = bodyTexts.toSet();
  final duplicateCount = bodyTexts.length - uniqueBodies.length;
  final duplicateRatioPercent = (duplicateCount * 100) ~/ bodyTexts.length;
  if (duplicateRatioPercent >= maxDuplicateBodyRatioPercent) {
    blockers.add(
      l10n.projectEditorNovelImportQualityDuplicateHighBlocker(
        duplicateRatioPercent,
      ),
    );
  } else if (duplicateRatioPercent > 0) {
    warnings.add(
      l10n.projectEditorNovelImportQualityDuplicatePartialWarning(
        duplicateRatioPercent,
      ),
    );
  }

  if (chapters.length == 1) {
    warnings.add(l10n.projectEditorNovelImportQualitySingleChapterWarning);
  }
  if (chapters.length > 300) {
    warnings.add(
      l10n.projectEditorNovelImportQualityManyChaptersWarning(chapters.length),
    );
  }

  return NovelImportQualityReport(
    blockers: blockers,
    warnings: warnings,
  );
}

List<ParsedNovelChapter> reindexParsedNovelChapters(
  AppLocalizations l10n,
  Iterable<ParsedNovelChapter> rows, {
  bool dropEmptyBodies = false,
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
            ? l10n.projectEditorNovelImportFallbackChapterTitle(
                normalized.length + 1,
              )
            : chapter,
        chapterData: chapterData,
      ),
    );
  }
  return normalized;
}

List<ParsedNovelChapter> parseWholeBookNovelText(
  AppLocalizations l10n,
  String raw,
) {
  final normalized = _normalizeExtractedText(raw);
  if (normalized.isEmpty) {
    return const <ParsedNovelChapter>[];
  }

  final matches = kNovelCrawlChapterHeaderPattern.allMatches(normalized).toList();
  if (matches.isEmpty) {
    return reindexParsedNovelChapters(
      l10n,
      <ParsedNovelChapter>[
        ParsedNovelChapter(
          chapterIndex: 1,
          chapter: l10n.projectEditorNovelImportFallbackChapterTitle(1),
          chapterData: normalized,
        ),
      ],
      dropEmptyBodies: true,
    );
  }

  final chapters = <ParsedNovelChapter>[];
  for (var i = 0; i < matches.length; i += 1) {
    final match = matches[i];
    final title =
        match.group(1)?.trim() ??
        l10n.projectEditorNovelImportFallbackChapterTitle(i + 1);
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
      l10n,
      <ParsedNovelChapter>[
        ParsedNovelChapter(
          chapterIndex: 1,
          chapter: l10n.projectEditorNovelImportFallbackChapterTitle(1),
          chapterData: normalized,
        ),
      ],
      dropEmptyBodies: true,
    );
  }
  return reindexParsedNovelChapters(
    l10n,
    chapters,
    dropEmptyBodies: true,
  );
}
