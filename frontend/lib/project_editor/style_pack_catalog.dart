import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Bundled art or story style pack option for project editors and Studio.
class StylePackOption {
  const StylePackOption({
    required this.path,
    required this.name,
    required this.description,
    required this.tag,
    this.previewImagePaths = const <String>[],
  });

  final String path;
  final String name;
  final String description;
  final String tag;
  final List<String> previewImagePaths;
}

class StylePackCatalog {
  const StylePackCatalog({required this.artPacks, required this.storyPacks});

  final List<StylePackOption> artPacks;
  final List<StylePackOption> storyPacks;
}

/// Stored paths use `art_skills/...`; catalog keys are often bare style folder names.
String normalizeArtStylePackPath(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('art_skills/')) {
    return trimmed;
  }
  return 'art_skills/$trimmed';
}

String normalizeStoryStylePackPath(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  if (trimmed.startsWith('story_skills/')) {
    return trimmed;
  }
  return 'story_skills/$trimmed';
}

bool artStylePackPathsMatch(String? a, String? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return normalizeArtStylePackPath(a) == normalizeArtStylePackPath(b);
}

bool storyStylePackPathsMatch(String? a, String? b) {
  if (a == null || b == null) {
    return a == b;
  }
  return normalizeStoryStylePackPath(a) == normalizeStoryStylePackPath(b);
}

StylePackOption? findArtStylePackOption(
  List<StylePackOption> options,
  String? selectedPath,
) {
  if (selectedPath == null || selectedPath.isEmpty) {
    return null;
  }
  final normalized = normalizeArtStylePackPath(selectedPath);
  for (final option in options) {
    if (normalizeArtStylePackPath(option.path) == normalized) {
      return option;
    }
  }
  return null;
}

StylePackOption? findStoryStylePackOption(
  List<StylePackOption> options,
  String? selectedPath,
) {
  if (selectedPath == null || selectedPath.isEmpty) {
    return null;
  }
  final normalized = normalizeStoryStylePackPath(selectedPath);
  for (final option in options) {
    if (normalizeStoryStylePackPath(option.path) == normalized) {
      return option;
    }
  }
  return null;
}

/// Builds picker options from visual-manual + director-manual API payloads.
StylePackCatalog buildStylePackCatalogFromResponses({
  required VisualManualResponseV1 visualManual,
  required DirectorManualListResponse directorManual,
  required AppLocalizations l10n,
}) {
  final artPacks =
      visualManual.styles
          .map(
            (style) => StylePackOption(
              path: normalizeArtStylePackPath(style.stylePath),
              name: style.name,
              description: _stylePackDescriptionFromSlots(
                l10n,
                style.data.map((slot) => slot.data),
              ),
              tag: l10n.projectEditorStylePackTagArt,
              previewImagePaths: style.image,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  final storyPacks =
      directorManual.data
          .map(
            (style) => StylePackOption(
              path: normalizeStoryStylePackPath(style.directorManual),
              name: style.name,
              description: _stylePackDescriptionFromSlots(
                l10n,
                style.data.map((slot) => slot.data),
              ),
              tag: l10n.projectEditorStylePackTagStory,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  return StylePackCatalog(artPacks: artPacks, storyPacks: storyPacks);
}

Future<StylePackCatalog> loadProjectStylePackCatalog(
  String accessToken,
  AppLocalizations l10n,
) async {
  final visualManual = await fetchVisualManualV1(accessToken);
  final directorManual = await postProjectQueryDirectorManual(accessToken);
  return buildStylePackCatalogFromResponses(
    visualManual: visualManual,
    directorManual: directorManual,
    l10n: l10n,
  );
}

String _stylePackDescriptionFromSlots(
  AppLocalizations l10n,
  Iterable<String> slots,
) {
  for (final raw in slots) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('|') &&
              !line.startsWith('```') &&
              !line.startsWith('- ') &&
              !line.startsWith('* '),
        );
    for (final line in lines) {
      return line.length <= 96 ? line : '${line.substring(0, 96)}...';
    }
  }
  return l10n.projectEditorStylePackNoDescriptionFallback;
}
