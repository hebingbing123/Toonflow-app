import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rust_api/settings/outbound_webhook_platform.dart';

/// Multi-select chips for platform outbound webhook event types.
class OutboundWebhookEventChips extends StatelessWidget {
  const OutboundWebhookEventChips({
    super.key,
    required this.selected,
    required this.onSelectionChanged,
    this.enabled = true,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onSelectionChanged;
  final bool enabled;

  void _toggle(String slug, bool select) {
    final next = Set<String>.from(selected);
    if (select) {
      next.add(slug);
    } else {
      next.remove(slug);
    }
    if (next.isEmpty) {
      next.addAll(kOutboundWebhookPlatformEventTypes);
    }
    onSelectionChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final slug in kOutboundWebhookPlatformEventTypes)
          FilterChip(
            label: Text(outboundWebhookPlatformEventLabel(l10n, slug)),
            selected: selected.contains(slug),
            onSelected: enabled
                ? (v) {
                    _toggle(slug, v);
                  }
                : null,
          ),
      ],
    );
  }
}
