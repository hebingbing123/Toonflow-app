import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../design_system/components/studio_icon_button.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/design_system/studio_scheduler.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../short_video_aspect_ratio.dart';

part 'preview_player_models.dart';
part 'preview_player_widget.dart';
part 'preview_player_dialog.dart';
