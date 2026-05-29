import '../product_shell/studio_shell_branches.dart';
import '../project_studio/project_studio_navigation.dart';
import '../shell/navigation_controller.dart';
import '../project_studio/studio_step.dart';
import '../l10n/app_localizations.dart';
import 'demo_tour_bilingual_l10n.dart';
import 'product_demo_tour.dart';
import 'product_demo_tour_anchors.dart';
import 'product_demo_tour_mainline_l10n.dart';

/// Expected length of [ProductDemoTour.buildDefaultStops] (update when adding beats).
const int kProductDemoTourBeatCount = 24;

/// Builds the full demo tour: intro + mainline multi-step SOP + utility panes.
List<ProductDemoTourStop> buildProductDemoTourStops() {
  final l10n = demoTourBilingualL10n();
  return <ProductDemoTourStop>[
    ..._introStops(l10n.zh, l10n.en),
    ..._mainlineStops(l10n.zh, l10n.en),
    ..._utilityStops(l10n.zh, l10n.en),
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

List<ProductDemoTourStop> _introStops(AppLocalizations zh, AppLocalizations en) {
  final projectZh = zh.demoStudioProjectDisplayName;
  final projectEn = en.demoStudioProjectDisplayName;
  return <ProductDemoTourStop>[
    ProductDemoTourStop(
      location: '/',
      titleZh: zh.demoTourIntroTitle,
      titleEn: en.demoTourIntroTitle,
      shortLabelZh: zh.demoTourIntroShortLabel,
      shortLabelEn: en.demoTourIntroShortLabel,
      anchorId: ProductDemoTourAnchorIds.projectsGrid,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh: zh.demoTourIntroGuide(projectZh),
      guideEn: en.demoTourIntroGuide(projectEn),
      dwell: const Duration(seconds: 4),
      sections: ProductDemoTourGuideSections(
        positionZh: zh.demoTourIntroPosition,
        positionEn: en.demoTourIntroPosition,
        goalZh: zh.demoTourIntroGoal(projectZh),
        goalEn: en.demoTourIntroGoal(projectEn),
        bulletsZh: <String>[
          zh.demoTourIntroBulletProgressRing,
          zh.demoTourIntroBulletStepCounter,
        ],
        bulletsEn: <String>[
          en.demoTourIntroBulletProgressRing,
          en.demoTourIntroBulletStepCounter,
        ],
        demoNoteZh: zh.demoTourIntroDemoNote,
        demoNoteEn: en.demoTourIntroDemoNote,
        nextHintZh: zh.demoTourIntroNextHint,
        nextHintEn: en.demoTourIntroNextHint,
      ),
    ),
  ];
}

List<ProductDemoTourStop> _mainlineStops(AppLocalizations zh, AppLocalizations en) {
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
      shortLabelZh: zh.demoTourBeatShortLabel(step.slug, part, partTotal),
      shortLabelEn: en.demoTourBeatShortLabel(step.slug, part, partTotal),
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
    sopBeat(
      step: StudioStep.script,
      part: 1,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Script1', zh),
      titleEn: demoTourMainlineTitle('Script1', en),
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: demoTourMainlineSections('Script1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.script,
      part: 2,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Script2', zh),
      titleEn: demoTourMainlineTitle('Script2', en),
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: demoTourMainlineSections('Script2', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.art,
      part: 1,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Art1', zh),
      titleEn: demoTourMainlineTitle('Art1', en),
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: demoTourMainlineSections('Art1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.art,
      part: 2,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Art2', zh),
      titleEn: demoTourMainlineTitle('Art2', en),
      sections: demoTourMainlineSections('Art2', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.assets,
      part: 1,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Assets1', zh),
      titleEn: demoTourMainlineTitle('Assets1', en),
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      sections: demoTourMainlineSections('Assets1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.assets,
      part: 2,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Assets2', zh),
      titleEn: demoTourMainlineTitle('Assets2', en),
      sections: demoTourMainlineSections('Assets2', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 1,
      partTotal: 4,
      titleZh: demoTourMainlineTitle('Storyboard1', zh),
      titleEn: demoTourMainlineTitle('Storyboard1', en),
      dwell: const Duration(seconds: 5),
      sections: demoTourMainlineSections('Storyboard1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 2,
      partTotal: 4,
      titleZh: demoTourMainlineTitle('Storyboard2', zh),
      titleEn: demoTourMainlineTitle('Storyboard2', en),
      sections: demoTourMainlineSections('Storyboard2', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 3,
      partTotal: 4,
      titleZh: demoTourMainlineTitle('Storyboard3', zh),
      titleEn: demoTourMainlineTitle('Storyboard3', en),
      sections: demoTourMainlineSections('Storyboard3', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.storyboard,
      part: 4,
      partTotal: 4,
      titleZh: demoTourMainlineTitle('Storyboard4', zh),
      titleEn: demoTourMainlineTitle('Storyboard4', en),
      sections: demoTourMainlineSections('Storyboard4', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.video,
      part: 1,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Video1', zh),
      titleEn: demoTourMainlineTitle('Video1', en),
      coachStyle: ProductDemoCoachStyle.spotlight,
      sections: demoTourMainlineSections('Video1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.video,
      part: 2,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Video2', zh),
      titleEn: demoTourMainlineTitle('Video2', en),
      sections: demoTourMainlineSections('Video2', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.deliver,
      part: 1,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Deliver1', zh),
      titleEn: demoTourMainlineTitle('Deliver1', en),
      sections: demoTourMainlineSections('Deliver1', zh: zh, en: en),
    ),
    sopBeat(
      step: StudioStep.deliver,
      part: 2,
      partTotal: 2,
      titleZh: demoTourMainlineTitle('Deliver2', zh),
      titleEn: demoTourMainlineTitle('Deliver2', en),
      sections: demoTourMainlineSections('Deliver2', zh: zh, en: en),
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.shortVideoSpace),
      titleZh: zh.demoTourLaunchReadinessTitle,
      titleEn: en.demoTourLaunchReadinessTitle,
      shortLabelZh: zh.demoTourLaunchReadinessShortLabel,
      shortLabelEn: en.demoTourLaunchReadinessShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 5),
      launchPart: 1,
      launchPartTotal: 2,
      sections: demoTourMainlineSections('LaunchReadiness', zh: zh, en: en),
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.shortVideoSpace),
      titleZh: zh.demoTourLaunchPublishTitle,
      titleEn: en.demoTourLaunchPublishTitle,
      shortLabelZh: zh.demoTourLaunchPublishShortLabel,
      shortLabelEn: en.demoTourLaunchPublishShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.spotlight,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 5),
      launchPart: 2,
      launchPartTotal: 2,
      sections: demoTourMainlineSections('LaunchPublish', zh: zh, en: en),
    ),
  ];
}

List<ProductDemoTourStop> _utilityStops(AppLocalizations zh, AppLocalizations en) {
  final projectId = ProductDemoTour.kDemoProjectNumericId;
  return <ProductDemoTourStop>[
    ProductDemoTourStop(
      location: '/projects/$projectId/review-pack',
      titleZh: zh.demoTourUtilityReviewPackTitle,
      titleEn: en.demoTourUtilityReviewPackTitle,
      shortLabelZh: zh.demoTourUtilityReviewPackShortLabel,
      shortLabelEn: en.demoTourUtilityReviewPackShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellContent,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 4),
      isOptionalUtility: true,
      sections: ProductDemoTourGuideSections(
        goalZh: zh.demoTourUtilityReviewPackGoal,
        goalEn: en.demoTourUtilityReviewPackGoal,
        bulletsZh: <String>[
          zh.demoTourUtilityReviewPackBulletThumbnails,
          zh.demoTourUtilityReviewPackBulletExpand,
        ],
        bulletsEn: <String>[
          en.demoTourUtilityReviewPackBulletThumbnails,
          en.demoTourUtilityReviewPackBulletExpand,
        ],
        nextHintZh: zh.demoTourUtilityReviewPackNextHint,
        nextHintEn: en.demoTourUtilityReviewPackNextHint,
      ),
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.tasks),
      titleZh: zh.demoTourUtilityTasksTitle,
      titleEn: en.demoTourUtilityTasksTitle,
      shortLabelZh: zh.demoTourUtilityTasksShortLabel,
      shortLabelEn: en.demoTourUtilityTasksShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: zh.demoTourUtilityTasksGuide,
      guideEn: en.demoTourUtilityTasksGuide,
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.quality),
      titleZh: zh.demoTourUtilityQualityTitle,
      titleEn: en.demoTourUtilityQualityTitle,
      shortLabelZh: zh.demoTourUtilityQualityShortLabel,
      shortLabelEn: en.demoTourUtilityQualityShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: zh.demoTourUtilityQualityGuide,
      guideEn: en.demoTourUtilityQualityGuide,
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.notifications),
      titleZh: zh.demoTourUtilityNotificationsTitle,
      titleEn: en.demoTourUtilityNotificationsTitle,
      shortLabelZh: zh.demoTourUtilityNotificationsShortLabel,
      shortLabelEn: en.demoTourUtilityNotificationsShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellAppBar,
      coachStyle: ProductDemoCoachStyle.calloutAbove,
      guideZh: zh.demoTourUtilityNotificationsGuide,
      guideEn: en.demoTourUtilityNotificationsGuide,
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.productionWorkspace),
      titleZh: zh.demoTourUtilityProductionTitle,
      titleEn: en.demoTourUtilityProductionTitle,
      shortLabelZh: zh.demoTourUtilityProductionShortLabel,
      shortLabelEn: en.demoTourUtilityProductionShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: zh.demoTourUtilityProductionGuide,
      guideEn: en.demoTourUtilityProductionGuide,
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.scriptWorkspace),
      titleZh: zh.demoTourUtilityScriptTitle,
      titleEn: en.demoTourUtilityScriptTitle,
      shortLabelZh: zh.demoTourUtilityScriptShortLabel,
      shortLabelEn: en.demoTourUtilityScriptShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellPipeline,
      coachStyle: ProductDemoCoachStyle.calloutBeside,
      guideZh: zh.demoTourUtilityScriptGuide,
      guideEn: en.demoTourUtilityScriptGuide,
      isOptionalUtility: true,
    ),
    ProductDemoTourStop(
      location: studioUriForUtilityPane(ProductWorkspacePane.helpHub),
      titleZh: zh.demoTourUtilityHelpTitle,
      titleEn: en.demoTourUtilityHelpTitle,
      shortLabelZh: zh.demoTourUtilityHelpShortLabel,
      shortLabelEn: en.demoTourUtilityHelpShortLabel,
      anchorId: ProductDemoTourAnchorIds.shellAppBar,
      coachStyle: ProductDemoCoachStyle.floatingCard,
      guideZh: '',
      guideEn: '',
      dwell: const Duration(seconds: 3),
      isOptionalUtility: true,
      sections: ProductDemoTourGuideSections(
        goalZh: zh.demoTourUtilityHelpGoal,
        goalEn: en.demoTourUtilityHelpGoal,
        bulletsZh: <String>[
          zh.demoTourUtilityHelpBulletSampleLists,
          zh.demoTourUtilityHelpBulletAfterMainline,
        ],
        bulletsEn: <String>[
          en.demoTourUtilityHelpBulletSampleLists,
          en.demoTourUtilityHelpBulletAfterMainline,
        ],
      ),
    ),
  ];
}
