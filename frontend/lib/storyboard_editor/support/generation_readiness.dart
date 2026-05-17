import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/short_video_generation_blocked.dart';
import 'package:openflow_app/rust_api/project/overview_api.dart';
import 'package:openflow_app/rust_api/project/overview_models.dart';

/// Throws [FormatException] when the current storyboard is not ready for generation.
Future<void> assertStoryboardReadyForVideoGeneration({
  required String accessToken,
  required String projectUuid,
  required int storyboardNumericId,
  required AppLocalizations l10n,
}) async {
  final readiness = await fetchProjectShortVideoReadinessByProjectId(
    accessToken,
    projectUuid,
  );
  StoryboardShortVideoReadiness? shot;
  for (final row in readiness.storyboards) {
    if (row.storyboardNumericId == storyboardNumericId) {
      shot = row;
      break;
    }
  }
  if (shot == null || shot.readyForGeneration) {
    return;
  }
  throw FormatException(
    formatStoryboardGenerationBlockedMessage(
      l10n,
      storyboardNumericId: shot.storyboardNumericId,
      blockingReasons: shot.blockingReasons,
    ),
  );
}
