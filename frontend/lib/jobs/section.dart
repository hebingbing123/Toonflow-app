import 'package:flutter/material.dart';
import 'controller.dart';
import 'section_view.dart';

class JobsSection extends StatelessWidget {
  const JobsSection({
    super.key,
    required this.controller,
    this.studioPresentation = false,
  });

  final JobsController controller;
  final bool studioPresentation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => JobsSectionView(
        studioPresentation: studioPresentation,
        model: JobsSectionViewModel(
          loadingJobs: controller.loadingJobs,
          loadingJobKinds: controller.loadingJobKinds,
          loadingJobKindSummary: controller.loadingJobKindSummary,
          loadingJobStatusSummary: controller.loadingJobStatusSummary,
          creatingJob: controller.creatingJob,
          loadingJobById: controller.loadingJobById,
          jobIdController: controller.jobIdController,
          jobs: controller.jobs,
          jobByIdLine: controller.jobByIdLine,
          jobKindsLine: controller.jobKindsLine,
          jobKindSummaryLine: controller.jobKindSummaryLine,
          jobStatusSummaryLine: controller.jobStatusSummaryLine,
          cancellingJobId: controller.cancellingJobId,
          retryingJobId: controller.retryingJobId,
        ),
        callbacks: JobsSectionViewCallbacks(
          onJobIdChanged: controller.onJobIdChanged,
          onLoadJobs: controller.loadJobs,
          onLoadJobsKindFlutterProbe: controller.loadJobsKindFlutterProbe,
          onLoadJobsStatusFailed: controller.loadJobsStatusFailed,
          onLoadJobsKindProbeStatusQueued:
              controller.loadJobsKindProbeStatusQueued,
          onLoadJobKinds: controller.loadJobKinds,
          onLoadJobKindSummary: controller.loadJobKindSummary,
          onLoadJobStatusSummary: controller.loadJobStatusSummary,
          onCreateProbeJob: controller.createProbeJob,
          onFetchJobById: controller.fetchJobById,
          onSelectJob: controller.selectJob,
          onRetryFailedJob: controller.retryFailedJob,
          onCancelQueuedJob: controller.cancelQueuedJob,
        ),
      ),
    );
  }
}
