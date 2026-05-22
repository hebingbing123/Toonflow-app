import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'import_parser.dart';

/// Client-side checkpoint when a whole-book import stops mid-batch.
class WholeBookImportCheckpoint {
  const WholeBookImportCheckpoint({
    required this.projectId,
    required this.sourceKey,
    required this.sourceDisplayName,
    required this.nextChapterListIndex,
    required this.totalChapters,
    required this.batchTag,
    required this.updatedAtMs,
    this.contentHash,
  });

  final String projectId;
  final String sourceKey;
  final String sourceDisplayName;
  final int nextChapterListIndex;
  final int totalChapters;
  final String batchTag;
  final int updatedAtMs;

  /// Stable fingerprint of decoded book text (filename-independent).
  final String? contentHash;

  bool get isComplete => nextChapterListIndex >= totalChapters;

  String get effectiveContentHash =>
      (contentHash != null && contentHash!.isNotEmpty)
      ? contentHash!
      : sourceKey;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'projectId': projectId,
    'sourceKey': sourceKey,
    'sourceDisplayName': sourceDisplayName,
    'nextChapterListIndex': nextChapterListIndex,
    'totalChapters': totalChapters,
    'batchTag': batchTag,
    'updatedAtMs': updatedAtMs,
    if (contentHash != null) 'contentHash': contentHash,
  };

  factory WholeBookImportCheckpoint.fromJson(Map<String, dynamic> json) {
    return WholeBookImportCheckpoint(
      projectId: json['projectId'] as String,
      sourceKey: json['sourceKey'] as String,
      sourceDisplayName: json['sourceDisplayName'] as String? ?? '',
      nextChapterListIndex: (json['nextChapterListIndex'] as num).toInt(),
      totalChapters: (json['totalChapters'] as num).toInt(),
      batchTag: json['batchTag'] as String,
      updatedAtMs: (json['updatedAtMs'] as num).toInt(),
      contentHash: json['contentHash'] as String?,
    );
  }
}

/// Parsed chapters stashed locally so paste/large-book resume need not re-read text.
class WholeBookImportStash {
  const WholeBookImportStash({
    required this.projectId,
    required this.contentHash,
    required this.chapters,
    required this.updatedAtMs,
  });

  final String projectId;
  final String contentHash;
  final List<ParsedNovelChapter> chapters;
  final int updatedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'projectId': projectId,
    'contentHash': contentHash,
    'chapters': <Map<String, dynamic>>[
      for (final c in chapters)
        <String, dynamic>{
          'chapterIndex': c.chapterIndex,
          'chapter': c.chapter,
          'chapterData': c.chapterData,
        },
    ],
    'updatedAtMs': updatedAtMs,
  };

  factory WholeBookImportStash.fromJson(Map<String, dynamic> json) {
    final raw = json['chapters'] as List<dynamic>? ?? const <dynamic>[];
    return WholeBookImportStash(
      projectId: json['projectId'] as String,
      contentHash: json['contentHash'] as String,
      chapters: <ParsedNovelChapter>[
        for (final item in raw)
          ParsedNovelChapter(
            chapterIndex: (item['chapterIndex'] as num).toInt(),
            chapter: item['chapter'] as String,
            chapterData: item['chapterData'] as String,
          ),
      ],
      updatedAtMs: (json['updatedAtMs'] as num).toInt(),
    );
  }
}

const String _kWholeBookImportCheckpointPrefsKey =
    'whole_book_import_checkpoint_v1';
const String _kWholeBookImportStashPrefsKey = 'whole_book_import_stash_v1';

/// Max chapters cached for in-place resume (avoids blowing SharedPreferences).
const int kWholeBookImportStashMaxChapters = 800;

