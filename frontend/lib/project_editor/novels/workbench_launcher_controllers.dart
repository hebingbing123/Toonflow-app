part of 'workbench_launcher.dart';

class _NovelWorkbenchControllers {
  const _NovelWorkbenchControllers({
    required this.searchCtrl,
    required this.searchIntakeStatusCtrl,
    required this.searchIntakeSourceCtrl,
    required this.importUrlCtrl,
    required this.importRawTextCtrl,
    required this.importBatchSizeCtrl,
    required this.importExecutionSideCtrl,
    required this.importIntakeStatusCtrl,
    required this.importIntakeNoteCtrl,
    required this.createChapterCtrl,
    required this.createBodyCtrl,
    required this.selectedNovelIdCtrl,
    required this.patchChapterCtrl,
    required this.patchBodyCtrl,
    required this.patchIntakeStatusCtrl,
    required this.patchIntakeSourceUrlCtrl,
    required this.patchIntakeNoteCtrl,
    required this.deleteNovelIdCtrl,
    required this.generateIdsCtrl,
    required this.numericIdsCtrl,
    required this.batchDeleteIdsCtrl,
    required this.batchAdmissionIdsCtrl,
    required this.batchAdmissionStatusCtrl,
    required this.batchAdmissionNoteCtrl,
  });

  factory _NovelWorkbenchControllers.fromItems({
    required List<NovelRow> currentItems,
    required NovelRow? first,
    required NovelRow? last,
  }) {
    return _NovelWorkbenchControllers(
      searchCtrl: TextEditingController(),
      searchIntakeStatusCtrl: TextEditingController(),
      searchIntakeSourceCtrl: TextEditingController(),
      importUrlCtrl: TextEditingController(),
      importRawTextCtrl: TextEditingController(),
      importBatchSizeCtrl: TextEditingController(text: '10'),
      importExecutionSideCtrl: TextEditingController(text: 'client'),
      importIntakeStatusCtrl: TextEditingController(text: 'pending_review'),
      importIntakeNoteCtrl: TextEditingController(),
      createChapterCtrl: TextEditingController(
        text: '章节_${DateTime.now().millisecondsSinceEpoch}',
      ),
      createBodyCtrl: TextEditingController(text: '在这里填写章节正文。'),
      selectedNovelIdCtrl: TextEditingController(
        text: first?.numericId.toString() ?? '',
      ),
      patchChapterCtrl: TextEditingController(text: first?.chapter ?? ''),
      patchBodyCtrl: TextEditingController(text: first?.chapterData ?? ''),
      patchIntakeStatusCtrl: TextEditingController(
        text: first?.intakeStatus ?? 'admitted',
      ),
      patchIntakeSourceUrlCtrl: TextEditingController(
        text: first?.intakeSourceUrl ?? '',
      ),
      patchIntakeNoteCtrl: TextEditingController(text: first?.intakeNote ?? ''),
      deleteNovelIdCtrl: TextEditingController(
        text: last?.numericId.toString() ?? '',
      ),
      generateIdsCtrl: TextEditingController(
        text: currentItems.take(3).map((e) => e.numericId).join(','),
      ),
      numericIdsCtrl: TextEditingController(
        text: currentItems.take(3).map((e) => e.numericId).join(','),
      ),
      batchDeleteIdsCtrl: TextEditingController(
        text: currentItems.skip(1).take(2).map((e) => e.numericId).join(','),
      ),
      batchAdmissionIdsCtrl: TextEditingController(
        text: currentItems.take(3).map((e) => e.numericId).join(','),
      ),
      batchAdmissionStatusCtrl: TextEditingController(text: 'pending_review'),
      batchAdmissionNoteCtrl: TextEditingController(),
    );
  }

  final TextEditingController searchCtrl;
  final TextEditingController searchIntakeStatusCtrl;
  final TextEditingController searchIntakeSourceCtrl;
  final TextEditingController importUrlCtrl;
  final TextEditingController importRawTextCtrl;
  final TextEditingController importBatchSizeCtrl;
  final TextEditingController importExecutionSideCtrl;
  final TextEditingController importIntakeStatusCtrl;
  final TextEditingController importIntakeNoteCtrl;
  final TextEditingController createChapterCtrl;
  final TextEditingController createBodyCtrl;
  final TextEditingController selectedNovelIdCtrl;
  final TextEditingController patchChapterCtrl;
  final TextEditingController patchBodyCtrl;
  final TextEditingController patchIntakeStatusCtrl;
  final TextEditingController patchIntakeSourceUrlCtrl;
  final TextEditingController patchIntakeNoteCtrl;
  final TextEditingController deleteNovelIdCtrl;
  final TextEditingController generateIdsCtrl;
  final TextEditingController numericIdsCtrl;
  final TextEditingController batchDeleteIdsCtrl;
  final TextEditingController batchAdmissionIdsCtrl;
  final TextEditingController batchAdmissionStatusCtrl;
  final TextEditingController batchAdmissionNoteCtrl;

  void dispose() {
    searchCtrl.dispose();
    searchIntakeStatusCtrl.dispose();
    searchIntakeSourceCtrl.dispose();
    importUrlCtrl.dispose();
    importRawTextCtrl.dispose();
    importBatchSizeCtrl.dispose();
    importExecutionSideCtrl.dispose();
    importIntakeStatusCtrl.dispose();
    importIntakeNoteCtrl.dispose();
    createChapterCtrl.dispose();
    createBodyCtrl.dispose();
    selectedNovelIdCtrl.dispose();
    patchChapterCtrl.dispose();
    patchBodyCtrl.dispose();
    patchIntakeStatusCtrl.dispose();
    patchIntakeSourceUrlCtrl.dispose();
    patchIntakeNoteCtrl.dispose();
    deleteNovelIdCtrl.dispose();
    generateIdsCtrl.dispose();
    numericIdsCtrl.dispose();
    batchDeleteIdsCtrl.dispose();
    batchAdmissionIdsCtrl.dispose();
    batchAdmissionStatusCtrl.dispose();
    batchAdmissionNoteCtrl.dispose();
  }
}
