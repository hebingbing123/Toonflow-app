import '../l10n/app_localizations.dart';
import '../rust_api.dart';

/// Stable keys for creator-journey starter templates (see backend `build_cockpit`).
const List<String> kCreatorStarterTemplateKeys = <String>[
  'starter_creator_plot',
  'starter_creator_shot_rhythm',
];

List<ProjectHomeStarterTemplate> creatorStarterTemplatesForScript(
  List<ProjectHomeStarterTemplate> all,
) {
  final byKey = <String, ProjectHomeStarterTemplate>{
    for (final starter in all) starter.key: starter,
  };
  return kCreatorStarterTemplateKeys
      .map((String key) => byKey[key])
      .whereType<ProjectHomeStarterTemplate>()
      .toList(growable: false);
}

typedef CreatorStarterCopy = ({String title, String detail, String ctaLabel});

CreatorStarterCopy creatorStarterLocalizedCopy(
  AppLocalizations l10n,
  ProjectHomeStarterTemplate starter,
) {
  switch (starter.key) {
    case 'starter_creator_plot':
      return (
        title: l10n.studioCreatorStarterPlotTitle,
        detail: l10n.studioCreatorStarterPlotDetail,
        ctaLabel: l10n.studioCreatorStarterPlotCta,
      );
    case 'starter_creator_shot_rhythm':
      return (
        title: l10n.studioCreatorStarterRhythmTitle,
        detail: l10n.studioCreatorStarterRhythmDetail,
        ctaLabel: l10n.studioCreatorStarterRhythmCta,
      );
    default:
      return (
        title: starter.title,
        detail: starter.detail,
        ctaLabel: starter.ctaLabel,
      );
  }
}
