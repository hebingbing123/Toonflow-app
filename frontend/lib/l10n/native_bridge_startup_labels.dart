import 'app_localizations.dart';
import '../native_bridge/native_bridge_bootstrap.dart';

/// Localized user-facing text for [NativeBridgeStartupSnapshot].
String nativeBridgeStartupMessage(
  AppLocalizations l10n,
  NativeBridgeStartupSnapshot snapshot,
) {
  switch (snapshot.state) {
    case NativeBridgeStartupState.idle:
      return l10n.nativeBridgeMessageNotStarted;
    case NativeBridgeStartupState.skipped:
      return l10n.nativeBridgeMessageWebSkipped;
    case NativeBridgeStartupState.ready:
      final path = snapshot.libraryPath?.trim();
      if (path != null && path.isNotEmpty) {
        return l10n.nativeBridgeMessageLoadedFrom(path);
      }
      return l10n.nativeBridgeMessageReady;
    case NativeBridgeStartupState.failed:
      return l10n.nativeBridgeMessageInitFailed;
  }
}
