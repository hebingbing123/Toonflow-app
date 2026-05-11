import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/projects/workbenches/agent_memory_view.dart';
import 'package:openflow_app/rust_api.dart';

ProjectRow buildProject({required int numericId, required String name}) {
  return ProjectRow(
    id: 'project-$numericId',
    numericId: numericId,
    name: name,
    projectAccessMode: 'inherited',
    projectAccessRole: 'member',
  );
}

ProjectsAgentMemoryWorkbenchDialogViewModel buildModel({
  required TextEditingController projectIdCtrl,
  required TextEditingController agentTypeCtrl,
  required TextEditingController episodesIdCtrl,
  required TextEditingController queryTypeCtrl,
  TextEditingController? memoryTierCtrl,
  TextEditingController? scopeSignatureCtrl,
  required TextEditingController appendContentCtrl,
  required TextEditingController appendRoleCtrl,
  TextEditingController? appendTypeCtrl,
  TextEditingController? appendMemoryTierCtrl,
  TextEditingController? appendNameCtrl,
  required TextEditingController clearTypeCtrl,
  TextEditingController? automationModeCtrl,
  List<ProjectRow>? projects,
  List<dynamic>? memoryRows,
  String? memorySummary = '已读取 2 条记忆。',
  String? statusLine = '已刷新 2 个项目。',
  bool loadingProjects = false,
  bool loadingMemory = false,
  bool appendingMemory = false,
  bool clearingMemory = false,
  bool optimizingMemory = false,
  bool canOptimizeVideoMemory = true,
}) {
  final resolvedMemoryTierCtrl =
      memoryTierCtrl ?? TextEditingController(text: 'message');
  final resolvedScopeSignatureCtrl = scopeSignatureCtrl ?? TextEditingController();
  final resolvedAppendTypeCtrl =
      appendTypeCtrl ?? TextEditingController(text: 'summary');
  final resolvedAppendMemoryTierCtrl =
      appendMemoryTierCtrl ?? TextEditingController(text: 'message');
  final resolvedAppendNameCtrl = appendNameCtrl ?? TextEditingController();
  final resolvedAutomationModeCtrl =
      automationModeCtrl ?? TextEditingController(text: 'manual');
  return ProjectsAgentMemoryWorkbenchDialogViewModel(
    projects:
        projects ??
        <ProjectRow>[
          buildProject(numericId: 11, name: '青溪镇奇案'),
          buildProject(numericId: 12, name: '海雾迷城'),
        ],
    memoryRows:
        (memoryRows
            ?.map(
              (row) => row is AgentMemoryHistoryItem
                  ? row
                  : AgentMemoryHistoryItem.fromJson(
                      Map<String, dynamic>.from(row as Map),
                    ),
            )
            .toList(growable: false)) ??
        <AgentMemoryHistoryItem>[
          const AgentMemoryHistoryItem(
            scope: 'user',
            id: 'memory-1',
            name: 'selected_video_memory',
            role: 'user',
            memoryTier: 'message',
            status: 'complete',
            datetime: '2026-05-04T12:00:00Z',
            createTime: 1,
            content: <AgentMemoryContentBlock>[
              AgentMemoryContentBlock(
                blockType: 'markdown',
                status: 'complete',
                data:
                    'storyboardIds=3 | subject=沈青禾 | style=语气克制，情绪压迫，保留停顿 | note=语气克制，情绪压迫，保留停顿',
              ),
            ],
          ),
          const AgentMemoryHistoryItem(
            scope: 'user',
            id: 'memory-2',
            name: 'quality_feedback_memory',
            role: 'assistant',
            memoryTier: 'message',
            status: 'complete',
            datetime: '2026-05-04T12:05:00Z',
            createTime: 2,
            content: <AgentMemoryContentBlock>[
              AgentMemoryContentBlock(
                blockType: 'markdown',
                status: 'complete',
                data: 'production agent 建议先刷新 storyboardTable 再补镜头。',
              ),
            ],
          ),
        ],
    memorySummary: memorySummary,
    statusLine: statusLine,
    costOverview: null,
    loadingProjects: loadingProjects,
    loadingCostOverview: false,
    loadingMemory: loadingMemory,
    appendingMemory: appendingMemory,
    clearingMemory: clearingMemory,
    optimizingMemory: optimizingMemory,
    canOptimizeVideoMemory: canOptimizeVideoMemory,
    queryType: queryTypeCtrl.text,
    clearType: clearTypeCtrl.text,
    memoryTier: resolvedMemoryTierCtrl.text,
    queryTypeOptions: const <String>['summary', 'message', 'all'],
    clearTypeOptions: const <String>['summary', 'message', 'all'],
    memoryTierOptions: const <String>[
      'all',
      'style_bible',
      'stage_summary',
      'delta_memory',
      'message',
    ],
    appendTypeOptions: const <String>['summary', 'message'],
    automationModeOptions: const <String>['manual', 'auto'],
    projectIdCtrl: projectIdCtrl,
    agentTypeCtrl: agentTypeCtrl,
    episodesIdCtrl: episodesIdCtrl,
    queryTypeCtrl: queryTypeCtrl,
    memoryTierCtrl: resolvedMemoryTierCtrl,
    scopeSignatureCtrl: resolvedScopeSignatureCtrl,
    appendContentCtrl: appendContentCtrl,
    appendRoleCtrl: appendRoleCtrl,
    appendTypeCtrl: resolvedAppendTypeCtrl,
    appendMemoryTierCtrl: resolvedAppendMemoryTierCtrl,
    appendNameCtrl: resolvedAppendNameCtrl,
    clearTypeCtrl: clearTypeCtrl,
    automationModeCtrl: resolvedAutomationModeCtrl,
    appendType: resolvedAppendTypeCtrl.text,
    appendMemoryTier: resolvedAppendMemoryTierCtrl.text,
    automationMode: resolvedAutomationModeCtrl.text,
  );
}

ProjectsAgentMemoryWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function()? onReloadProjects,
  Future<void> Function()? onQueryMemory,
  Future<void> Function()? onAppendMemory,
  Future<void> Function()? onClearMemory,
  Future<void> Function()? onOptimizeVideoMemory,
  VoidCallback? onClose,
}) {
  return ProjectsAgentMemoryWorkbenchDialogViewCallbacks(
    onReloadProjects: onReloadProjects ?? () async {},
    onQueryMemory: onQueryMemory ?? () async {},
    onAppendMemory: onAppendMemory ?? () async {},
    onClearMemory: onClearMemory ?? () async {},
    onLoadCostOverview: () async {},
    onOptimizeVideoMemory: onOptimizeVideoMemory ?? () async {},
    onQueryTypeChanged: (_) {},
    onClearTypeChanged: (_) {},
    onMemoryTierChanged: (_) {},
    onAppendTypeChanged: (_) {},
    onAppendMemoryTierChanged: (_) {},
    onAutomationModeChanged: (_) {},
    onClose: onClose ?? () {},
  );
}

Finder disabledButtonWithText(String text) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is ButtonStyleButton &&
        widget.onPressed == null &&
        widget.child is Text &&
        (widget.child as Text).data == text,
  );
}

void main() {
  late TextEditingController projectIdCtrl;
  late TextEditingController agentTypeCtrl;
  late TextEditingController episodesIdCtrl;
  late TextEditingController queryTypeCtrl;
  late TextEditingController memoryTierCtrl;
  late TextEditingController scopeSignatureCtrl;
  late TextEditingController appendContentCtrl;
  late TextEditingController appendRoleCtrl;
  late TextEditingController appendTypeCtrl;
  late TextEditingController appendMemoryTierCtrl;
  late TextEditingController appendNameCtrl;
  late TextEditingController clearTypeCtrl;
  late TextEditingController automationModeCtrl;

  setUp(() {
    projectIdCtrl = TextEditingController(text: '11');
    agentTypeCtrl = TextEditingController(text: 'scriptAgent');
    episodesIdCtrl = TextEditingController(text: '3');
    queryTypeCtrl = TextEditingController(text: 'summary');
    memoryTierCtrl = TextEditingController(text: 'message');
    scopeSignatureCtrl = TextEditingController(text: '{"episodeId":3}');
    appendContentCtrl = TextEditingController(text: '需要补一个反转伏笔。');
    appendRoleCtrl = TextEditingController(text: 'user');
    appendTypeCtrl = TextEditingController(text: 'summary');
    appendMemoryTierCtrl = TextEditingController(text: 'message');
    appendNameCtrl = TextEditingController(text: 'quality_feedback_memory');
    clearTypeCtrl = TextEditingController(text: 'summary');
    automationModeCtrl = TextEditingController(text: 'manual');
  });

  tearDown(() {
    projectIdCtrl.dispose();
    agentTypeCtrl.dispose();
    episodesIdCtrl.dispose();
    queryTypeCtrl.dispose();
    memoryTierCtrl.dispose();
    scopeSignatureCtrl.dispose();
    appendContentCtrl.dispose();
    appendRoleCtrl.dispose();
    appendTypeCtrl.dispose();
    appendMemoryTierCtrl.dispose();
    appendNameCtrl.dispose();
    clearTypeCtrl.dispose();
    automationModeCtrl.dispose();
  });

  testWidgets('agent memory workbench view renders summary and rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              memoryTierCtrl: memoryTierCtrl,
              scopeSignatureCtrl: scopeSignatureCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              appendTypeCtrl: appendTypeCtrl,
              appendMemoryTierCtrl: appendMemoryTierCtrl,
              appendNameCtrl: appendNameCtrl,
              clearTypeCtrl: clearTypeCtrl,
              automationModeCtrl: automationModeCtrl,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('Agent 记忆工作台'), findsOneWidget);
    expect(find.textContaining('2 个项目 ·'), findsOneWidget);
    expect(find.text('已读取 2 条记忆。'), findsOneWidget);
    expect(find.text('summary / message / all'), findsNWidgets(2));
    expect(
      find.text('自动记忆按 项目 numeric ID + agent type + episodes id 独立隔离。'),
      findsOneWidget,
    );
    expect(find.text('自动优化视频记忆'), findsOneWidget);
    expect(
      find.textContaining('自动优化只处理 productionAgent + episodes id 范围内'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '角色分布：user 1 / assistant 1 · 类型 selected_video_memory 1 / quality_feedback_memory 1',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '视频记忆：delivery 1/74 chars · visual 0/0 chars · negative 0/0 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('处理建议：保留 1/74 chars · 压缩 0/0 chars · 合并坏例 0/0 chars'),
      findsOneWidget,
    );
    expect(
      find.textContaining('记忆桶优先级：优先保留 selected_video_memory'),
      findsOneWidget,
    );
    expect(find.byTooltip('复制记忆执行清单'), findsOneWidget);
    expect(find.textContaining('记忆执行清单：'), findsOneWidget);
    expect(find.textContaining('P11 / scriptAgent / E3'), findsOneWidget);
    expect(
      find.textContaining('保留 selected_video_memory 里最具体的表演/情绪锚点'),
      findsOneWidget,
    );
    expect(find.text('2 条记忆'), findsOneWidget);
    expect(find.text('追加记忆'), findsOneWidget);
    expect(find.text('按当前 scope 追加记忆'), findsOneWidget);
    expect(find.text('清理记忆'), findsOneWidget);
    expect(
      find.textContaining('selected_video_memory · user · '),
      findsOneWidget,
    );
    expect(find.textContaining('表演优先 · 优先保留'), findsOneWidget);
    expect(find.textContaining('memory-1'), findsOneWidget);
    expect(find.textContaining('subject 沈青禾'), findsOneWidget);
    expect(find.textContaining('signals 人物/情绪'), findsOneWidget);
    expect(find.textContaining('语气克制，情绪压迫，保留停顿'), findsOneWidget);
  });

  testWidgets('agent memory workbench view surfaces dedupe guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: <dynamic>[
                <String, Object?>{
                  'id': 'memory-1',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=12 | delivery=表演克制压抑，避免读稿腔，保留真实停顿与呼吸 | note=表演克制压抑，避免读稿腔，保留真实停顿与呼吸',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-2',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=15 | delivery=表演克制压抑，避免读稿腔，保留真实停顿与呼吸 | note=表演克制压抑，避免读稿腔，保留真实停顿与呼吸',
                    },
                  ],
                },
              ],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.textContaining('建议：检测到重复表述'), findsOneWidget);
    expect(find.widgetWithText(Chip, '重复'), findsNWidgets(2));
  });

  testWidgets('agent memory workbench view surfaces dominant memory bucket', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: List<dynamic>.generate(6, (index) {
                return <String, Object?>{
                  'id': 'memory-$index',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{'data': '第 $index 条镜头表演记忆，保留强停顿与真实呼吸。'},
                  ],
                };
              }),
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('建议：selected_video_memory 已累计 6 条'),
      findsOneWidget,
    );
  });

  testWidgets('agent memory workbench view highlights visual-heavy video memory', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: <dynamic>[
                <String, Object?>{
                  'id': 'memory-1',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=12 | style=镜头近景，光影冷调逆光，机位压迫 | note=镜头近景，光影冷调逆光，机位压迫',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-2',
                  'name': 'script_role_video_style_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'sampleCount=4 | style=镜头稳定跟拍，光影阴天冷光，构图压迫 | note=镜头稳定跟拍，光影阴天冷光，构图压迫',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-3',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=12 | subject=林晚 | style=表演欲言又止，语气轻声克制，情绪强忍泪意 | note=表演欲言又止，语气轻声克制，情绪强忍泪意',
                    },
                  ],
                },
              ],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(
      find.textContaining(
        '视频记忆：delivery 1/86 chars · visual 2/131 chars · negative 0/0 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '处理建议：保留 1/86 chars · 压缩 2/131 chars · 合并坏例 0/0 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('记忆桶优先级：待压缩 selected_video_memory'),
      findsOneWidget,
    );
    expect(
      find.textContaining('待压缩 script_role_video_style_memory'),
      findsOneWidget,
    );
    expect(find.textContaining('建议：视觉偏重记忆吃掉了更多预算'), findsOneWidget);
    expect(find.textContaining('· 视觉偏重 · 待压缩'), findsNWidgets(2));
    expect(find.textContaining('storyboard 12'), findsNWidgets(2));
    expect(find.textContaining('samples 4'), findsOneWidget);
    expect(find.textContaining('subject 林晚'), findsOneWidget);
    expect(find.textContaining('signals 人物/情绪'), findsOneWidget);
  });

  testWidgets('agent memory workbench view highlights rejected video constraints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: <dynamic>[
                <String, Object?>{
                  'id': 'memory-1',
                  'name': 'rejected_video_negative_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=7 | rejectionCount=3 | riskTags=delivery/lip-sync | avoid=avoid blank expression or monotone delivery',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-2',
                  'name': 'rejected_video_negative_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=8 | rejectionCount=2 | riskTags=emotion | avoid=avoid overly cold, oppressive, or frantic mood',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-3',
                  'name': 'rejected_video_negative_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=9 | rejectionCount=2 | riskTags=identity | avoid=avoid face distortion, identity drift, costume drift',
                    },
                  ],
                },
              ],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(
      find.textContaining(
        '视频记忆：delivery 0/0 chars · visual 0/0 chars · negative 3/338 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '处理建议：保留 0/0 chars · 压缩 0/0 chars · 合并坏例 3/338 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '记忆桶优先级：合并坏例 rejected_video_negative_memory · 3条/338 chars',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('建议：坏例约束累计较多'), findsOneWidget);
    expect(
      find.textContaining('rejected_video_negative_memory · assistant ·'),
      findsNWidgets(3),
    );
    expect(find.textContaining('坏例约束 · 合并坏例'), findsNWidgets(3));
  });

  testWidgets('agent memory workbench view highlights missing delivery anchors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: <dynamic>[
                <String, Object?>{
                  'id': 'memory-1',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=12 | style=镜头近景，光影冷调逆光，机位压迫 | note=镜头近景，光影冷调逆光，机位压迫',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'memory-2',
                  'name': 'script_role_video_style_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'sampleCount=4 | style=镜头稳定跟拍，光影阴天冷光，构图压迫 | note=镜头稳定跟拍，光影阴天冷光，构图压迫',
                    },
                  ],
                },
              ],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(
      find.textContaining(
        '视频记忆：delivery 0/0 chars · visual 2/131 chars · negative 0/0 chars',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '处理建议：保留 0/0 chars · 压缩 2/131 chars · 合并坏例 0/0 chars',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('建议：当前视频记忆几乎只有镜头/光影'), findsOneWidget);
  });

  testWidgets(
    'agent memory workbench view highlights keep-worthy delivery anchors',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: ProjectsAgentMemoryWorkbenchDialogView(
              model: buildModel(
                projectIdCtrl: projectIdCtrl,
                agentTypeCtrl: agentTypeCtrl,
                episodesIdCtrl: episodesIdCtrl,
                queryTypeCtrl: queryTypeCtrl,
                appendContentCtrl: appendContentCtrl,
                appendRoleCtrl: appendRoleCtrl,
                clearTypeCtrl: clearTypeCtrl,
                memoryRows: <dynamic>[
                  <String, Object?>{
                    'id': 'memory-1',
                    'name': 'selected_video_memory',
                    'role': 'assistant',
                    'content': <Map<String, String>>[
                      <String, String>{
                        'data':
                            'storyboardIds=15 | subject=林晚 | riskTags=identity/dialogue/performance | style=表演呼吸发颤，语气低声克制，光影冷蓝窗光 | delivery=表演呼吸发颤低声克制',
                      },
                    ],
                  },
                ],
              ),
              callbacks: buildCallbacks(),
            ),
          ),
        ),
      );

      expect(find.textContaining('表演+视觉 · 优先保留'), findsOneWidget);
      expect(find.textContaining('signals 人物/情绪/镜头/身份/台词/表演'), findsOneWidget);
      expect(
        find.textContaining(
          '处理建议：保留 1/121 chars · 压缩 0/0 chars · 合并坏例 0/0 chars',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('agent memory workbench view prioritizes actionable rows first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              memoryRows: <dynamic>[
                <String, Object?>{
                  'id': 'keep-1',
                  'name': 'selected_video_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'storyboardIds=21 | subject=林晚 | style=表演欲言又止，语气轻声克制 | delivery=表演欲言又止轻声克制',
                    },
                  ],
                },
                <String, Object?>{
                  'id': 'trim-1',
                  'name': 'project_video_style_memory',
                  'role': 'assistant',
                  'content': <Map<String, String>>[
                    <String, String>{
                      'data':
                          'sampleCount=6 | style=镜头稳定跟拍，光影阴天冷光，构图压迫 | note=镜头稳定跟拍，光影阴天冷光，构图压迫',
                    },
                  ],
                },
              ],
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect((tiles.first.title as Text).data, contains('待压缩'));
    expect((tiles.last.title as Text).data, contains('优先保留'));
  });

  testWidgets('agent memory workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
              loadingProjects: true,
              loadingMemory: true,
              appendingMemory: true,
              clearingMemory: true,
              optimizingMemory: true,
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(disabledButtonWithText('处理中…'), findsNWidgets(5));
  });

  testWidgets(
    'agent memory workbench view gates optimize action to scoped production memory',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: ProjectsAgentMemoryWorkbenchDialogView(
              model: buildModel(
                projectIdCtrl: projectIdCtrl,
                agentTypeCtrl: agentTypeCtrl,
                episodesIdCtrl: episodesIdCtrl,
                queryTypeCtrl: queryTypeCtrl,
                appendContentCtrl: appendContentCtrl,
                appendRoleCtrl: appendRoleCtrl,
                clearTypeCtrl: clearTypeCtrl,
                canOptimizeVideoMemory: false,
              ),
              callbacks: buildCallbacks(),
            ),
          ),
        ),
      );

      expect(disabledButtonWithText('自动优化视频记忆'), findsOneWidget);
      expect(
        find.textContaining('要启用自动优化，请把 agent type 设为 productionAgent'),
        findsOneWidget,
      );
    },
  );

  testWidgets('agent memory workbench view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var reloadCalls = 0;
    var queryCalls = 0;
    var appendCalls = 0;
    var clearCalls = 0;
    var optimizeCalls = 0;
    var closeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsAgentMemoryWorkbenchDialogView(
            model: buildModel(
              projectIdCtrl: projectIdCtrl,
              agentTypeCtrl: agentTypeCtrl,
              episodesIdCtrl: episodesIdCtrl,
              queryTypeCtrl: queryTypeCtrl,
              appendContentCtrl: appendContentCtrl,
              appendRoleCtrl: appendRoleCtrl,
              clearTypeCtrl: clearTypeCtrl,
            ),
            callbacks: buildCallbacks(
              onReloadProjects: () async => reloadCalls += 1,
              onQueryMemory: () async => queryCalls += 1,
              onAppendMemory: () async => appendCalls += 1,
              onClearMemory: () async => clearCalls += 1,
              onOptimizeVideoMemory: () async => optimizeCalls += 1,
              onClose: () => closeCalls += 1,
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.widgetWithText(FilledButton, '刷新项目列表'));
    await tester.tap(find.widgetWithText(FilledButton, '刷新项目列表'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '查询记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '查询记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '自动优化视频记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '自动优化视频记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '按当前 scope 追加记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '按当前 scope 追加记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '执行清理'));
    await tester.tap(find.widgetWithText(FilledButton, '执行清理'));
    await tester.pump();
    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(reloadCalls, 1);
    expect(queryCalls, 1);
    expect(optimizeCalls, 1);
    expect(appendCalls, 1);
    expect(clearCalls, 1);
    expect(closeCalls, 1);
  });
}
