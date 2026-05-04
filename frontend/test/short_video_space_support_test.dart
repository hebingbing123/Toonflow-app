import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/short_video_space/support.dart';
import 'package:openflow_app/short_video_space/view.dart';

void main() {
  test('live-action readiness highlights scene clip and manual gaps', () {
    final items = buildShortVideoReadinessItems(
      isAnimated: false,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 7,
        mode: 'live_action.short_drama',
        artStylePack: 'art_skills/modern_cn',
        createTimeMs: 1,
      ),
      stats: const ProjectStats(
        scriptCount: 1,
        storyboardCount: 0,
        roleCount: 2,
        novelCount: 0,
        videoCount: 0,
      ),
      sceneAssetCount: 0,
      clipAssetCount: 0,
    );

    expect(items, hasLength(6));
    expect(items.where((item) => item.ready).map((item) => item.label), [
      '剧本基础',
      '角色设定',
      '视觉手册',
    ]);
    expect(items.where((item) => !item.ready).map((item) => item.label), [
      '场景参考',
      '镜头素材',
      '表演 / 口播手册',
    ]);
  });

  test('live-action next step prefers scene references before clip refs', () {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: false,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 7,
        mode: 'live_action.short_drama',
        artStylePack: 'art_skills/modern_cn',
        directorManual: 'spoken-showcase',
        createTimeMs: 1,
      ),
      stats: const ProjectStats(
        scriptCount: 1,
        storyboardCount: 1,
        roleCount: 1,
        novelCount: 0,
        videoCount: 0,
      ),
      recentProjectTasks: const TaskCenterGetTaskApiResult(
        data: <JobRow>[],
        total: 0,
      ),
      qualityScopeInsight: null,
      sceneAssetCount: 0,
      clipAssetCount: 3,
    );

    expect(plan.title, '先补真人场景参考');
    expect(plan.buttonLabel, '打开项目区补准备项');
    expect(plan.target, ShortVideoNextStepTarget.projects);
  });

  test('failed tasks override creative prep routing', () {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: true,
      project: const ProjectRow(
        id: 'project-1',
        numericId: 9,
        mode: 'animated.short_drama',
        artStyle: '国风二次元',
        directorManual: 'heroic',
        createTimeMs: 1,
      ),
      stats: const ProjectStats(
        scriptCount: 2,
        storyboardCount: 3,
        roleCount: 2,
        novelCount: 0,
        videoCount: 0,
      ),
      recentProjectTasks: const TaskCenterGetTaskApiResult(
        data: <JobRow>[
          JobRow(
            numericTaskId: 1,
            id: 'job-1',
            ownerUserId: 'user-1',
            kind: 'video.generate',
            status: 'failed',
            payload: <String, dynamic>{},
            createdAt: '2026-05-05T00:00:00Z',
            updatedAt: '2026-05-05T00:00:00Z',
          ),
        ],
        total: 1,
      ),
      qualityScopeInsight: null,
      sceneAssetCount: 4,
      clipAssetCount: 0,
    );

    expect(plan.title, '先处理失败任务');
    expect(plan.target, ShortVideoNextStepTarget.tasks);
  });

  test('mode and ratio labels stay human readable', () {
    expect(shortVideoModeLabel(ShortVideoMode.animated), '动漫短剧');
    expect(shortVideoModeLabel(ShortVideoMode.liveAction), '真人短剧');
    expect(shortVideoVideoRatioLabel('16:9'), '横屏 16:9');
    expect(shortVideoVideoRatioLabel('9:16'), '竖屏 9:16');
  });
}
