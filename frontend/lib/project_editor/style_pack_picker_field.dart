import 'package:flutter/material.dart';

import '../design_system/components/studio_dropdown_field.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'style_pack_catalog.dart';

/// Dropdown for bundled art or story style packs (project editor + Studio).
class StylePackPickerField extends StatelessWidget {
  const StylePackPickerField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedPath,
    required this.onChanged,
    required this.isArtPack,
    this.enabled = true,
  });

  final String label;
  final List<StylePackOption> options;
  final String? selectedPath;
  final ValueChanged<String?> onChanged;
  final bool isArtPack;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = isArtPack
        ? findArtStylePackOption(options, selectedPath)
        : findStoryStylePackOption(options, selectedPath);
    final hasSelectedOutsideList =
        selectedPath != null &&
        selectedPath!.isNotEmpty &&
        selected == null;
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem<String>(
        value: '',
        child: Text(l10n.projectEditorBasicsStylePackPickerNone),
      ),
      ...options.map(
        (option) => DropdownMenuItem<String>(
          value: option.path,
          child: Text(
            l10n.projectEditorBasicsStylePackOptionDisplay(
              option.name,
              option.tag,
            ),
          ),
        ),
      ),
      if (hasSelectedOutsideList)
        DropdownMenuItem<String>(
          value: selectedPath,
          child: Text(
            l10n.projectEditorBasicsStylePackPickerCurrentConfigRow(
              selectedPath!,
            ),
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StudioDropdownButtonFormField<String>(
          initialValue: selectedPath ?? '',
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
          items: items,
          onChanged: enabled
              ? (value) =>
                    onChanged((value == null || value.isEmpty) ? null : value)
              : null,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          selected?.description ??
              (hasSelectedOutsideList
                  ? l10n.projectEditorBasicsStylePackFootnoteLegacy
                  : l10n.projectEditorBasicsStylePackFootnoteNone),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
          ),
        ),
      ],
    );
  }
}
