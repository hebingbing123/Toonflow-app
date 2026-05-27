import '../product_shell/studio_shell_branches.dart';
import '../project_studio/project_studio_navigation.dart';
import '../shell/navigation_controller.dart';
import '../project_studio/studio_step.dart';
import 'product_demo_tour.dart';
import 'product_demo_tour_anchors.dart';

/// Expected length of [ProductDemoTour.buildDefaultStops] (update when adding beats).
const int kProductDemoTourBeatCount = 24;

/// Builds the full demo tour: intro + mainline multi-step SOP + utility panes.
List<ProductDemoTourStop> buildProductDemoTourStops() {
  return <ProductDemoTourStop>[
    ..._introStops(),
    ..._mainlineStops(),
    ..._utilityStops(),
  ];
}

int _mainlineNumber(StudioStep step) => switch (step) {
  StudioStep.script => 1,
  StudioStep.art => 2,
  StudioStep.assets => 3,
  StudioStep.storyboard => 4,
  StudioStep.video => 5,
  StudioStep.deliver => 6,
  _ => 0,
};

String _projectStepLocation(StudioStep step) {
  return projectStudioStepUri(
    ProductDemoTour.kDemoProjectNumericId,
    step,
    storyboardScriptNumericId: step == StudioStep.storyboard
        ? ProductDemoTour.kDemoStoryboardScriptNumericId
        : null,
  ).toString();
}

List<ProductDemoTourStop> _introStops() {
  return <ProductDemoTourStop>[
    ProductDemoTourStop(
      location: '/',
      titleZh: '从这里开始',
      titleEn: 'Start here',
      shortLabelZh: '项目首页',
      shortLabelEn: 'Projects home',
      anchorId: ProductDemoTourAnchorIds.projectsGrid,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh:
          '浏览示例项目卡片与进度。可点进「春季短剧 · 演示」进入工作室，或点卡片下方「下一步」继续导览。',
      guideEn:
          'Browse sample project cards and progress. Open “Spring Short Drama · Demo” or tap Next on the card to continue the tour.',
      dwell: const Duration(seconds: 4),
      sections: const ProductDemoTourGuideSections(
        positionZh: '欢迎体验演示。接下来会走一条「做短剧并准备上线」的示范线。',
        positionEn:
            'Welcome to the demo. You will follow a sample path from script to publish-ready.',
        goalZh: '认识项目入口，并打开示例项目「春季短剧 · 演示」。',
        goalEn:
            'Find the project list and open the sample project “Spring Short Drama · Demo”.',
        bulletsZh: <String>[
          '项目卡片上的圆环（如 5/6）表示这个示例项目整体制作进度',
          '右上角「第 x / 24 步」是本次导览进度，两者含义不同',
        ],
        bulletsEn: <String>[
          'The ring on a card (e.g. 5/6) is overall production progress for that sample project',
          '“Step x of 24” in the coach card is this tour only—the two numbers are not the same',
        ],
        demoNoteZh: '演示数据不会写入你的真实账号。',
        demoNoteEn: 'Demo data is never saved to your real account.',
        nextHintZh: '点「下一步」进入示例项目，从「剧本」开始做片主线。',
        nextHintEn: 'Tap Next to enter the sample project and start the Script leg of the main line.',
      ),
    ),
  ];
}

