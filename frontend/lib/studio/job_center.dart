import 'package:flutter/foundation.dart';

/// Tracks in-flight generation jobs for [StudioJobTray] (Wave 1.5).
class StudioJobCenter extends ChangeNotifier {
  StudioJobCenter._();
  static final StudioJobCenter instance = StudioJobCenter._();

  final Map<String, StudioJobSnapshot> _jobs = <String, StudioJobSnapshot>{};

  Iterable<StudioJobSnapshot> get activeJobs =>
      _jobs.values.where((j) => j.isActive);

  int get activeCount => activeJobs.length;

  void upsert(StudioJobSnapshot snapshot) {
    _jobs[snapshot.jobId] = snapshot;
    notifyListeners();
  }

  void remove(String jobId) {
    if (_jobs.remove(jobId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    _jobs.clear();
    notifyListeners();
  }
}

class StudioJobSnapshot {
  const StudioJobSnapshot({
    required this.jobId,
    required this.status,
    this.label,
    this.progress,
  });

  final String jobId;
  final String status;
  final String? label;
  final double? progress;

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'running' || s == 'queued';
  }
}
