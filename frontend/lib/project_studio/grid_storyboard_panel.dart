import 'package:flutter/material.dart';

import '../design_system/components/studio_primary_button.dart';
import '../l10n/app_localizations.dart';

/// Grid generate → split → assign UI shell (Wave 8 frontend; backend job TBD).
class GridStoryboardPanel extends StatelessWidget {
  const GridStoryboardPanel({super.key, required this.onGenerateGrid});

  final VoidCallback onGenerateGrid;

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
        StudioPrimaryButton(
          label: l10n.studioGridStoryboardCta,
          icon: Icons.grid_on_outlined,
          onPressed: onGenerateGrid,
        ),
      ],
    );
  }
}