List<ProductDemoTourStop> _mainlineStops() {
  final storyboardUri = _projectStepLocation(StudioStep.storyboard);

  ProductDemoTourStop sopBeat({
    required StudioStep step,
    required int part,
    required int partTotal,
    required String titleZh,
    required String titleEn,
    required ProductDemoTourGuideSections sections,
    ProductDemoCoachStyle coachStyle = ProductDemoCoachStyle.spotlight,
    Duration dwell = const Duration(seconds: 5),
    String? anchorId,
  }) {
    final mainline = _mainlineNumber(step);
    return ProductDemoTourStop(
      location: step == StudioStep.storyboard
          ? storyboardUri
          : _projectStepLocation(step),
      titleZh: titleZh,
      titleEn: titleEn,
      shortLabelZh: '制作主线 · ${step.slug} · $part/$partTotal',
      shortLabelEn: 'Main line · ${step.slug} · $part/$partTotal',
      anchorId: anchorId ?? ProductDemoTourAnchorIds.studioJourney,
      coachStyle: coachStyle,
      guideZh: sections.compactBodyForLocale('zh'),
      guideEn: sections.compactBodyForLocale('en'),
      dwell: dwell,
      mainlineStep: mainline,
      mainlinePart: part,
      mainlinePartTotal: partTotal,
      sections: sections,
    );
  }

  return <ProductDemoTourStop>[
    // —— Script (2) ——
    sopBeat(
      step: StudioStep.script,
      part: 1,
      partTotal: 2,
      titleZh: '剧本 · ① 内容与导入',
      titleEn: 'Script · ① Content & import',
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 1/6 步：一切从剧本和场次开始。',
        positionEn: 'Main line step 1/6: everything starts with script and scenes.',
        goalZh: '确认本项目已有可拍的剧本/场次（演示已预填）。',
        goalEn:
            'Confirm this project has shootable script content (preloaded in the demo).',
        bulletsZh: <String>[
          '左侧：小说导入、剧本列表与场次入口',
          '可打开剧本工作台查看大纲与正文布局',
          '右侧 Agent 区：演示对话为只读样例',
        ],
        bulletsEn: <String>[
          'Left rail: novel import, script list, and scene entry points',
          'Open the script workbench to see outline vs body layout',
          'Agent sidebar on the right is read-only sample chat',
        ],
        demoNoteZh: '演示模式下保存会被拦截，可放心浏览。',
        demoNoteEn: 'Saves are blocked in demo mode—browse freely.',
        nextHintZh: '下一步：认识本步的模型与快捷操作区。',
        nextHintEn: 'Next: model routing and quick actions on this step.',
      ),
    ),
    sopBeat(
      step: StudioStep.script,
      part: 2,
      partTotal: 2,
      titleZh: '剧本 · ② 模型与起步',
      titleEn: 'Script · ② Models & starters',
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: const ProductDemoTourGuideSections(
        goalZh: '了解如何为后续 AI 生成配置模型路由（真项目需在设置里填 API Key）。',
        goalEn:
            'See how model routing is set up before AI generation (real projects need API keys in Settings).',
        bulletsZh: <String>[
          '顶部或设置区：模型厂商 / 路由条',
          '起步模板与快捷动作：一键进入常见工作流',
          '项目驾驶舱：进度与下一步建议',
        ],
        bulletsEn: <String>[
          'Top or setup area: vendor routing bar',
          'Starter templates and quick actions for common flows',
          'Project cockpit: progress and suggested next actions',
        ],
        demoNoteZh: '真环境生成前请完成「设置 → 模型厂商」。',
        demoNoteEn: 'In production, finish Settings → Model vendors before generating.',
        nextHintZh: '剧本就绪后进入「美术」定视觉风格。',
        nextHintEn: 'When script is ready, continue to Art for visual direction.',
      ),
    ),
    // —— Art (2) ——
    sopBeat(
      step: StudioStep.art,
      part: 1,
      partTotal: 2,
      titleZh: '美术 · ① 风格与画板',
      titleEn: 'Art · ① Style & boards',
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 2/6 步：统一全片视觉语言。',
        positionEn: 'Main line step 2/6: align the visual language for the whole piece.',
        goalZh: '选定美术/叙事风格包，让后续出图一致。',
        goalEn: 'Pick art and story style packs so later images stay consistent.',
        bulletsZh: <String>[
          '风格包选择器与参考说明',
          '可读性卡片：当前风格摘要',
          '需要时可打开完整项目设置',
        ],
        bulletsEn: <String>[
          'Style pack picker and reference notes',
          'Readiness card with a summary of current style',
          'Open full project settings when you need more control',
        ],
        demoNoteZh: '演示中修改不会保存到真实项目。',
        demoNoteEn: 'Edits in the demo are not persisted.',
        nextHintZh: '下一步：对照就绪度清单补缺口。',
        nextHintEn: 'Next: use the readiness checklist to close gaps.',
      ),
    ),
    sopBeat(
      step: StudioStep.art,
      part: 2,
      partTotal: 2,
      titleZh: '美术 · ② 就绪度',
      titleEn: 'Art · ② Readiness',
      sections: const ProductDemoTourGuideSections(
        goalZh: '把美术步的阻塞项清掉，再进资产与分镜。',
        goalEn: 'Clear blockers on the Art step before Assets and Storyboard.',
        bulletsZh: <String>[
          '就绪度分数与进度条',
          '检查清单：点条目可跳到对应操作（演示为样例）',
          '完成后顶栏「下一步」会指向资产步',
        ],
        bulletsEn: <String>[
          'Readiness score and progress bar',
          'Checklist items jump to the related action (sample in demo)',
          'When ready, the top “Next” control aims at Assets',
        ],
        nextHintZh: '进入「资产」准备角色与参考素材。',
        nextHintEn: 'Continue to Assets for characters and references.',
      ),
    ),
    // —— Assets (2) ——
    sopBeat(
      step: StudioStep.assets,
      part: 1,
      partTotal: 2,
      titleZh: '资产 · ① 角色库',
      titleEn: 'Assets · ① Character library',
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 3/6 步：为分镜出图准备可复用素材。',
        positionEn: 'Main line step 3/6: prepare reusable media before storyboard generation.',
        goalZh: '浏览角色/道具资产，确认演示项目里有哪些可用素材。',
        goalEn: 'Browse character and prop assets available in the sample project.',
        bulletsZh: <String>[
          '角色资产卡片与数量统计',
          '打开资产步 / 资产编辑器查看详情',
          'Agent 侧栏：示例协作对话（只读）',
        ],
        bulletsEn: <String>[
          'Character asset cards and counts',
          'Open the asset step or asset editor for details',
          'Agent sidebar shows sample collaboration (read-only)',
        ],
        demoNoteZh: '示例项目可能故意保留「待锚点」提示。',
        demoNoteEn: 'The sample may deliberately show a “pending anchor” hint.',
        nextHintZh: '下一步：补齐主角锚点（真项目必做）。',
        nextHintEn: 'Next: complete lead character anchors (required in real projects).',
      ),
    ),
    sopBeat(
      step: StudioStep.assets,
      part: 2,
      partTotal: 2,
      titleZh: '资产 · ② 锚点',
      titleEn: 'Assets · ② Anchors',
      sections: const ProductDemoTourGuideSections(
        goalZh: '理解「锚点」：锁定脸型/服装，分镜批量出图才稳定。',
        goalEn:
            'Anchors lock face and wardrobe so batch storyboard generation stays consistent.',
        bulletsZh: <String>[
          '待锚点提示与「还差 N 个锚点」文案',
          '补齐后可进入分镜批量出图',
          '顶栏旅程条可随时切到分镜',
        ],
        bulletsEn: <String>[
          'Pending-anchor hints and “N anchors left” copy',
          'After anchors, you can batch-generate storyboard frames',
          'Use the journey strip to jump to Storyboard anytime',
        ],
        nextHintZh: '资产就绪后进入「分镜」（导览会分 4 小步介绍）。',
        nextHintEn: 'When assets are ready, continue to Storyboard (four short beats in this tour).',
      ),
    ),
    // —— Storyboard (4) ——
    sopBeat(
      step: StudioStep.storyboard,
      part: 1,
      partTotal: 4,
      titleZh: '分镜 · ① 选集',
      titleEn: 'Storyboard · ① Pick episode',
      dwell: const Duration(seconds: 5),
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 4/6 步：把剧本变成可操作的镜头列表。',
        positionEn: 'Main line step 4/6: turn script into an actionable shot list.',
        goalZh: '在分镜工作室顶部选好要做的那一集（演示已预选示例集）。',
        goalEn:
            'Select the episode to work on at the top of Storyboard Studio (preselected in the demo).',
        bulletsZh: <String>[
          '集数 / 剧本下拉',
          '若列表为空，需先回剧本步补场次',
        ],
        bulletsEn: <String>[
          'Episode / script dropdown',
          'If the list is empty, go back to Script to add scenes',
        ],
        demoNoteZh: '演示不会修改真实镜头数据。',
        demoNoteEn: 'The demo does not change real shot data.',
        nextHintZh: '下一步：认识左侧镜头列表。',
        nextHintEn: 'Next: the shot list on the left.',
      ),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 2,
      partTotal: 4,
      titleZh: '分镜 · ② 镜头列表',
      titleEn: 'Storyboard · ② Shot list',
      sections: const ProductDemoTourGuideSections(
        goalZh: '逐镜检查编号、缩略图与状态（待出图 / 已出图等）。',
        goalEn:
            'Review each shot’s index, thumbnail, and status (pending, generated, etc.).',
        bulletsZh: <String>[
          '左侧：镜头列表，点一条选中',
          '中间：当前镜预览',
          '右侧：提示词、时长等属性（演示只读）',
        ],
        bulletsEn: <String>[
          'Left: shot list—tap a row to select',
          'Center: preview for the active shot',
          'Right: prompt, duration, and properties (read-only in demo)',
        ],
        nextHintZh: '列表齐全后，用工具栏做「网格批量出图」。',
        nextHintEn: 'When the list looks good, use the toolbar for grid batch generation.',
      ),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 3,
      partTotal: 4,
      titleZh: '分镜 · ③ 批量出图',
      titleEn: 'Storyboard · ③ Batch images',
      sections: const ProductDemoTourGuideSections(
        goalZh: '一次为多镜生成画面（演示模拟入队，不扣费真渲染）。',
        goalEn:
            'Generate frames for many shots at once (demo simulates enqueue—no real billed render).',
        bulletsZh: <String>[
          '工具栏：网格分镜 / 批量出图',
          '弹窗选择行列数后确认',
          '进度可在后面的「任务中心」查看',
        ],
        bulletsEn: <String>[
          'Toolbar: grid storyboard / batch image generation',
          'Pick rows and columns in the dialog, then confirm',
          'Track progress later in Tasks',
        ],
        demoNoteZh: '真项目出图前请配置模型厂商 API Key。',
        demoNoteEn: 'Configure model vendor API keys before real generation.',
        nextHintZh: '某一镜不满意时，可进单镜/出图工作台精修。',
        nextHintEn: 'For a single weak frame, open the image workbench next.',
      ),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 4,
      partTotal: 4,
      titleZh: '分镜 · ④ 单镜精修',
      titleEn: 'Storyboard · ④ Shot workbench',
      sections: const ProductDemoTourGuideSections(
        goalZh: '对单镜改提示词、换图或重新生成，直到画面可用。',
        goalEn: 'Tune prompts, swap images, or regenerate one shot until it is usable.',
        bulletsZh: <String>[
          '列表中的「打开出图工作台」等入口',
          '工作台：提示词、参考图、生成记录（演示样例）',
          '也可从制作工作台跨项目查看 Agent 输出',
        ],
        bulletsEn: <String>[
          'Entries such as “Open image workbench” on a shot row',
          'Workbench: prompts, references, generation history (samples)',
          'Production workspace shows cross-project agent output later',
        ],
        nextHintZh: '分镜画面稳定后进入「视频」步拼成片。',
        nextHintEn: 'When frames are stable, continue to Video to assemble the piece.',
      ),
    ),
    // —— Video (2) ——
    sopBeat(
      step: StudioStep.video,
      part: 1,
      partTotal: 2,
      titleZh: '视频 · ① 成片策略',
      titleEn: 'Video · ① Assembly mode',
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 5/6 步：把分镜画面拼成可交付的视频。',
        positionEn: 'Main line step 5/6: assemble storyboard frames into deliverable video.',
        goalZh: '选择成片策略：首帧 / 尾帧 / 分镜板等模式（按项目需要）。',
        goalEn: 'Choose how video is assembled: first frame, last frame, storyboard board, etc.',
        bulletsZh: <String>[
          '分段按钮切换成片模式',
          '选择会按项目记住',
          '演示不触发真实渲染队列',
        ],
        bulletsEn: <String>[
          'Segmented control for assembly mode',
          'Choice is remembered per project',
          'Demo does not enqueue real renders',
        ],
        nextHintZh: '下一步：进入制作流水线查看生成与导出。',
        nextHintEn: 'Next: open the production pipeline for generation and export.',
      ),
    ),
    sopBeat(
      step: StudioStep.video,
      part: 2,
      partTotal: 2,
      titleZh: '视频 · ② 制作流水线',
      titleEn: 'Video · ② Production pipeline',
      sections: const ProductDemoTourGuideSections(
        goalZh: '在制作工作台跟踪视频生成、写回与任务状态。',
        goalEn:
            'Use the production workspace to track video jobs, writebacks, and task status.',
        bulletsZh: <String>[
          '本步可跳转「打开制作 / Production」',
          '任务中心汇总渲染与导出队列',
          '真项目里在此等待成片完成',
        ],
        bulletsEn: <String>[
          'Open Production from this step when available',
          'Tasks aggregates render and export queues',
          'In real projects, wait here for the master to finish',
        ],
        nextHintZh: '成片后进入「交付」做导出前检查。',
        nextHintEn: 'After video is ready, open Deliver for pre-export checks.',
      ),
    ),
    // —— Deliver (2) ——
    sopBeat(
      step: StudioStep.deliver,
      part: 1,
      partTotal: 2,
      titleZh: '交付 · ① 导出清单',
      titleEn: 'Deliver · ① Export checklist',
      sections: const ProductDemoTourGuideSections(
        positionZh: '制作主线第 6/6 步：确认可以交出成片。',
        positionEn: 'Main line step 6/6: confirm the piece is ready to hand off.',
        goalZh: '对照交付清单，处理音乐、字幕、权限等阻塞项。',
        goalEn: 'Work through the deliver checklist: audio, subtitles, rights, and blockers.',
        bulletsZh: <String>[
          '交付步检查清单与准备度',
          '旅程条可打开「审片包」里程碑',
          '质量子页可看阶段评分（演示为样例）',
        ],
        bulletsEn: <String>[
          'Deliver checklists and readiness',
          'Journey strip links to Review pack',
          'Quality sub-tab shows stage scores (sample data)',
        ],
        demoNoteZh: '这是上线前的质量闸口，不是可跳过的装饰页。',
        demoNoteEn: 'This is a quality gate before launch—not a decorative screen.',
        nextHintZh: '下一步：用审片包收反馈、清阻塞。',
        nextHintEn: 'Next: use Review pack for feedback and blockers.',
      ),
    ),
    sopBeat(
      step: StudioStep.deliver,
      part: 2,
      partTotal: 2,
      titleZh: '交付 · ② 过片与导出',
      titleEn: 'Deliver · ② Review & export',
      sections: const ProductDemoTourGuideSections(
        goalZh: '从旅程条或菜单打开「审片包」，收齐反馈并清掉导出阻塞。',
        goalEn:
            'Open Review pack from the journey strip or menu, collect feedback, and clear export blockers.',
        bulletsZh: <String>[
          '交付页：导出准备度与阻塞摘要',
          '审片包：缩略图、反馈状态、筛选与展开',
          '全部通过后，才进入发布检查',
        ],
        bulletsEn: <String>[
          'Deliver tab: export readiness and blocker summary',
          'Review pack: thumbnails, feedback, filters, and row detail',
          'Move to publish checks only after blockers are cleared',
        ],
        nextHintZh: '下一步进入「短视频空间」，走完就绪度与发布检查。',
        nextHintEn: 'Next: Short video for readiness and publish gates.',
      ),
    ),
    // —— Short video / launch (2) — same utility pane, two beats ——
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.shortVideoSpace),
      titleZh: '上线 · ① 就绪度',
      titleEn: 'Launch · ① Readiness',
      shortLabelZh: '短视频 · 就绪',
      shortLabelEn: 'Short video · readiness',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 5),
      launchPart: 1,
      launchPartTotal: 2,
      sections: const ProductDemoTourGuideSections(
        positionZh: '从「做出片」到「能上线」：短视频空间负责发布前检查。',
        positionEn: 'From “master done” to “ready to publish”: Short video handles pre-launch checks.',
        goalZh: '看成片就绪度：缺素材、时长、封面等问题会在这里汇总。',
        goalEn: 'Check master readiness—missing assets, duration, cover, etc. surface here.',
        bulletsZh: <String>[
          '切换概览 / 时间线 / 发布等子页签',
          '就绪度指标与阻塞说明',
          '演示数据不会连接真实发布渠道',
        ],
        bulletsEn: <String>[
          'Switch overview, timeline, publish, and other tabs',
          'Readiness metrics and blocker explanations',
          'Demo does not connect to real distribution channels',
        ],
        demoNoteZh: '真账号在此对接渠道；演示只走流程。',
        demoNoteEn: 'Production accounts connect channels here; the demo is walkthrough only.',
        nextHintZh: '下一步：发布检查单。',
        nextHintEn: 'Next: the publish checklist.',
      ),
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.shortVideoSpace),
      titleZh: '上线 · ② 发布检查',
      titleEn: 'Launch · ② Publish gates',
      shortLabelZh: '短视频 · 发布',
      shortLabelEn: 'Short video · publish',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 5),
      launchPart: 2,
      launchPartTotal: 2,
      sections: const ProductDemoTourGuideSections(
        goalZh: '走完发布前检查单，确认可以对外上线。',
        goalEn: 'Complete pre-publish gates before going live.',
        bulletsZh: <String>[
          '发布检查项与状态',
          '时间线核对镜头与配音',
          '通过后即完成「做片并上线」示范线',
        ],
        bulletsEn: <String>[
          'Publish checklist and statuses',
          'Timeline for shots and audio alignment',
          'Finishing this completes the script-to-launch sample path',
        ],
        nextHintZh: '主线结束后，导览会简短介绍任务、通知等辅助功能（可跳过）。',
        nextHintEn: 'After the main path, optional beats cover Tasks, notifications, and more.',
      ),
    ),
  ];
}

