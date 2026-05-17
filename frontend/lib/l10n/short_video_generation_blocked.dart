import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/short_video_readiness_localized.dart';
import 'package:openflow_app/rust_api/core.dart';

/// User-visible summary when generation is blocked by readiness (API or local check).
String formatStoryboardGenerationBlockedMessage(
  AppLocalizations l10n, {
  required int storyboardNumericId,
  required List<String> blockingReasons,
}) {
  if (blockingReasons.isEmpty) {
    return l10n.shortVideoReadinessStoryboardDetailPrefix(storyboardNumericId);
  }
  final labels = blockingReasons
      .map((c) => labelShortVideoBlockingReasonLocalized(l10n, c))
      .join('、');
  return l10n.shortVideoReadinessBlockedShotDetail(
    l10n.shortVideoReadinessStoryboardDetailPrefix(storyboardNumericId),
    labels,
  );
}

/// Prefer structured **`details.blockedStoryboards`** from a 409 body; falls back to [message].
String? formatGenerationBlockedFromRustApiException(
  AppLocalizations l10n,
  RustApiException error,
) {
  final details = RustApiErrorDetails.tryParse(error.message);
  final blocked = details?.blockedStoryboards ?? const [];
  if (blocked.isEmpty) {
    return details?.message;
  }
  return blocked
      .map(
        (b) => formatStoryboardGenerationBlockedMessage(
          l10n,
          storyboardNumericId: b.storyboardNumericId,
          blockingReasons: b.blockingReasons,
        ),
      )
      .join('\n');
}
