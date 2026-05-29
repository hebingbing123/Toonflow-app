import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

import '../design_system/ix/studio_keyboard_shortcuts_panel.dart';
import '../l10n/app_localizations.dart';

/// Platform-aware label for ⌘K / Ctrl+K.
String studioProductCommandPaletteKeys(AppLocalizations l10n) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.iOS:
      return l10n.studioCommandPaletteShortcutMac;
    default:
      return l10n.studioCommandPaletteShortcutWindows;
  }
}

/// Product-shell shortcuts shown in Help Hub (24.3).
List<StudioKeyboardShortcutEntry> buildStudioProductKeyboardShortcuts(
  AppLocalizations l10n,
) {
  return <StudioKeyboardShortcutEntry>[
    StudioKeyboardShortcutEntry(
      description: l10n.studioShortcutCommandPaletteDescription,
      keys: studioProductCommandPaletteKeys(l10n),
    ),
    StudioKeyboardShortcutEntry(
      description: l10n.studioShortcutFormSubmitDescription,
      keys: l10n.studioShortcutFormSubmitKeys,
    ),
  ];
}
