import 'package:flutter/material.dart';
import '../../design_system/components/studio_chip.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';

class ValueTierBadge extends StatelessWidget {
  const ValueTierBadge({
    super.key,
    required this.valueTier,
    required this.sampleSufficient,
    this.showSameTierCheaper = false,
  });

  final String? valueTier;
  final bool sampleSufficient;
  final bool showSameTierCheaper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!sampleSufficient) {
      return StudioChip(
        label: Text(l10n.studioValueTierSampleLow),
      );
    }
    if (showSameTierCheaper) {
      return StudioChip(
        label: Text(l10n.studioValueTierSameTierCheaper),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      );
    }
    final label = valueTierLabel(l10n, valueTier);
    if (label.isEmpty) return const SizedBox.shrink();
    return StudioChip(
      label: Text(label),
    );
  }
}
