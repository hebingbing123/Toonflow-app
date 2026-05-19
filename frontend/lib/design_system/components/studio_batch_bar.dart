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
      elevation: 8,
      color: tokens.bgElevated,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Text(
              AppLocalizations.of(context)!.studioBatchSelectedCount(
                selectedCount,
              ),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}
