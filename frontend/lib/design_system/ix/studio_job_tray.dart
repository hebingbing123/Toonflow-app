import 'package:flutter/material.dart';

import '../../studio/job_center.dart';
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
        final tokens = StudioTokens.of(context);
        return Tooltip(
          message: '$count 个任务进行中',
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: jobs
                .map(
                  (j) => ListTile(
                    title: Text(j.label ?? j.jobId),
                    subtitle: Text(j.status),
                    trailing: j.progress != null
                        ? Text('${(j.progress! * 100).round()}%')
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }
}
