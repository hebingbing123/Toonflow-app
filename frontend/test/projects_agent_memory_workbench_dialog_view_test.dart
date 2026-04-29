import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/projects/workbenches/agent_memory_view.dart';
import 'package:openflow_app/rust_api.dart';

ProjectRow buildProject({required int numericId, required String name}) {
  return ProjectRow(id: 'project-$numericId', numericId: numericId, name: name);
}

ProjectsAgentMemoryWorkbenchDialogViewModel buildModel({
  required TextEditingController projectIdCtrl,
  required TextEditingController agentTypeCtrl,
  required TextEditingController episodesIdCtrl,
  required TextEditingController queryTypeCtrl,
  required TextEditingController appendContentCtrl,
  required TextEditingController appendRoleCtrl,
  required TextEditingController clearTypeCtrl,
  List<ProjectRow>? projects,
  List<dynamic>? memoryRows,
  String? memorySummary = '已读取 2 条记忆。',
  String? statusLine = '已刷新 2 个项目。',
  bool loadingProjects = false,
  bool loadingMemory = false,
  bool appendingMemory = false,
  bool clearingMemory = false,
}) {
  return ProjectsAgentMemoryWorkbenchDialogViewModel(
    projects:
        projects ??
        <ProjectRow>[
          buildProject(numericId: 11, name: '青溪镇奇案'),
          buildProject(numericId: 12, name: '海雾迷城'),
        ],
    memoryRows:
        memoryRows ??
        <dynamic>[
          <String, Object?>{
            'id': 'memory-1',
            'name': 'selected_video_memory',
            'role': 'user',
            'content': <Map<String, String>>[
              <String, String>{
                'data':
                    'storyboardIds=3 | subject=沈青禾 | style=语气克制，情绪压迫，保留停顿 | note=语气克制，情绪压迫，保留停顿',
              },
            ],
          },
          <String, Object?>{
            'id': 'memory-2',
            'name': 'quality_feedback_memory',
            'role': 'assistant',
            'content': <Map<String, String>>[
              <String, String>{
                'data': 'production agent 建议先刷新 storyboardTable 再补镜头。',
              },
            ],
          },
        ],
    memorySummary: memorySummary,
    statusLine: statusLine,
    loadingProjects: loadingProjects,
    loadingMemory: loadingMemory,
    appendingMemory: appendingMemory,
    clearingMemory: clearingMemory,
    queryType: queryTypeCtrl.text,
    clearType: clearTypeCtrl.text,
    queryTypeOptions: const <String>['summary', 'message', 'all'],
    clearTypeOptions: const <String>['summary', 'message', 'all'],
    projectIdCtrl: projectIdCtrl,
    agentTypeCtrl: agentTypeCtrl,
    episodesIdCtrl: episodesIdCtrl,
    queryTypeCtrl: queryTypeCtrl,
    appendContentCtrl: appendContentCtrl,
    appendRoleCtrl: appendRoleCtrl,
    clearTypeCtrl: clearTypeCtrl,
  );
}

ProjectsAgentMemoryWorkbenchDialogViewCallbacks buildCallbacks({
  Future<void> Function()? onReloadProjects,
  Future<void> Function()? onQueryMemory,
  Future<void> Function()? onAppendMemory,
  Future<void> Function()? onClearMemory,
  VoidCallback? onClose,
}) {
  return ProjectsAgentMemoryWorkbenchDialogViewCallbacks(
    onReloadProjects: onReloadProjects ?? () async {},
    onQueryMemory: onQueryMemory ?? () async {},
    onAppendMemory: onAppendMemory ?? () async {},
    onClearMemory: onClearMemory ?? () async {},
    onQueryTypeChanged: (_) {},
    onClearTypeChanged: (_) {},
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
  late TextEditingController appendContentCtrl;
  late TextEditingController appendRoleCtrl;
  late TextEditingController clearTypeCtrl;

  setUp(() {
    projectIdCtrl = TextEditingController(text: '11');
    agentTypeCtrl = TextEditingController(text: 'scriptAgent');
    episodesIdCtrl = TextEditingController(text: '3');
    queryTypeCtrl = TextEditingController(text: 'summary');
    appendContentCtrl = TextEditingController(text: '需要补一个反转伏笔。');
    appendRoleCtrl = TextEditingController(text: 'user');
    clearTypeCtrl = TextEditingController(text: 'summary');
  });

  tearDown(() {
    projectIdCtrl.dispose();
    agentTypeCtrl.dispose();
    episodesIdCtrl.dispose();
    queryTypeCtrl.dispose();
    appendContentCtrl.dispose();
    appendRoleCtrl.dispose();
    clearTypeCtrl.dispose();
  });

  testWidgets('agent memory workbench view renders summary and rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('Agent 记忆工作台'), findsOneWidget);
    expect(find.textContaining('项目 2 个'), findsOneWidget);
    expect(find.text('已读取 2 条记忆。'), findsOneWidget);
    expect(find.text('summary / message / all'), findsNWidgets(2));
    expect(
      find.text('自动记忆按 项目 numeric ID + agent type + episodes id 独立隔离。'),
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
    expect(find.text('2 条记忆'), findsOneWidget);
    expect(find.text('追加记忆'), findsNWidgets(2));
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
                      'data': 'storyboardIds=12 | note=表演克制压抑，避免读稿腔，保留真实停顿与呼吸',
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
                          'storyboardIds=15 | note=表演克制压抑，避免读稿腔，保留真实停顿与呼吸，再加一点冷感尾音',
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

  testWidgets('agent memory workbench view disables busy actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
            ),
            callbacks: buildCallbacks(),
          ),
        ),
      ),
    );

    expect(disabledButtonWithText('…'), findsNWidgets(4));
  });

  testWidgets('agent memory workbench view forwards action callbacks', (
    WidgetTester tester,
  ) async {
    var reloadCalls = 0;
    var queryCalls = 0;
    var appendCalls = 0;
    var clearCalls = 0;
    var closeCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
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
    await tester.ensureVisible(find.widgetWithText(FilledButton, '追加记忆'));
    await tester.tap(find.widgetWithText(FilledButton, '追加记忆'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '执行清理'));
    await tester.tap(find.widgetWithText(FilledButton, '执行清理'));
    await tester.pump();
    await tester.tap(find.text('关闭'));
    await tester.pump();

    expect(reloadCalls, 1);
    expect(queryCalls, 1);
    expect(appendCalls, 1);
    expect(clearCalls, 1);
    expect(closeCalls, 1);
  });
}
