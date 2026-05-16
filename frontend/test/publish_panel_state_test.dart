import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api/project/publish_models.dart';
import 'package:openflow_app/short_video_space/publish_copy_editor.dart';
import 'package:openflow_app/short_video_space/support_publish_api.dart';
import 'package:openflow_app/short_video_space/view.dart';

void main() {
  final zh = AppLocalizationsZh();

  Widget appWithZh({required Widget child}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  Widget buildCopyEditorHarness({
    required String draftId,
    required List<String> domesticPlatformIds,
    required List<String> overseasPlatformIds,
    required Map<String, dynamic> platformCopy,
    Map<String, String> platformLabels = const {
      'douyin': '抖音',
      'youtube': 'YouTube',
      'bilibili': 'bilibili',
    },
    PublishPlatformCopyCommit? onCommit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PublishPlatformCopyEditor(
          draftId: draftId,
          domesticPlatformIds: domesticPlatformIds,
          overseasPlatformIds: overseasPlatformIds,
          platformLabels: platformLabels,
          platformCopy: platformCopy,
          busy: false,
          onCommit:
              onCommit ?? (platformId, title, description, tagsComma) async {},
        ),
      ),
    );
  }

  Widget buildDraftEditorSectionHarness({
    required ShortVideoPublishPanelUi publishPanelUi,
  }) {
    final normalizedUi = ShortVideoPublishPanelUi(
      visible: true,
      loading: publishPanelUi.loading,
      unavailable: publishPanelUi.unavailable,
      headline: publishPanelUi.headline,
      exportGateHint: publishPanelUi.exportGateHint,
      exportReady: publishPanelUi.exportReady,
      detail: publishPanelUi.detail,
      matrixDomesticLines: publishPanelUi.matrixDomesticLines,
      matrixOverseasLines: publishPanelUi.matrixOverseasLines,
      prepareLines: publishPanelUi.prepareLines,
      publishOverviewLines: publishPanelUi.publishOverviewLines,
      draftLines: publishPanelUi.draftLines,
      jobLines: publishPanelUi.jobLines,
      onRefreshPublish: publishPanelUi.onRefreshPublish,
      publishBusy: publishPanelUi.publishBusy,
      onBootstrapPublishDraft: publishPanelUi.onBootstrapPublishDraft,
      onEnqueuePublishJob: publishPanelUi.onEnqueuePublishJob,
      awaitingSemiAutoJobId: publishPanelUi.awaitingSemiAutoJobId,
      onConfirmSemiAuto: publishPanelUi.onConfirmSemiAuto,
      onSuggestPublishCopy: publishPanelUi.onSuggestPublishCopy,
      onClearPublishSchedule: publishPanelUi.onClearPublishSchedule,
      publishPrimaryDraftId: publishPanelUi.publishPrimaryDraftId,
      publishDomesticTargetIds: publishPanelUi.publishDomesticTargetIds,
      publishOverseasTargetIds: publishPanelUi.publishOverseasTargetIds,
      publishPlatformLabels: publishPanelUi.publishPlatformLabels,
      publishPlatformCopySnapshot: publishPanelUi.publishPlatformCopySnapshot,
      publishCopyEditorRevision: publishPanelUi.publishCopyEditorRevision,
      onCommitPublishPlatformCopy: publishPanelUi.onCommitPublishPlatformCopy,
      onScheduleFirstDraft: publishPanelUi.onScheduleFirstDraft,
      onScheduleAllDraftsSameTime: publishPanelUi.onScheduleAllDraftsSameTime,
      onEnqueueAllDrafts: publishPanelUi.onEnqueueAllDrafts,
      onRetryFailedPublishJobs: publishPanelUi.onRetryFailedPublishJobs,
      publishBatchResultLines: publishPanelUi.publishBatchResultLines,
      publishAutomationModesByPlatform:
          publishPanelUi.publishAutomationModesByPlatform,
      onChangePublishAutomationMode:
          publishPanelUi.onChangePublishAutomationMode,
      publishDraftOptions: publishPanelUi.publishDraftOptions,
      selectedPublishDraftId: publishPanelUi.selectedPublishDraftId,
      onSelectPublishDraft: publishPanelUi.onSelectPublishDraft,
      publishScheduleCalendarDrafts:
          publishPanelUi.publishScheduleCalendarDrafts,
      onPublishCalendarDayBulkSchedule:
          publishPanelUi.onPublishCalendarDayBulkSchedule,
      onOpenPublishTroubleshooting: publishPanelUi.onOpenPublishTroubleshooting,
      multiSelectMode: publishPanelUi.multiSelectMode,
      selectedDraftIds: publishPanelUi.selectedDraftIds,
      onToggleMultiSelectMode: publishPanelUi.onToggleMultiSelectMode,
      onToggleDraftSelection: publishPanelUi.onToggleDraftSelection,
      onSelectAllDrafts: publishPanelUi.onSelectAllDrafts,
      onClearDraftSelection: publishPanelUi.onClearDraftSelection,
      onBatchScheduleDrafts: publishPanelUi.onBatchScheduleDrafts,
      onBatchPublishDrafts: publishPanelUi.onBatchPublishDrafts,
      onBatchArchiveDrafts: publishPanelUi.onBatchArchiveDrafts,
      onCompareDrafts: publishPanelUi.onCompareDrafts,
      batchValidation: publishPanelUi.batchValidation,
      onResetConfirmationDontShowAgain:
          publishPanelUi.onResetConfirmationDontShowAgain,
      jobsByDeliveryMode: publishPanelUi.jobsByDeliveryMode,
      deliveryModeFilter: publishPanelUi.deliveryModeFilter,
      onDeliveryModeFilterChanged: publishPanelUi.onDeliveryModeFilterChanged,
    );
    return appWithZh(
      child: ShortVideoPublishDraftsPanel(publishPanelUi: normalizedUi),
    );
  }

  PublishDraftRow buildDraftRow({required String id, required String title}) {
    return PublishDraftRow(
      id: id,
      projectId: 'project-1',
      title: title,
      description: '',
      tags: const [],
      draftStatus: 'editing',
    );
  }

  group('Publish Panel State Tests', () {
    test('publish data availability helper detects usable slices', () {
      expect(
        shortVideoPublishHasUsableData(
          matrix: null,
          drafts: const [],
          prepare: null,
          jobs: const [],
          performanceAlerts: const [],
          audits: const [],
        ),
        false,
      );

      expect(
        shortVideoPublishHasUsableData(
          matrix: null,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '测试草稿',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
          prepare: null,
          jobs: const [],
          performanceAlerts: const [],
          audits: const [],
        ),
        true,
      );
    });

    test('publish interactions stay enabled for degraded but usable data', () {
      expect(
        shortVideoPublishInteractionsAllowed(
          publishUnavailable: true,
          hasUsableData: false,
        ),
        false,
      );
      expect(
        shortVideoPublishInteractionsAllowed(
          publishUnavailable: true,
          hasUsableData: true,
        ),
        true,
      );
      expect(
        shortVideoPublishInteractionsAllowed(
          publishUnavailable: false,
          hasUsableData: false,
        ),
        true,
      );
    });

    test('draft selection helper drops stale draft ids after refresh', () {
      expect(
        shortVideoFilterExistingDraftIds(
          {'draft-1', 'draft-2', 'draft-ghost'},
          const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '草稿 1',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
            PublishDraftRow(
              id: 'draft-2',
              projectId: 'project-1',
              title: '草稿 2',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
        ),
        {'draft-1', 'draft-2'},
      );

      expect(
        shortVideoFilterExistingDraftIds({
          'draft-ghost',
        }, const <PublishDraftRow>[]),
        isEmpty,
      );
    });

    test('multi-select mode only stays active with at least two drafts', () {
      expect(
        shortVideoShouldKeepMultiSelectMode(
          multiSelectMode: true,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '草稿 1',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
            PublishDraftRow(
              id: 'draft-2',
              projectId: 'project-1',
              title: '草稿 2',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
        ),
        true,
      );
      expect(
        shortVideoShouldKeepMultiSelectMode(
          multiSelectMode: true,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '草稿 1',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
        ),
        false,
      );
      expect(
        shortVideoShouldKeepMultiSelectMode(
          multiSelectMode: false,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '草稿 1',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
            PublishDraftRow(
              id: 'draft-2',
              projectId: 'project-1',
              title: '草稿 2',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
        ),
        false,
      );
    });

    test('copy editor only reloads when current platform block changes', () {
      expect(
        publishPlatformCopyBlockChanged(
          {
            'douyin': {
              'title': '标题',
              'description': '描述',
              'tags': ['a', 'b'],
            },
            'youtube': {'title': 'YT old'},
          },
          {
            'douyin': {
              'title': '标题',
              'description': '描述',
              'tags': ['a', 'b'],
            },
            'youtube': {'title': 'YT new'},
          },
          'douyin',
        ),
        false,
      );
      expect(
        publishPlatformCopyBlockChanged(
          {
            'douyin': {
              'title': '标题',
              'description': '描述',
              'tags': ['a', 'b'],
            },
          },
          {
            'douyin': {
              'title': '新标题',
              'description': '描述',
              'tags': ['a', 'b'],
            },
          },
          'douyin',
        ),
        true,
      );
    });

    test('copy editor platform list equality uses contents not identity', () {
      expect(
        listEquals(['douyin', 'xiaohongshu'], ['douyin', 'xiaohongshu']),
        true,
      );
      expect(listEquals(['douyin', 'xiaohongshu'], ['douyin']), false);
    });

    testWidgets(
      'copy editor keeps unsaved input across harmless parent refresh',
      (tester) async {
        await tester.pumpWidget(
          buildCopyEditorHarness(
            draftId: 'draft-1',
            domesticPlatformIds: const ['douyin'],
            overseasPlatformIds: const ['youtube'],
            platformCopy: const {
              'douyin': {
                'title': '原始标题',
                'description': '原始描述',
                'tags': ['a', 'b'],
              },
              'youtube': {'title': 'YT old'},
            },
          ),
        );

        await tester.enterText(find.byType(TextField).first, '用户未保存标题');
        await tester.pump();

        await tester.pumpWidget(
          buildCopyEditorHarness(
            draftId: 'draft-1',
            domesticPlatformIds: const ['douyin'],
            overseasPlatformIds: const ['youtube'],
            platformCopy: const {
              'douyin': {
                'title': '原始标题',
                'description': '原始描述',
                'tags': ['a', 'b'],
              },
              'youtube': {'title': 'YT new'},
            },
          ),
        );
        await tester.pump();

        expect(find.text('用户未保存标题'), findsOneWidget);
      },
    );

    testWidgets(
      'publish draft dropdown switches copy editor to selected draft',
      (tester) async {
        await tester.pumpWidget(
          _PublishDraftSelectionHarness(
            builder: (selectedDraftId, onSelectDraft) {
              final selectedTitle = selectedDraftId == 'draft-1'
                  ? '标题一'
                  : '标题二';
              return buildDraftEditorSectionHarness(
                publishPanelUi: ShortVideoPublishPanelUi(
                  publishDraftOptions: [
                    buildDraftRow(id: 'draft-1', title: '草稿 1'),
                    buildDraftRow(id: 'draft-2', title: '草稿 2'),
                  ],
                  selectedPublishDraftId: selectedDraftId,
                  onSelectPublishDraft: onSelectDraft,
                  publishPrimaryDraftId: selectedDraftId,
                  publishDomesticTargetIds: const ['douyin'],
                  publishPlatformLabels: const {'douyin': '抖音'},
                  onCommitPublishPlatformCopy:
                      (platformId, title, description, tagsComma) async {},
                  publishPlatformCopySnapshot: {
                    'douyin': {
                      'title': selectedTitle,
                      'description': '描述 $selectedTitle',
                      'tags': ['tag-$selectedDraftId'],
                    },
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final titleFieldFinder = find.descendant(
          of: find.byType(PublishPlatformCopyEditor),
          matching: find.byType(TextField),
        );
        expect(
          tester.widgetList<TextField>(titleFieldFinder).first.controller!.text,
          '标题一',
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();

        final draft2Label = zh.shortVideoPublishDraftDropdownLabel(
          '草稿 2',
          zh.shortVideoPublishDraftStatusEditing,
        );
        await tester.tap(find.text(draft2Label).last);
        await tester.pumpAndSettle();

        expect(
          tester.widgetList<TextField>(titleFieldFinder).first.controller!.text,
          '标题二',
        );
      },
    );

    testWidgets(
      'publish draft switch discards unsaved input from previous draft',
      (tester) async {
        await tester.pumpWidget(
          _PublishDraftSelectionHarness(
            builder: (selectedDraftId, onSelectDraft) {
              final selectedTitle = selectedDraftId == 'draft-1'
                  ? '草稿一已保存标题'
                  : '草稿二已保存标题';
              return buildDraftEditorSectionHarness(
                publishPanelUi: ShortVideoPublishPanelUi(
                  publishDraftOptions: [
                    buildDraftRow(id: 'draft-1', title: '草稿 1'),
                    buildDraftRow(id: 'draft-2', title: '草稿 2'),
                  ],
                  selectedPublishDraftId: selectedDraftId,
                  onSelectPublishDraft: onSelectDraft,
                  publishPrimaryDraftId: selectedDraftId,
                  publishDomesticTargetIds: const ['douyin'],
                  publishPlatformLabels: const {'douyin': '抖音'},
                  onCommitPublishPlatformCopy:
                      (platformId, title, description, tagsComma) async {},
                  publishPlatformCopySnapshot: {
                    'douyin': {
                      'title': selectedTitle,
                      'description': '描述 $selectedTitle',
                      'tags': ['tag-$selectedDraftId'],
                    },
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final titleFieldFinder = find.descendant(
          of: find.byType(PublishPlatformCopyEditor),
          matching: find.byType(TextField),
        );

        await tester.enterText(titleFieldFinder.first, '草稿一未保存改动');
        await tester.pump();
        expect(
          tester.widgetList<TextField>(titleFieldFinder).first.controller!.text,
          '草稿一未保存改动',
        );

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        final draft2Label = zh.shortVideoPublishDraftDropdownLabel(
          '草稿 2',
          zh.shortVideoPublishDraftStatusEditing,
        );
        await tester.tap(find.text(draft2Label).last);
        await tester.pumpAndSettle();

        expect(
          tester.widgetList<TextField>(titleFieldFinder).first.controller!.text,
          '草稿二已保存标题',
        );
        expect(find.text('草稿一未保存改动'), findsNothing);

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        final draft1Label = zh.shortVideoPublishDraftDropdownLabel(
          '草稿 1',
          zh.shortVideoPublishDraftStatusEditing,
        );
        await tester.tap(find.text(draft1Label).last);
        await tester.pumpAndSettle();

        expect(
          tester.widgetList<TextField>(titleFieldFinder).first.controller!.text,
          '草稿一已保存标题',
        );
        expect(find.text('草稿一未保存改动'), findsNothing);
      },
    );

    testWidgets(
      'copy editor platform switch discards unsaved input from previous platform',
      (tester) async {
        await tester.pumpWidget(
          buildCopyEditorHarness(
            draftId: 'draft-1',
            domesticPlatformIds: const ['douyin', 'bilibili'],
            overseasPlatformIds: const [],
            platformCopy: const {
              'douyin': {
                'title': '抖音已保存标题',
                'description': '抖音描述',
                'tags': ['douyin-tag'],
              },
              'bilibili': {
                'title': 'B站已保存标题',
                'description': 'B站描述',
                'tags': ['bili-tag'],
              },
            },
          ),
        );
        await tester.pumpAndSettle();

        final titleFieldFinder = find.byType(TextField).first;

        await tester.enterText(titleFieldFinder, '抖音未保存改动');
        await tester.pump();
        expect(find.text('抖音未保存改动'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'bilibili'));
        await tester.pumpAndSettle();
        expect(find.text('B站已保存标题'), findsOneWidget);
        expect(find.text('抖音未保存改动'), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, '抖音'));
        await tester.pumpAndSettle();
        expect(find.text('抖音已保存标题'), findsOneWidget);
        expect(find.text('抖音未保存改动'), findsNothing);
      },
    );

    testWidgets('copy editor save submits current platform fields', (
      tester,
    ) async {
      String? committedPlatformId;
      String? committedTitle;
      String? committedDescription;
      String? committedTagsComma;

      await tester.pumpWidget(
        buildCopyEditorHarness(
          draftId: 'draft-1',
          domesticPlatformIds: const ['douyin', 'bilibili'],
          overseasPlatformIds: const [],
          platformCopy: const {
            'douyin': {
              'title': '抖音原始标题',
              'description': '抖音原始描述',
              'tags': ['old-a'],
            },
            'bilibili': {
              'title': 'B站原始标题',
              'description': 'B站原始描述',
              'tags': ['old-b'],
            },
          },
          onCommit: (platformId, title, description, tagsComma) async {
            committedPlatformId = platformId;
            committedTitle = title;
            committedDescription = description;
            committedTagsComma = tagsComma;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'bilibili'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'B站新标题');
      await tester.enterText(textFields.at(1), 'B站新描述');
      await tester.enterText(textFields.at(2), 'tag-a, tag-b');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      expect(committedPlatformId, 'bilibili');
      expect(committedTitle, 'B站新标题');
      expect(committedDescription, 'B站新描述');
      expect(committedTagsComma, 'tag-a, tag-b');
    });

    testWidgets(
      'draft editor section save follows selected draft after switching',
      (tester) async {
        String? committedSelectedDraftId;
        String? committedPlatformId;
        String? committedTitle;

        await tester.pumpWidget(
          _PublishDraftSelectionHarness(
            builder: (selectedDraftId, onSelectDraft) {
              final selectedTitle = selectedDraftId == 'draft-1'
                  ? '草稿一标题'
                  : '草稿二标题';
              return buildDraftEditorSectionHarness(
                publishPanelUi: ShortVideoPublishPanelUi(
                  publishDraftOptions: [
                    buildDraftRow(id: 'draft-1', title: '草稿 1'),
                    buildDraftRow(id: 'draft-2', title: '草稿 2'),
                  ],
                  selectedPublishDraftId: selectedDraftId,
                  onSelectPublishDraft: onSelectDraft,
                  publishPrimaryDraftId: selectedDraftId,
                  publishDomesticTargetIds: const ['douyin'],
                  publishPlatformLabels: const {'douyin': '抖音'},
                  onCommitPublishPlatformCopy:
                      (platformId, title, description, tagsComma) async {
                        committedSelectedDraftId = selectedDraftId;
                        committedPlatformId = platformId;
                        committedTitle = title;
                      },
                  publishPlatformCopySnapshot: {
                    'douyin': {
                      'title': selectedTitle,
                      'description': '描述 $selectedTitle',
                      'tags': ['tag-$selectedDraftId'],
                    },
                  },
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        final draft2Label = zh.shortVideoPublishDraftDropdownLabel(
          '草稿 2',
          zh.shortVideoPublishDraftStatusEditing,
        );
        await tester.tap(find.text(draft2Label).last);
        await tester.pumpAndSettle();

        final textFields = find.descendant(
          of: find.byType(PublishPlatformCopyEditor),
          matching: find.byType(TextField),
        );
        await tester.enterText(textFields.at(0), '草稿二新标题');
        await tester.pump();

        await tester.tap(find.byIcon(Icons.save_outlined));
        await tester.pumpAndSettle();

        expect(committedSelectedDraftId, 'draft-2');
        expect(committedPlatformId, 'douyin');
        expect(committedTitle, '草稿二新标题');
      },
    );

    testWidgets('draft editor section disables switching while busy', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildDraftEditorSectionHarness(
          publishPanelUi: ShortVideoPublishPanelUi(
            publishDraftOptions: [
              buildDraftRow(id: 'draft-1', title: '草稿 1'),
              buildDraftRow(id: 'draft-2', title: '草稿 2'),
            ],
            selectedPublishDraftId: 'draft-1',
            onSelectPublishDraft: (_) {},
            publishPrimaryDraftId: 'draft-1',
            publishDomesticTargetIds: const ['douyin'],
            publishPlatformLabels: const {'douyin': '抖音'},
            publishBusy: true,
            onCommitPublishPlatformCopy:
                (platformId, title, description, tagsComma) async {},
            publishPlatformCopySnapshot: const {
              'douyin': {
                'title': '标题',
                'description': '描述',
                'tags': ['tag-1'],
              },
            },
          ),
        ),
      );
      await tester.pump();

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(dropdown.onChanged, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.save_outlined), findsNothing);
    });

    test('publish panel treats missing export check as not export ready', () {
      final ui = buildShortVideoPublishPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        publishUnavailable: false,
        exportCheck: null,
        matrix: null,
        drafts: const [],
        prepare: null,
        jobs: const [],
        performanceAlerts: const [],
        audits: const [],
        selectedPublishDraftId: null,
        publishBusy: false,
      );

      expect(ui.visible, true);
      expect(ui.unavailable, false);
      expect(ui.exportReady, false);
      expect(ui.exportGateHint, contains('导出检查数据暂不可用'));
    });

    test(
      'publish panel clears stale selected draft id when multiple drafts remain',
      () {
        final ui = buildShortVideoPublishPanelUi(
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          publishUnavailable: false,
          exportCheck: null,
          matrix: null,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '草稿 1',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
            PublishDraftRow(
              id: 'draft-2',
              projectId: 'project-1',
              title: '草稿 2',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
          prepare: null,
          jobs: const [],
          performanceAlerts: const [],
          audits: const [],
          selectedPublishDraftId: 'draft-gone',
          publishBusy: false,
        );

        expect(ui.selectedPublishDraftId, isNull);
        expect(ui.publishPrimaryDraftId, isEmpty);
        expect(ui.prepareLines.first, contains('请明确选择草稿'));
      },
    );

    test(
      'publish panel falls back to the only draft when stale selection remains',
      () {
        final ui = buildShortVideoPublishPanelUi(
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          publishUnavailable: false,
          exportCheck: null,
          matrix: null,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '唯一草稿',
              description: '',
              tags: [],
              draftStatus: 'editing',
            ),
          ],
          prepare: null,
          jobs: const [],
          performanceAlerts: const [],
          audits: const [],
          selectedPublishDraftId: 'draft-gone',
          publishBusy: false,
        );

        expect(ui.selectedPublishDraftId, 'draft-1');
        expect(ui.publishPrimaryDraftId, 'draft-1');
        expect(ui.prepareLines.first, contains('唯一草稿'));
      },
    );

    test(
      'publish panel keeps partial publish data visible during degraded mode',
      () {
        final ui = buildShortVideoPublishPanelUi(
          l10n: zh,
          projectSelected: true,
          loadingProjectOverview: false,
          publishUnavailable: true,
          exportCheck: null,
          matrix: null,
          drafts: const [
            PublishDraftRow(
              id: 'draft-1',
              projectId: 'project-1',
              title: '测试草稿',
              description: '',
              tags: [],
              draftStatus: 'editing',
              platformCopy: {},
            ),
          ],
          prepare: null,
          jobs: const [],
          performanceAlerts: const [],
          audits: const [],
          selectedPublishDraftId: 'draft-1',
          publishBusy: false,
        );

        expect(ui.visible, true);
        expect(ui.unavailable, false);
        expect(ui.draftLines, isNotEmpty);
        expect(ui.detail, contains('Rust worker'));
      },
    );

    test('publish panel shows pending prepare message for selected draft', () {
      final ui = buildShortVideoPublishPanelUi(
        l10n: zh,
        projectSelected: true,
        loadingProjectOverview: false,
        publishUnavailable: false,
        exportCheck: null,
        matrix: null,
        drafts: const [
          PublishDraftRow(
            id: 'draft-1',
            projectId: 'project-1',
            title: '测试草稿',
            description: '',
            tags: [],
            draftStatus: 'editing',
          ),
        ],
        prepare: null,
        jobs: const [],
        performanceAlerts: const [],
        audits: const [],
        selectedPublishDraftId: 'draft-1',
        publishBusy: false,
      );

      expect(ui.prepareLines, isNotEmpty);
      expect(ui.prepareLines.first, contains('当前草稿'));
      expect(
        ui.prepareLines.join('\n'),
        contains('选择草稿后将显示 prepare-check 校验结果'),
      );
      expect(ui.prepareLines.join('\n'), isNot(contains('尚无草稿')));
    });
  });
}

class _PublishDraftSelectionHarness extends StatefulWidget {
  const _PublishDraftSelectionHarness({required this.builder});

  final Widget Function(
    String selectedDraftId,
    ValueChanged<String> onSelectDraft,
  )
  builder;

  @override
  State<_PublishDraftSelectionHarness> createState() =>
      _PublishDraftSelectionHarnessState();
}

class _PublishDraftSelectionHarnessState
    extends State<_PublishDraftSelectionHarness> {
  String _selectedDraftId = 'draft-1';

  @override
  Widget build(BuildContext context) {
    return widget.builder(_selectedDraftId, (draftId) {
      setState(() {
        _selectedDraftId = draftId;
      });
    });
  }
}
