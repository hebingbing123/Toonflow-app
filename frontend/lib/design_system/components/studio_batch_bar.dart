import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../tokens.dart';

/// Floating batch action bar (Wave 0b).
class StudioBatchBar extends StatelessWidget {
  const StudioBatchBar({
    super.key,
    required this.selectedCount,
    required this.actions,
  });

  final int selectedCount;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (selectedCount <= 0) return const SizedBox.shrink();
    final tokens = StudioTokens.of(context);
    return Material(
      elevation: 0,
      color: tokens.bgElevated,
      borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
          border: Border.all(color: tokens.borderSubtle),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tokens.overlay.withValues(alpha: 0.08),
              blurRadius: 8,
              spreadRadius: -8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: StudioLayoutSpacing.inlineGap,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: StudioSpacing.sm,
            runSpacing: StudioSpacing.chromeActionGap,
            children: <Widget>[
              Text(
                AppLocalizations.of(
                  context,
                )!.studioBatchSelectedCount(selectedCount),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
