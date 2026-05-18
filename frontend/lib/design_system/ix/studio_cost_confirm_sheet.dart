import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import '../components/studio_primary_button.dart';

/// Bottom sheet before enqueueing a paid generation job.
Future<bool> showStudioCostConfirmSheet({
  required BuildContext context,
  required BillingEstimateResponse estimate,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final cny = formatCnyFromCents(estimate.cnyCents);
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.studioCostConfirmTitle,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.studioCostConfirmBody(
                estimate.credits,
                cny,
                l10n.studioPlanUsageEstimateDisclaimer,
              ),
            ),
            const SizedBox(height: 20),
            StudioPrimaryButton(
              label: l10n.studioCostConfirmProceed,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.studioCostConfirmCancel),
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}
