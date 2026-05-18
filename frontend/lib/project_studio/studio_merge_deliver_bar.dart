import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../l10n/app_localizations.dart';

/// Step ⑥ primary CTA: merge & preview (opens short-video assembly focus).
class StudioMergeDeliverBar extends StatelessWidget {
  const StudioMergeDeliverBar({
    super.key,
    required this.onMergeAndPreview,
    this.busy = false,
  });

  final VoidCallback? onMergeAndPreview;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StudioPrimaryButton(
        label: l10n.studioMergeAndPreview,
        icon: Icons.movie_filter_outlined,
        loading: busy,
        onPressed: busy ? null : onMergeAndPreview,
      ),
    );
  }
}
