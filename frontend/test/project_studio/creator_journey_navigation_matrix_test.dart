import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/project_studio/creator_journey_strip.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

/// Expected compact-bar [←]/[→] targets (single source of truth in tests).
void main() {
  group('creator journey compact bar matrix', () {
    test('prev step for every studio step', () {
      const expectations = <StudioStep, StudioStep?>{
        StudioStep.script: null,
        StudioStep.art: StudioStep.script,
        StudioStep.assets: StudioStep.art,
        StudioStep.storyboard: StudioStep.art,
        StudioStep.video: StudioStep.storyboard,
        StudioStep.deliver: StudioStep.video,
        StudioStep.quality: StudioStep.deliver,
      };
      for (final entry in expectations.entries) {
        expect(
          creatorJourneyCompactBarPrevStep(entry.key),
          entry.value,
          reason: 'prev from ${entry.key.slug}',
        );
      }
    });

    test('prev exit to projects only on script milestone', () {
      expect(creatorJourneyCompactBarPrevIsExitToProjects(StudioStep.script), isTrue);
      for (final step in StudioStep.values) {
        if (step == StudioStep.script) continue;
        expect(
          creatorJourneyCompactBarPrevIsExitToProjects(step),
          isFalse,
          reason: step.slug,
        );
      }
    });

    test('next step for every studio step', () {
      const expectations = <StudioStep, StudioStep?>{
        StudioStep.script: StudioStep.art,
        StudioStep.art: StudioStep.storyboard,
        StudioStep.assets: StudioStep.storyboard,
        StudioStep.storyboard: StudioStep.deliver,
        StudioStep.video: StudioStep.deliver,
        StudioStep.deliver: null,
        StudioStep.quality: null,
      };
      for (final entry in expectations.entries) {
        expect(
          creatorJourneyCompactBarNextStep(entry.key),
          entry.value,
          reason: 'next from ${entry.key.slug}',
        );
      }
    });

    test('review pack only after deliver milestone', () {
      for (final step in StudioStep.values) {
        final opens = creatorJourneyCompactBarNextOpensReviewPack(step);
        if (step == StudioStep.deliver || step == StudioStep.quality) {
          expect(opens, isTrue, reason: step.slug);
        } else {
          expect(opens, isFalse, reason: step.slug);
        }
      }
    });
  });

  group('creator journey compact bar chrome labels', () {
    test('deliver landing uses deliver short not review-pack tile name', () {
      final l10n = AppLocalizationsEn();
      expect(
        creatorJourneyCompactBarChromeLabel(l10n, StudioStep.deliver),
        l10n.studioStepDeliverShort,
      );
      expect(
        creatorJourneyCompactBarChromeLabel(l10n, StudioStep.quality),
        l10n.studioDeliverTabQuality,
      );
      expect(
        creatorJourneyCompactBarChromeLabel(l10n, StudioStep.deliver),
        isNot(l10n.studioCreatorJourneyReviewPack),
      );
    });
  });

  group('creator journey strip tiles', () {
    test('tile targets match UI labels', () {
      final l10n = AppLocalizationsEn();
      expect(
        creatorJourneyStripTargetForTile(0).kind,
        CreatorJourneyStripTileKind.exitProjects,
      );
      expect(
        creatorJourneyStripTargetForTile(1).step,
        StudioStep.script,
      );
      expect(
        creatorJourneyStripTargetForTile(2).step,
        StudioStep.art,
      );
      expect(
        creatorJourneyStripTargetForTile(3).step,
        StudioStep.storyboard,
      );
      expect(
        creatorJourneyStripTargetForTile(4).step,
        StudioStep.deliver,
      );
      expect(
        creatorJourneyStripLabelForTile(l10n, 4),
        l10n.studioStepDeliverShort,
      );
    });
  });
}
