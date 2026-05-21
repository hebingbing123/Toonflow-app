import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/studio_code_labels.dart';
import '../../studio/job_center.dart';
import '../components/studio_dialog_shell.dart';
import '../tokens.dart';

/// Compact job indicator for the studio top bar (Wave 1.5).
class StudioJobTray extends StatelessWidget {
  const StudioJobTray({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudioJobCenter.instance,
      builder: (context, _) {
        final count = StudioJobCenter.instance.activeCount;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        final tokens = StudioTokens.of(context);
        return Tooltip(
          message: l10n.studioJobTrayActiveJobs(count),
          child: TextButton.icon(
            onPressed: () => _showJobSheet(context),
            icon: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: tokens.accent,
              ),
            ),
            label: Text('$count'),
          ),
        );
      },
    );
  }

  void _showJobSheet(BuildContext context) {
    final jobs = StudioJobCenter.instance.activeJobs.toList(growable: false);
    showStudioBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  sheetL10n.studioJobTraySheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ...jobs.map(
                (j) => ListTile(
                  title: Text(j.label ?? j.jobId),
                  subtitle: Text(
                    studioJobStatusLabel(
                      AppLocalizations.of(ctx)!,
                      j.status,
                    ),
                  ),
                  trailing: j.progress != null
                      ? Text('${(j.progress! * 100).round()}%')
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
