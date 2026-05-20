import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../design_system/tokens.dart';
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
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final summary = Text(
              l10n.studioDeliverTabAssembly,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            );
            final action = StudioPrimaryButton(
              label: l10n.studioMergeAndPreview,
              icon: Icons.movie_filter_outlined,
              loading: busy,
              onPressed: busy ? null : onMergeAndPreview,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[summary, const SizedBox(height: 10), action],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: summary),
                const SizedBox(width: 12),
                Flexible(child: action),
              ],
            );
          },
        ),
      ),
    );
  }
}
