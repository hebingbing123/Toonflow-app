import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../l10n/app_localizations.dart';

/// Grid generate → split → assign (production API).
class GridStoryboardPanel extends StatelessWidget {
  const GridStoryboardPanel({
    super.key,
    required this.onGenerateGrid,
    this.busy = false,
  });

  final VoidCallback? onGenerateGrid;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            l10n.studioGridStoryboardHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        StudioPrimaryButton(
          label: l10n.studioGridStoryboardCta,
          icon: Icons.grid_on_outlined,
          onPressed: busy ? null : onGenerateGrid,
        ),
      ],
    );
  }
}
