import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/novels/whole_book_import_resume.dart';

void main() {
  test('wholeBookContentHash is stable for same text', () {
    const text = '第一章\n正文\n\n第二章\n更多';
    expect(wholeBookContentHash(text), wholeBookContentHash(text));
  });

  test('wholeBookImportSourcesMatch ignores filename when content hash matches', () {
    const text = '第一章\n正文';
    final hash = wholeBookContentHash(text);
    final checkpoint = WholeBookImportCheckpoint(
      projectId: 'p1',
      sourceKey: 'oldname.txt|100|999',
      sourceDisplayName: 'oldname.txt',
      nextChapterListIndex: 3,
      totalChapters: 10,
      batchTag: 'batch',
      updatedAtMs: 1,
      contentHash: hash,
    );
    expect(
      wholeBookImportSourcesMatch(
        checkpoint,
        contentHash: hash,
        sourceKey: wholeBookSourceKeyFromContentHash(hash),
      ),
      isTrue,
    );
    expect(
      wholeBookImportSourcesMatch(
        checkpoint,
        contentHash: wholeBookContentHash('different'),
      ),
      isFalse,
    );
  });
}
