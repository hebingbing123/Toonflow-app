import 'package:flutter/material.dart';

import '../design_system/studio_scheduler.dart';
import '../platform/studio_load_state.dart';
import 'controller.dart';
import 'section_view.dart';

class JobsSection extends StatefulWidget {
  const JobsSection({
    super.key,
    required this.controller,
    this.studioPresentation = false,
  });

  final JobsController controller;
  final bool studioPresentation;

  @override
  State<JobsSection> createState() => _JobsSectionState();
}

class _JobsSectionState extends State<JobsSection> {
  @override
  void initState() {
    super.initState();
    if (widget.studioPresentation &&
        widget.controller.jobsLoadState == StudioLoadState.initial) {
      StudioScheduler.scheduleOnceUntil('jobs_section_initial_load', () {
        if (!mounted) return;
        widget.controller.loadJobs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => JobsSectionView(
        studioPresentation: widget.studioPresentation,
        model: JobsSectionViewModel(
          loadingJobs: widget.controller.loadingJobs,
          loadingJobKinds: widget.controller.loadingJobKinds,
          loadingJobKindSummary: widget.controller.loadingJobKindSummary,
          loadingJobStatusSummary: widget.controller.loadingJobStatusSummary,
          creatingJob: widget.controller.creatingJob,
          loadingJobById: widget.controller.loadingJobById,
          jobIdController: widget.controller.jobIdController,
          jobs: widget.controller.jobs,
          jobsLoadState: widget.controller.jobsLoadState,
          jobsLastError: widget.controller.jobsLastError,
          jobByIdLine: widget.controller.jobByIdLine,
          jobKindsLine: widget.controller.jobKindsLine,
          jobKindSummaryLine: widget.controller.jobKindSummaryLine,
          jobStatusSummaryLine: widget.controller.jobStatusSummaryLine,
          cancellingJobId: widget.controller.cancellingJobId,
          retryingJobId: widget.controller.retryingJobId,
        ),
        callbacks: JobsSectionViewCallbacks(
          onJobIdChanged: widget.controller.onJobIdChanged,
          onLoadJobs: widget.controller.loadJobs,
          onLoadJobsKindFlutterProbe: widget.controller.loadJobsKindFlutterProbe,
          onLoadJobsStatusFailed: widget.controller.loadJobsStatusFailed,
          onLoadJobsKindProbeStatusQueued:
              widget.controller.loadJobsKindProbeStatusQueued,
          onLoadJobKinds: widget.controller.loadJobKinds,
          onLoadJobKindSummary: widget.controller.loadJobKindSummary,
          onLoadJobStatusSummary: widget.controller.loadJobStatusSummary,
          onCreateProbeJob: widget.controller.createProbeJob,
          onFetchJobById: widget.controller.fetchJobById,
          onSelectJob: widget.controller.selectJob,
          onRetryFailedJob: widget.controller.retryFailedJob,
          onCancelQueuedJob: widget.controller.cancelQueuedJob,
        ),
      ),
    );
  }
}
