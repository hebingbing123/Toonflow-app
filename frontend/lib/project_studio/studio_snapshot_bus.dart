import 'package:flutter/foundation.dart';

/// Keys for coordinated studio / short-video-space refresh.
enum StudioSnapshotKey {
  readiness,
  assembly,
  exportCheck,
  jobs,
  assets,
  timeline,
  assemblyVersions,
}

/// Broadcast when project-scoped snapshots should reload after mutations.
class StudioSnapshotBus extends ChangeNotifier {
  StudioSnapshotBus();

  final Set<StudioSnapshotKey> _pending = <StudioSnapshotKey>{};

  Set<StudioSnapshotKey> get pendingKeys => Set<StudioSnapshotKey>.unmodifiable(_pending);

  void invalidate(Iterable<StudioSnapshotKey> keys) {
    _pending.addAll(keys);
    notifyListeners();
  }

  void invalidateAll() {
    _pending.addAll(StudioSnapshotKey.values);
    notifyListeners();
  }

  /// Consumers call after handling a refresh wave.
  void clearPending(Iterable<StudioSnapshotKey> keys) {
    _pending.removeAll(keys);
  }
}

/// Product-shell shared bus (studio + short video space).
final StudioSnapshotBus kStudioSnapshotBus = StudioSnapshotBus();

/// Common invalidation sets (see refresh matrix in plan).
abstract final class StudioSnapshotInvalidation {
  static const workbenchMedia = <StudioSnapshotKey>[
    StudioSnapshotKey.readiness,
    StudioSnapshotKey.assembly,
    StudioSnapshotKey.exportCheck,
  ];

  static const productionJobTerminal = <StudioSnapshotKey>[
    StudioSnapshotKey.readiness,
    StudioSnapshotKey.assembly,
    StudioSnapshotKey.exportCheck,
    StudioSnapshotKey.jobs,
  ];

  static const timelineEdit = <StudioSnapshotKey>[
    StudioSnapshotKey.timeline,
    StudioSnapshotKey.assembly,
  ];

  static const assemblyVersionsOnly = <StudioSnapshotKey>[
    StudioSnapshotKey.assemblyVersions,
  ];
}
