import '../../rust_api/core.dart';

/// Returns a copy of [job] with an optimistic [status] (jobs / task center).
JobRow studioJobRowWithStatus(JobRow job, String status) {
  return JobRow(
    numericTaskId: job.numericTaskId,
    id: job.id,
    ownerUserId: job.ownerUserId,
    kind: job.kind,
    status: status,
    payload: job.payload,
    result: job.result,
    errorMessage: job.errorMessage,
    errorDetails: job.errorDetails,
    idempotencyKey: job.idempotencyKey,
    claimedBy: job.claimedBy,
    createdAt: job.createdAt,
    updatedAt: job.updatedAt,
    jobSubKind: job.jobSubKind,
    productionPhase: job.productionPhase,
  );
}

List<JobRow> studioReplaceJobInList(List<JobRow> jobs, JobRow updated) {
  final next = List<JobRow>.from(jobs);
  final index = next.indexWhere((row) => row.id == updated.id);
  if (index >= 0) {
    next[index] = updated;
  } else {
    next.insert(0, updated);
  }
  return next;
}
