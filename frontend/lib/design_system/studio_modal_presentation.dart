import 'package:flutter/foundation.dart';

/// How [showStudioBottomSheet] presents on the current platform.
enum StudioModalPresentation {
  /// Native / Cupertino bottom sheet (short menus, drag handle).
  bottomSheet,

  /// Web tall panel as centered [Dialog] with full corner radius (not sheet chrome).
  webTallDialog,
}

/// Resolves modal presentation for [showStudioBottomSheet].
StudioModalPresentation studioModalPresentationFor({
  required bool isScrollControlled,
}) {
  if (!kIsWeb || !isScrollControlled) {
    return StudioModalPresentation.bottomSheet;
  }
  return StudioModalPresentation.webTallDialog;
}

