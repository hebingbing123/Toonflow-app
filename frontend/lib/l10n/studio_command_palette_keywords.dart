import 'app_localizations.dart';

/// Parses comma/space-separated command-palette aliases from arb.
List<String> studioCommandPaletteKeywordsFromAliases(String aliases) {
  return aliases
      .split(RegExp(r'[,，\s]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
}

List<String> studioCommandPaletteKeywordsProjects(AppLocalizations l10n) =>
    studioCommandPaletteKeywordsFromAliases(l10n.studioCommandPaletteKeywordsProjects);

List<String> studioCommandPaletteKeywordsNotifications(AppLocalizations l10n) =>
    studioCommandPaletteKeywordsFromAliases(
      l10n.studioCommandPaletteKeywordsNotifications,
    );

List<String> studioCommandPaletteKeywordsSettings(AppLocalizations l10n) =>
    studioCommandPaletteKeywordsFromAliases(l10n.studioCommandPaletteKeywordsSettings);

List<String> studioCommandPaletteKeywordsHelp(AppLocalizations l10n) =>
    studioCommandPaletteKeywordsFromAliases(l10n.studioCommandPaletteKeywordsHelp);
