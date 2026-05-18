import 'package:flutter/material.dart';

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
      return Chip(
        label: Text(l10n.studioValueTierSampleLow),
        visualDensity: VisualDensity.compact,
      );
    }
    if (showSameTierCheaper) {
      return Chip(
        label: Text(l10n.studioValueTierSameTierCheaper),
        visualDensity: VisualDensity.compact,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      );
    }
    final label = valueTierLabel(l10n, valueTier);
    if (label.isEmpty) return const SizedBox.shrink();
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
