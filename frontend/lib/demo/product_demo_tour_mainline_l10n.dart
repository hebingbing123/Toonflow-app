// Demo tour mainline copy — keys in app_en.arb / app_zh.arb.
import '../l10n/app_localizations.dart';
import 'product_demo_tour.dart';

/// Rich guide sections for a mainline or launch beat (dual zh/en from arb).
ProductDemoTourGuideSections demoTourMainlineSections(
  String beatId, {
  required AppLocalizations zh,
  required AppLocalizations en,
}) {
  switch (beatId) {
    case 'Script1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourScript1Position,
        positionEn: en.demoTourScript1Position,
        goalZh: zh.demoTourScript1Goal,
        goalEn: en.demoTourScript1Goal,
        bulletsZh: <String>[zh.demoTourScript1Bullet1, zh.demoTourScript1Bullet2, zh.demoTourScript1Bullet3],
        bulletsEn: <String>[en.demoTourScript1Bullet1, en.demoTourScript1Bullet2, en.demoTourScript1Bullet3],
        demoNoteZh: zh.demoTourScript1DemoNote,
        demoNoteEn: en.demoTourScript1DemoNote,
        nextHintZh: zh.demoTourScript1NextHint,
        nextHintEn: en.demoTourScript1NextHint,
      );
    case 'Script2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourScript2Goal,
        goalEn: en.demoTourScript2Goal,
        bulletsZh: <String>[zh.demoTourScript2Bullet1, zh.demoTourScript2Bullet2, zh.demoTourScript2Bullet3],
        bulletsEn: <String>[en.demoTourScript2Bullet1, en.demoTourScript2Bullet2, en.demoTourScript2Bullet3],
        demoNoteZh: zh.demoTourScript2DemoNote,
        demoNoteEn: en.demoTourScript2DemoNote,
        nextHintZh: zh.demoTourScript2NextHint,
        nextHintEn: en.demoTourScript2NextHint,
      );
    case 'Art1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourArt1Position,
        positionEn: en.demoTourArt1Position,
        goalZh: zh.demoTourArt1Goal,
        goalEn: en.demoTourArt1Goal,
        bulletsZh: <String>[zh.demoTourArt1Bullet1, zh.demoTourArt1Bullet2, zh.demoTourArt1Bullet3],
        bulletsEn: <String>[en.demoTourArt1Bullet1, en.demoTourArt1Bullet2, en.demoTourArt1Bullet3],
        demoNoteZh: zh.demoTourArt1DemoNote,
        demoNoteEn: en.demoTourArt1DemoNote,
        nextHintZh: zh.demoTourArt1NextHint,
        nextHintEn: en.demoTourArt1NextHint,
      );
    case 'Art2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourArt2Goal,
        goalEn: en.demoTourArt2Goal,
        bulletsZh: <String>[zh.demoTourArt2Bullet1, zh.demoTourArt2Bullet2, zh.demoTourArt2Bullet3],
        bulletsEn: <String>[en.demoTourArt2Bullet1, en.demoTourArt2Bullet2, en.demoTourArt2Bullet3],
        nextHintZh: zh.demoTourArt2NextHint,
        nextHintEn: en.demoTourArt2NextHint,
      );
    case 'Assets1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourAssets1Position,
        positionEn: en.demoTourAssets1Position,
        goalZh: zh.demoTourAssets1Goal,
        goalEn: en.demoTourAssets1Goal,
        bulletsZh: <String>[zh.demoTourAssets1Bullet1, zh.demoTourAssets1Bullet2, zh.demoTourAssets1Bullet3],
        bulletsEn: <String>[en.demoTourAssets1Bullet1, en.demoTourAssets1Bullet2, en.demoTourAssets1Bullet3],
        demoNoteZh: zh.demoTourAssets1DemoNote,
        demoNoteEn: en.demoTourAssets1DemoNote,
        nextHintZh: zh.demoTourAssets1NextHint,
        nextHintEn: en.demoTourAssets1NextHint,
      );
    case 'Assets2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourAssets2Goal,
        goalEn: en.demoTourAssets2Goal,
        bulletsZh: <String>[zh.demoTourAssets2Bullet1, zh.demoTourAssets2Bullet2, zh.demoTourAssets2Bullet3],
        bulletsEn: <String>[en.demoTourAssets2Bullet1, en.demoTourAssets2Bullet2, en.demoTourAssets2Bullet3],
        nextHintZh: zh.demoTourAssets2NextHint,
        nextHintEn: en.demoTourAssets2NextHint,
      );
    case 'Storyboard1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourStoryboard1Position,
        positionEn: en.demoTourStoryboard1Position,
        goalZh: zh.demoTourStoryboard1Goal,
        goalEn: en.demoTourStoryboard1Goal,
        bulletsZh: <String>[zh.demoTourStoryboard1Bullet1, zh.demoTourStoryboard1Bullet2],
        bulletsEn: <String>[en.demoTourStoryboard1Bullet1, en.demoTourStoryboard1Bullet2],
        demoNoteZh: zh.demoTourStoryboard1DemoNote,
        demoNoteEn: en.demoTourStoryboard1DemoNote,
        nextHintZh: zh.demoTourStoryboard1NextHint,
        nextHintEn: en.demoTourStoryboard1NextHint,
      );
    case 'Storyboard2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourStoryboard2Goal,
        goalEn: en.demoTourStoryboard2Goal,
        bulletsZh: <String>[zh.demoTourStoryboard2Bullet1, zh.demoTourStoryboard2Bullet2, zh.demoTourStoryboard2Bullet3],
        bulletsEn: <String>[en.demoTourStoryboard2Bullet1, en.demoTourStoryboard2Bullet2, en.demoTourStoryboard2Bullet3],
        nextHintZh: zh.demoTourStoryboard2NextHint,
        nextHintEn: en.demoTourStoryboard2NextHint,
      );
    case 'Storyboard3':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourStoryboard3Goal,
        goalEn: en.demoTourStoryboard3Goal,
        bulletsZh: <String>[zh.demoTourStoryboard3Bullet1, zh.demoTourStoryboard3Bullet2, zh.demoTourStoryboard3Bullet3],
        bulletsEn: <String>[en.demoTourStoryboard3Bullet1, en.demoTourStoryboard3Bullet2, en.demoTourStoryboard3Bullet3],
        demoNoteZh: zh.demoTourStoryboard3DemoNote,
        demoNoteEn: en.demoTourStoryboard3DemoNote,
        nextHintZh: zh.demoTourStoryboard3NextHint,
        nextHintEn: en.demoTourStoryboard3NextHint,
      );
    case 'Storyboard4':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourStoryboard4Goal,
        goalEn: en.demoTourStoryboard4Goal,
        bulletsZh: <String>[zh.demoTourStoryboard4Bullet1, zh.demoTourStoryboard4Bullet2, zh.demoTourStoryboard4Bullet3],
        bulletsEn: <String>[en.demoTourStoryboard4Bullet1, en.demoTourStoryboard4Bullet2, en.demoTourStoryboard4Bullet3],
        nextHintZh: zh.demoTourStoryboard4NextHint,
        nextHintEn: en.demoTourStoryboard4NextHint,
      );
    case 'Video1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourVideo1Position,
        positionEn: en.demoTourVideo1Position,
        goalZh: zh.demoTourVideo1Goal,
        goalEn: en.demoTourVideo1Goal,
        bulletsZh: <String>[zh.demoTourVideo1Bullet1, zh.demoTourVideo1Bullet2, zh.demoTourVideo1Bullet3],
        bulletsEn: <String>[en.demoTourVideo1Bullet1, en.demoTourVideo1Bullet2, en.demoTourVideo1Bullet3],
        nextHintZh: zh.demoTourVideo1NextHint,
        nextHintEn: en.demoTourVideo1NextHint,
      );
    case 'Video2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourVideo2Goal,
        goalEn: en.demoTourVideo2Goal,
        bulletsZh: <String>[zh.demoTourVideo2Bullet1, zh.demoTourVideo2Bullet2, zh.demoTourVideo2Bullet3],
        bulletsEn: <String>[en.demoTourVideo2Bullet1, en.demoTourVideo2Bullet2, en.demoTourVideo2Bullet3],
        nextHintZh: zh.demoTourVideo2NextHint,
        nextHintEn: en.demoTourVideo2NextHint,
      );
    case 'Deliver1':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourDeliver1Position,
        positionEn: en.demoTourDeliver1Position,
        goalZh: zh.demoTourDeliver1Goal,
        goalEn: en.demoTourDeliver1Goal,
        bulletsZh: <String>[zh.demoTourDeliver1Bullet1, zh.demoTourDeliver1Bullet2, zh.demoTourDeliver1Bullet3],
        bulletsEn: <String>[en.demoTourDeliver1Bullet1, en.demoTourDeliver1Bullet2, en.demoTourDeliver1Bullet3],
        demoNoteZh: zh.demoTourDeliver1DemoNote,
        demoNoteEn: en.demoTourDeliver1DemoNote,
        nextHintZh: zh.demoTourDeliver1NextHint,
        nextHintEn: en.demoTourDeliver1NextHint,
      );
    case 'Deliver2':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourDeliver2Goal,
        goalEn: en.demoTourDeliver2Goal,
        bulletsZh: <String>[zh.demoTourDeliver2Bullet1, zh.demoTourDeliver2Bullet2, zh.demoTourDeliver2Bullet3],
        bulletsEn: <String>[en.demoTourDeliver2Bullet1, en.demoTourDeliver2Bullet2, en.demoTourDeliver2Bullet3],
        nextHintZh: zh.demoTourDeliver2NextHint,
        nextHintEn: en.demoTourDeliver2NextHint,
      );
    case 'LaunchReadiness':
      return ProductDemoTourGuideSections(
        positionZh: zh.demoTourLaunchReadinessPosition,
        positionEn: en.demoTourLaunchReadinessPosition,
        goalZh: zh.demoTourLaunchReadinessGoal,
        goalEn: en.demoTourLaunchReadinessGoal,
        bulletsZh: <String>[zh.demoTourLaunchReadinessBullet1, zh.demoTourLaunchReadinessBullet2, zh.demoTourLaunchReadinessBullet3],
        bulletsEn: <String>[en.demoTourLaunchReadinessBullet1, en.demoTourLaunchReadinessBullet2, en.demoTourLaunchReadinessBullet3],
        demoNoteZh: zh.demoTourLaunchReadinessDemoNote,
        demoNoteEn: en.demoTourLaunchReadinessDemoNote,
        nextHintZh: zh.demoTourLaunchReadinessNextHint,
        nextHintEn: en.demoTourLaunchReadinessNextHint,
      );
    case 'LaunchPublish':
      return ProductDemoTourGuideSections(
        goalZh: zh.demoTourLaunchPublishGoal,
        goalEn: en.demoTourLaunchPublishGoal,
        bulletsZh: <String>[zh.demoTourLaunchPublishBullet1, zh.demoTourLaunchPublishBullet2, zh.demoTourLaunchPublishBullet3],
        bulletsEn: <String>[en.demoTourLaunchPublishBullet1, en.demoTourLaunchPublishBullet2, en.demoTourLaunchPublishBullet3],
        nextHintZh: zh.demoTourLaunchPublishNextHint,
        nextHintEn: en.demoTourLaunchPublishNextHint,
      );
    default:
      throw ArgumentError.value(beatId, "beatId", "unknown demo tour beat");
  }
}

/// Beat title for mainline SOP stops (launch beats use existing title keys).
String demoTourMainlineTitle(String beatId, AppLocalizations l10n) {
  switch (beatId) {
    case 'Script1': return l10n.demoTourScript1Title;
    case 'Script2': return l10n.demoTourScript2Title;
    case 'Art1': return l10n.demoTourArt1Title;
    case 'Art2': return l10n.demoTourArt2Title;
    case 'Assets1': return l10n.demoTourAssets1Title;
    case 'Assets2': return l10n.demoTourAssets2Title;
    case 'Storyboard1': return l10n.demoTourStoryboard1Title;
    case 'Storyboard2': return l10n.demoTourStoryboard2Title;
    case 'Storyboard3': return l10n.demoTourStoryboard3Title;
    case 'Storyboard4': return l10n.demoTourStoryboard4Title;
    case 'Video1': return l10n.demoTourVideo1Title;
    case 'Video2': return l10n.demoTourVideo2Title;
    case 'Deliver1': return l10n.demoTourDeliver1Title;
    case 'Deliver2': return l10n.demoTourDeliver2Title;
    default:
      throw ArgumentError.value(beatId, "beatId", "unknown demo tour beat");
  }
}