List<ProductDemoTourStop> _utilityStops() {
  final projectId = ProductDemoTour.kDemoProjectNumericId;
  return <ProductDemoTourStop>[
    ProductDemoTourStop(
      location: '/projects/$projectId/review-pack',
      titleZh: '审片包（深入）',
      titleEn: 'Review pack (deep dive)',
      shortLabelZh: '审片包',
      shortLabelEn: 'Review pack',
      anchorId: ProductDemoTourAnchorIds.shellContent,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 4),
      isOptionalUtility: true,
      sections: const ProductDemoTourGuideSections(
        goalZh: '【可选】练习审片包筛选、反馈与导出阻塞项。',
        goalEn:
            '[Optional] Practice Review pack filters, feedback, and export blockers.',
        bulletsZh: <String>[
          '缩略图网格与反馈状态列',
          '展开行查看阻塞原因',
        ],
        bulletsEn: <String>[
          'Thumbnail grid and feedback status',
          'Expand rows to see blocker reasons',
        ],
        nextHintZh: '上线前团队常用；做完主线后可随时回来。',
        nextHintEn: 'Common before launch; revisit after the main line.',
      ),
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.tasks),
      titleZh: '任务中心',
      titleEn: 'Tasks',
      shortLabelZh: '任务中心',
      shortLabelEn: 'Tasks',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '【可选】查看渲染、导出等后台任务。做片时用来盯进度，演示为示例记录。',
      guideEn:
          '[Optional] Monitor render and export jobs. Useful while producing; demo rows are samples only.',
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.quality),
      titleZh: '质量评审',
      titleEn: 'Quality',
      shortLabelZh: '质量评审',
      shortLabelEn: 'Quality',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '【可选】浏览阶段评分与评审意见。上线不必须，适合质检岗位。',
      guideEn:
          '[Optional] Browse stage scores and review notes. Not required to launch; good for QA roles.',
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.notifications),
      titleZh: '通知',
      titleEn: 'Notifications',
      shortLabelZh: '通知',
      shortLabelEn: 'Notifications',
      anchorId: ProductDemoTourAnchorIds.shellAppBar,
      coachStyle: ProductDemoCoachStyle.calloutAbove,
      guideZh: '【可选】协作与任务通知。演示条目可标记已读。',
      guideEn: '[Optional] Collaboration and task alerts. Sample entries can be marked read.',
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.productionWorkspace),
      titleZh: '制作工作台',
      titleEn: 'Production workspace',
      shortLabelZh: '制作工作台',
      shortLabelEn: 'Production workspace',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '【可选】跨项目 Agent 与流水线日志。进阶用户常用。',
      guideEn: '[Optional] Cross-project agent and pipeline logs—popular with power users.',
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.scriptWorkspace),
      titleZh: '剧本工作台',
      titleEn: 'Script workspace',
      shortLabelZh: '剧本工作台',
      shortLabelEn: 'Script workspace',
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '【可选】独立长剧本视图，适合多集连载。',
      guideEn: '[Optional] Dedicated long-form script view for serial projects.',
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.helpHub),
      titleZh: '帮助中心',
      titleEn: 'Help',
      shortLabelZh: '帮助中心',
      shortLabelEn: 'Help',
      anchorId: ProductDemoTourAnchorIds.shellAppBar,
      coachStyle: ProductDemoCoachStyle.floatingCard,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 3),
      isOptionalUtility: true,
      sections: const ProductDemoTourGuideSections(
        goalZh: '【可选】查文档、Webhook 与计费说明。',
        goalEn: '[Optional] Browse docs, webhooks, and billing.',
        bulletsZh: <String>[
          '演示模式下列表为样例，不会改真实配置',
          '做完「做片上线」主线后再来看即可',
        ],
        bulletsEn: <String>[
          'Lists are samples in demo—no real settings change',
          'Visit after you finish the script-to-launch main line',
        ],
      ),
    ),
  ];
}