/// Content fingerprint from decoded text (same book, different filename → same hash).
String wholeBookContentHash(String text) {
  final bytes = utf8.encode(text);
  var h = 2166136261;
  void mix(List<int> slice) {
    for (final b in slice) {
      h ^= b;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
  }
  if (bytes.length <= 65536) {
    mix(bytes);
  } else {
    mix(bytes.sublist(0, 32768));
    final mid = bytes.length ~/ 2;
    mix(bytes.sublist(mid, mid + 32768));
    mix(bytes.sublist(bytes.length - 32768));
    h ^= bytes.length;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

String wholeBookSourceKeyFromText(String text) =>
    wholeBookSourceKeyFromContentHash(wholeBookContentHash(text));

String wholeBookSourceKeyFromContentHash(String contentHash) => 'book:$contentHash';

/// Legacy file fingerprint (filename + size + head sample). Prefer [wholeBookContentHash].
String wholeBookLegacyFileSourceKey({
  required String? filename,
  required int byteLength,
  required List<int> bytes,
}) {
  var hash = byteLength;
  final sample = bytes.length <= 8192 ? bytes : bytes.sublist(0, 8192);
  for (final b in sample) {
    hash = 0x1fffffff & (hash + b);
    hash = 0x1fffffff & (hash + (hash << 10));
    hash ^= hash >> 6;
  }
  return '${filename ?? 'unknown'}|$byteLength|$hash';
}

/// Whether an interrupted import matches the current book (content-first, legacy key fallback).
bool wholeBookImportSourcesMatch(
  WholeBookImportCheckpoint checkpoint, {
  String? sourceKey,
  String? contentHash,
}) {
  final incomingHash = contentHash?.trim();
  final storedHash = checkpoint.contentHash?.trim();
  if (incomingHash != null &&
      incomingHash.isNotEmpty &&
      storedHash != null &&
      storedHash.isNotEmpty) {
    return incomingHash == storedHash;
  }
  if (sourceKey != null &&
      sourceKey.isNotEmpty &&
      sourceKey == checkpoint.sourceKey) {
    return true;
  }
  if (incomingHash != null &&
      incomingHash.isNotEmpty &&
      checkpoint.sourceKey == wholeBookSourceKeyFromContentHash(incomingHash)) {
    return true;
  }
  return false;
}

String wholeBookChapterDedupeKey(int chapterIndex, String chapterTitle) =>
    '$chapterIndex::${chapterTitle.trim().toLowerCase()}';

WholeBookImportCheckpoint _checkpointFromServerSession(
  String projectId,
  WholeBookImportSessionResponse session,
) {
  return WholeBookImportCheckpoint(
    projectId: projectId,
    sourceKey: wholeBookSourceKeyFromContentHash(session.contentHash),
    sourceDisplayName: session.sourceDisplayName,
    nextChapterListIndex: session.nextListIndex,
    totalChapters: session.totalChapters,
    batchTag: session.batchTag,
    updatedAtMs: session.updatedAtMs,
    contentHash: session.contentHash,
  );
}

/// Mirror server session into local prefs (offline UI hint; server is authoritative).
Future<void> syncWholeBookImportCheckpointFromServer({
  required String accessToken,
  required String projectId,
  required String contentHash,
  required String sourceKey,
  required String sourceDisplayName,
  required WholeBookImportSessionResponse session,
}) async {
  if (session.nextListIndex >= session.totalChapters) {
    await clearWholeBookImportCheckpoint();
    return;
  }
  await saveWholeBookImportCheckpoint(
    WholeBookImportCheckpoint(
      projectId: projectId,
      sourceKey: sourceKey,
      sourceDisplayName: sourceDisplayName,
      nextChapterListIndex: session.nextListIndex,
      totalChapters: session.totalChapters,
      batchTag: session.batchTag,
      updatedAtMs: session.updatedAtMs,
      contentHash: contentHash,
    ),
  );
}

/// Load resumable import progress (server-first for Web; local prefs fallback).
Future<WholeBookImportCheckpoint?> loadWholeBookImportCheckpoint(
  String projectId, {
  String? accessToken,
  String? contentHash,
}) async {
  if (accessToken != null && accessToken.isNotEmpty) {
    try {
      final session = await getProjectNovelWholeBookImportSession(
        accessToken,
        projectId,
        contentHash: contentHash,
      );
      if (session.nextListIndex >= session.totalChapters) {
        await clearWholeBookImportCheckpoint();
        return null;
      }
      final checkpoint = _checkpointFromServerSession(projectId, session);
      await saveWholeBookImportCheckpoint(checkpoint);
      return checkpoint;
    } on RustApiException catch (e) {
      if (e.statusCode != 404) {
        rethrow;
      }
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kWholeBookImportCheckpointPrefsKey);
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final map = jsonDecode(raw) as Map<String, dynamic>;
  final checkpoint = WholeBookImportCheckpoint.fromJson(map);
  if (checkpoint.projectId != projectId || checkpoint.isComplete) {
    return null;
  }
  if (contentHash != null &&
      contentHash.isNotEmpty &&
      checkpoint.effectiveContentHash != contentHash) {
    return null;
  }
  return checkpoint;
}

Future<void> saveWholeBookImportCheckpoint(WholeBookImportCheckpoint value) async {
  final prefs = await SharedPreferences.getInstance();
  if (value.isComplete) {
    await prefs.remove(_kWholeBookImportCheckpointPrefsKey);
    return;
  }
  await prefs.setString(
    _kWholeBookImportCheckpointPrefsKey,
    jsonEncode(value.toJson()),
  );
}

Future<void> clearWholeBookImportCheckpoint() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kWholeBookImportCheckpointPrefsKey);
}

Future<void> saveWholeBookImportStash({
  required String projectId,
  required String contentHash,
  required List<ParsedNovelChapter> chapters,
}) async {
  if (chapters.isEmpty || chapters.length > kWholeBookImportStashMaxChapters) {
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final stash = WholeBookImportStash(
    projectId: projectId,
    contentHash: contentHash,
    chapters: chapters,
    updatedAtMs: DateTime.now().millisecondsSinceEpoch,
  );
  await prefs.setString(
    _kWholeBookImportStashPrefsKey,
    jsonEncode(stash.toJson()),
  );
}

Future<WholeBookImportStash?> loadWholeBookImportStash(
  String projectId,
  String contentHash,
) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kWholeBookImportStashPrefsKey);
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final stash = WholeBookImportStash.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
  if (stash.projectId != projectId || stash.contentHash != contentHash) {
    return null;
  }
  return stash;
}

Future<bool> hasWholeBookImportStash(
  String projectId,
  String contentHash,
) async {
  final stash = await loadWholeBookImportStash(projectId, contentHash);
  return stash != null && stash.chapters.isNotEmpty;
}

Future<void> clearWholeBookImportStash() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_kWholeBookImportStashPrefsKey);
}

/// Chapters for resume from local stash or paste field (no file re-pick).
Future<List<ParsedNovelChapter>?> loadWholeBookResumeChapters({
  required AppLocalizations l10n,
  required String projectId,
  required WholeBookImportCheckpoint checkpoint,
  String? pasteText,
}) async {
  final hash = checkpoint.effectiveContentHash;
  final stash = await loadWholeBookImportStash(projectId, hash);
  if (stash != null && stash.chapters.isNotEmpty) {
    return stash.chapters;
  }
  final paste = pasteText?.trim() ?? '';
  if (paste.isNotEmpty && wholeBookContentHash(paste) == hash) {
    final rows = parseWholeBookNovelText(l10n, paste);
    if (rows.isNotEmpty) {
      return rows;
    }
  }
  return null;
}
