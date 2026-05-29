import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/components/studio_dropdown_field.dart';
import '../design_system/ix/studio_scroll_behavior.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/studio_network_image.dart';
import '../design_system/studio_responsive_layout.dart';
import '../design_system/studio_typography.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_debounced_action.dart';
import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/components/studio_icon_button.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/components/studio_metric_switch.dart';
import '../design_system/components/studio_repaint_boundary.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../rust_api.dart';
import 'panels/assembly_input_panel.dart';
import 'publish_copy_editor.dart';
import 'publish_schedule_calendar.dart';
import 'components/preview_player.dart';
import 'short_video_aspect_ratio.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

part 'view_labels.dart';
part 'view_models.dart';
part 'view_shell_widgets.dart';
part 'view_space_view.dart';
part 'view_overview_panel.dart';
part 'view_production_panel.dart';
part 'view_production_assets_panel.dart';
part 'view_production_assembly_export_layout.dart';
part 'view_production_export_panel.dart';
part 'view_project_selector.dart';
part 'view_candidate_compare.dart';
part 'view_readiness_flow.dart';
part 'view_publish_drafts.dart';
part 'view_publish_calendar.dart';
part 'view_publish_jobs.dart';
part 'view_publish_audit.dart';

enum ShortVideoMode { animated, liveAction }

/// Panels visible when [ShortVideoSpaceSection] is embedded in Project Studio.
enum ShortVideoSpaceEmbedScope {
  /// Full short-video workspace (default pane).
  full,

  /// Assembly + export actions (Studio deliver「组装」tab).
  assembly,

  /// Publish drafts / calendar / jobs / audit (Studio deliver「发布」tab).
  publish,

  /// Quality overview + export gate (Studio deliver「质检」tab).
  quality,
}

/// Display order for publish platform chips (full matrix; ids match backend).
const List<String> kShortVideoPublishPlatformIdsInDisplayOrder = <String>[
  'douyin',
  'bilibili',
  'xiaohongshu',
  'weixin_channels',
  'kuaishou',
  'tiktok',
  'youtube_shorts',
  'instagram_reels',
  'facebook_reels',
];
