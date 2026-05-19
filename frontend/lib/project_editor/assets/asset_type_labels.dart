import '../../l10n/app_localizations.dart';

String projectEditorAssetTypeLabel(AppLocalizations l10n, String assetType) {
  switch (assetType.trim().toLowerCase()) {
    case '':
      return l10n.projectEditorAssetGenWorkbenchAssetTypeAll;
    case 'role':
      return l10n.projectEditorAssetTypeRole;
    case 'clip':
      return l10n.projectEditorAssetTypeClip;
    case 'props':
      return l10n.projectEditorAssetTypeProps;
    case 'scene':
      return l10n.projectEditorAssetTypeScene;
    case 'character':
      return l10n.projectEditorAssetTypeCharacter;
    default:
      return assetType;
  }
}
