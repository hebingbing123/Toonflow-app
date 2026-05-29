import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/studio_code_labels.dart';
import '../../studio/job_center.dart';
import '../components/studio_dialog_shell.dart';
import '../components/studio_entrance_motion.dart';
import '../components/studio_metric_switch.dart';
import '../components/studio_repaint_boundary.dart';
import '../tokens.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

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
            icon: StudioRepaintBoundary(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: StudioControlSize.progressStroke,
                  color: tokens.accent,
                ),
              ),
            ),
            label: StudioMetricSwitch(
              transitionKey: count,
              child: Text('$count'),
            ),
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
                padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, StudioSpacing.xs, StudioSpacing.sm, StudioSpacing.chromeActionGap),
                child: Text(
                  sheetL10n.studioJobTraySheetTitle,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ...jobs.indexed.map(
                (entry) => studioStaggeredItem(
                  entry.$1,
                  entranceKey: jobs.length,
                  child: StudioListRow(
                    title: Text(entry.$2.label ?? entry.$2.jobId),
                    subtitle: Text(
                      studioJobStatusLabel(
                        AppLocalizations.of(ctx)!,
                        entry.$2.status,
                      ),
                    ),
                    trailing: entry.$2.progress != null
                        ? Text('${(entry.$2.progress! * 100).round()}%')
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
