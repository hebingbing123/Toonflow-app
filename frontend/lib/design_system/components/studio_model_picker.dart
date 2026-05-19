import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/billing_l10n_helpers.dart';
import '../../rust_api.dart';
import 'studio_dropdown_field.dart';

/// Dropdown model picker backed by `GET /api/v1/models?include_pricing=true`.
class StudioModelPicker extends StatelessWidget {
  const StudioModelPicker({
    super.key,
    required this.models,
    required this.selectedModelId,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ModelListEntry> models;
  final String? selectedModelId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final effectiveId = selectedModelId ??
        (models.isNotEmpty ? models.first.effectiveModelId : null);

    return StudioDropdownField<String>(
      value: models.any((m) => m.effectiveModelId == effectiveId)
          ? effectiveId
          : null,
      labelText: l10n.studioModelPickerLabel,
      width: null,
      enabled: enabled,
      entries: models
          .map(
            (m) => StudioDropdownEntry<String>(
              value: m.effectiveModelId,
              label: _labelFor(m, l10n),
            ),
          )
          .toList(growable: false),
      onChanged: enabled ? onChanged : null,
    );
  }

  String _labelFor(ModelListEntry m, AppLocalizations l10n) {
    final p = m.pricing;
    if (p == null) return '${m.label} (${m.name})';
    return '${m.label} · ${valueTierLabel(l10n, p.valueTier)}';
  }
}
