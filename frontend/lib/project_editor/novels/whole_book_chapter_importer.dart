import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'import_parser.dart';
import 'whole_book_import_resume.dart';

/// Result of importing parsed chapters (supports partial progress + resume).
class WholeBookChapterImportResult {
  const WholeBookChapterImportResult({
    required this.imported,
    required this.skippedExisting,
    required this.total,
    required this.failedAtIndex,
    required this.canResume,
    required this.batchTag,
  });

  final int imported;
  final int skippedExisting;
  final int total;
  final int? failedAtIndex;
  final bool canResume;
  final String batchTag;

  bool get succeeded => failedAtIndex == null && !canResume;
}

typedef WholeBookImportProgressCallback =
    void Function(int completed, int total, String message);

/// Import chapters via server session (Web + desktop); local stash caches chapter payloads.
Future<WholeBookChapterImportResult> importWholeBookChapters({
  required AppLocalizations l10n,
  required String accessToken,
  required String projectId,
  required List<ParsedNovelChapter> chapters,
  required String sourceKey,
  required String sourceDisplayName,
  required String contentHash,
  required String intakeStatus,
  String? intakeSourceUrl,
  String? intakeNote,
  int batchSize = 10,
  int startListIndex = 0,
  String? existingBatchTag,
  WholeBookImportProgressCallback? onProgress,
}) async {
  final normalized = reindexParsedNovelChapters(l10n, chapters);
  if (normalized.isEmpty) {
    throw FormatException(l10n.projectEditorNovelsActionErrorPreparseRequired);
  }
  final quality = evaluateNovelImportQuality(l10n, normalized);
  if (!quality.canImport) {
    throw FormatException(
      l10n.projectEditorNovelsActionErrorImportQuality(quality.blockers.join('；')),
    );
  }
  if (batchSize <= 0) {
    throw FormatException(l10n.projectEditorNovelsActionErrorBatchSizePositive);
  }

  await saveWholeBookImportStash(
    projectId: projectId,
    contentHash: contentHash,
    chapters: normalized,
  );

  var batchTag = existingBatchTag;
  var listIndex = startListIndex;
  var totalImported = 0;
  var totalSkipped = 0;
  int? failedAtIndex;

  while (listIndex < normalized.length) {
    final end = (listIndex + batchSize < normalized.length)
        ? listIndex + batchSize
        : normalized.length;
    final slice = normalized.sublist(listIndex, end);
    final items = <WholeBookImportChapterItem>[
      for (final chapter in slice)
        WholeBookImportChapterItem(
          chapterIndex: chapter.chapterIndex,
          chapter: chapter.chapter,
          chapterData: chapter.chapterData,
        ),
    ];

    final response = await postProjectNovelWholeBookImport(
      accessToken,
      projectId,
      contentHash: contentHash,
      totalChapters: normalized.length,
      chapters: items,
      intakeStatus: intakeStatus,
      sourceDisplayName: sourceDisplayName,
      batchTag: batchTag,
      startListIndex: listIndex,
      intakeSourceUrl: intakeSourceUrl,
      intakeNote: intakeNote,
    );

    batchTag = response.batchTag;
    totalImported += response.imported;
    totalSkipped += response.skippedExisting;
    listIndex = response.nextListIndex;

    onProgress?.call(
      listIndex,
      normalized.length,
      l10n.projectEditorNovelsActionImportProgress(
        listIndex,
        normalized.length,
      ),
    );

    await syncWholeBookImportCheckpointFromServer(
      accessToken: accessToken,
      projectId: projectId,
      contentHash: contentHash,
      sourceKey: sourceKey,
      sourceDisplayName: sourceDisplayName,
      session: WholeBookImportSessionResponse(
        contentHash: response.contentHash,
        sourceDisplayName: sourceDisplayName,
        batchTag: response.batchTag,
        nextListIndex: response.nextListIndex,
        totalChapters: response.totalChapters,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    if (response.failedAtListIndex != null) {
      failedAtIndex = response.failedAtListIndex;
      break;
    }
    if (response.completed) {
      break;
    }
  }

  final canResume =
      failedAtIndex != null || listIndex < normalized.length;
  if (!canResume) {
    await clearWholeBookImportCheckpoint();
    await clearWholeBookImportStash();
  }

  return WholeBookChapterImportResult(
    imported: totalImported,
    skippedExisting: totalSkipped,
    total: normalized.length,
    failedAtIndex: failedAtIndex,
    canResume: canResume,
    batchTag: batchTag ?? existingBatchTag ?? '',
  );
}
