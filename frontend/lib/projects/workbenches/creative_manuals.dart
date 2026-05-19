import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

part 'creative_manuals_row.dart';
part 'creative_manuals_state.dart';
part 'creative_manuals_view.dart';
part 'creative_manuals_helpers.dart';
part 'creative_manuals_controllers.dart';

enum _CreativeManualKind { director, visual }

class ProjectsCreativeManualsWorkbenchDialog extends StatefulWidget {
  const ProjectsCreativeManualsWorkbenchDialog({
    super.key,
    required this.accessToken,
  });

  final String accessToken;

  @override
  State<ProjectsCreativeManualsWorkbenchDialog> createState() =>
      _ProjectsCreativeManualsWorkbenchDialogState();
}
