part of 'workbench_launcher.dart';

class _NovelWorkbenchControllers {
  const _NovelWorkbenchControllers({
    required this.searchCtrl,
    required this.createChapterCtrl,
    required this.createBodyCtrl,
    required this.selectedNovelIdCtrl,
    required this.patchChapterCtrl,
    required this.patchBodyCtrl,
    required this.deleteNovelIdCtrl,
    required this.generateIdsCtrl,
    required this.numericIdsCtrl,
    required this.batchDeleteIdsCtrl,
  });

  factory _NovelWorkbenchControllers.fromItems({
    required List<NovelRow> currentItems,
    required NovelRow? first,
    required NovelRow? last,
  }) {
    return _NovelWorkbenchControllers(
      searchCtrl: TextEditingController(),
      createChapterCtrl: TextEditingController(
        text: '章节_${DateTime.now().millisecondsSinceEpoch}',
      ),
      createBodyCtrl: TextEditingController(text: '在这里填写章节正文。'),
      selectedNovelIdCtrl: TextEditingController(
        text: first?.numericId.toString() ?? '',
      ),
      patchChapterCtrl: TextEditingController(text: first?.chapter ?? ''),
      patchBodyCtrl: TextEditingController(text: first?.chapterData ?? ''),
      deleteNovelIdCtrl: TextEditingController(text: last?.numericId.toString() ?? ''),
      generateIdsCtrl: TextEditingController(
        text: currentItems.take(3).map((e) => e.numericId).join(','),
      ),
      numericIdsCtrl: TextEditingController(
        text: currentItems.take(3).map((e) => e.numericId).join(','),
      ),
      batchDeleteIdsCtrl: TextEditingController(
        text: currentItems.skip(1).take(2).map((e) => e.numericId).join(','),
      ),
    );
  }

  final TextEditingController searchCtrl;
  final TextEditingController createChapterCtrl;
  final TextEditingController createBodyCtrl;
  final TextEditingController selectedNovelIdCtrl;
  final TextEditingController patchChapterCtrl;
  final TextEditingController patchBodyCtrl;
  final TextEditingController deleteNovelIdCtrl;
  final TextEditingController generateIdsCtrl;
  final TextEditingController numericIdsCtrl;
  final TextEditingController batchDeleteIdsCtrl;

  void dispose() {
    searchCtrl.dispose();
    createChapterCtrl.dispose();
    createBodyCtrl.dispose();
    selectedNovelIdCtrl.dispose();
    patchChapterCtrl.dispose();
    patchBodyCtrl.dispose();
    deleteNovelIdCtrl.dispose();
    generateIdsCtrl.dispose();
    numericIdsCtrl.dispose();
    batchDeleteIdsCtrl.dispose();
  }
}

