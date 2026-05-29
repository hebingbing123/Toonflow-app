import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_icon_button.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../../rust_api.dart';
import '../dialogs/confirmation_dialogs.dart';
import 'version_comparison.dart';
import 'package:openflow_app/design_system/components/studio_card.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_entrance_motion.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// 成片版本数据模型
part 'version_manager_models.dart';
part 'version_manager_state.dart';
part 'version_manager_actions.dart';

class VersionManager extends StatefulWidget {
  const VersionManager({
    required this.versions,
    required this.currentVersionId,
    required this.drafts,
    required this.onCreateVersion,
    required this.onSwitchVersion,
    required this.onDeleteVersion,
    required this.onSaveDraft,
    required this.onRestoreDraft,
    required this.onDeleteDraft,
    super.key,
  });

  /// 版本列表
  final List<AssemblyVersion> versions;

  /// 当前版本 ID
  final String currentVersionId;

  /// 草稿列表
  final List<AssemblyDraft> drafts;

  /// 创建新版本回调
  final Future<void> Function(String name) onCreateVersion;

  /// 切换版本回调
  final Future<void> Function(String versionId) onSwitchVersion;

  /// 删除版本回调
  final Future<void> Function(String versionId) onDeleteVersion;

  /// 保存草稿回调
  final Future<void> Function(String name) onSaveDraft;

  /// 恢复草稿回调
  final Future<void> Function(String draftId) onRestoreDraft;

  /// 删除草稿回调
  final Future<void> Function(String draftId) onDeleteDraft;

  @override
  State<VersionManager> createState() => _VersionManagerState();
}

