import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_job_tray.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/studio/job_center.dart';

import '../support/studio_golden_app.dart';

void main() {
  setUp(StudioJobCenter.instance.clear);
  tearDown(StudioJobCenter.instance.clear);

  testWidgets('job tray shows active count', (tester) async {
    StudioJobCenter.instance.upsert(
      const StudioJobSnapshot(
        jobId: 'job-export-1',
        status: 'running',
        label: '导出视频',
        progress: 0.42,
      ),
    );

    await tester.pumpWidget(
      studioGoldenApp(child: const StudioJobTray()),
    );
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(
      find.byTooltip(AppLocalizationsZh().studioJobTrayActiveJobs(1)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('job tray hides when no active jobs', (tester) async {
    await tester.pumpWidget(
      studioGoldenApp(child: const StudioJobTray()),
    );
    await tester.pump();

    expect(find.byType(StudioJobTray), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}
