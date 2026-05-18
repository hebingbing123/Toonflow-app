import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/assets/workbench/dialog_support.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('project assets workbench session honors preferred focus', () {
    final session = ProjectAssetsWorkbenchSession(
      visibleAssets: const <AssetRow>[
        AssetRow(id: 'asset-7', numericId: 7, name: 'Lead', assetType: 'role'),
        AssetRow(id: 'asset-9', numericId: 9, name: 'Sword', assetType: 'prop'),
      ],
      scriptList: const <ScriptBrief>[
        ScriptBrief(numericId: 11, name: 'Act 1'),
        ScriptBrief(numericId: 12, name: 'Act 2'),
      ],
      initialStatusLine: 'Loaded assets',
      targetKind: ProjectStudioAssetEditorTargetKind.anchorCharacters,
      focusNotice: 'Review pending role anchors.',
      preferredAssetNumericId: 9,
      preferredScriptNumericId: 12,
    );

    expect(session.selectedAssetNumericId, 9);
    expect(session.selectedScriptNumericId, 12);
    expect(
      session.targetKind,
      ProjectStudioAssetEditorTargetKind.anchorCharacters,
    );
    expect(session.focusNotice, 'Review pending role anchors.');
    expect(session.statusLine, 'Loaded assets');
  });

  test('project assets workbench session falls back gracefully', () {
    final session = ProjectAssetsWorkbenchSession(
      visibleAssets: const <AssetRow>[
        AssetRow(id: 'asset-7', numericId: 7, name: 'Lead', assetType: 'role'),
      ],
      scriptList: const <ScriptBrief>[
        ScriptBrief(numericId: 11, name: 'Act 1'),
      ],
      initialStatusLine: 'Loaded assets',
      preferredAssetNumericId: 999,
      preferredScriptNumericId: 999,
    );

    expect(session.selectedAssetNumericId, 7);
    expect(session.selectedScriptNumericId, 11);
  });
}
