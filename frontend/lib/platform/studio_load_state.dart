/// Unified async data presentation for Studio product panes.
enum StudioLoadState {
  initial,
  loading,
  success,
  empty,
  error,
}

/// Maps controller-reported state + in-flight flag into a [StudioAsyncDataView] state.
StudioLoadState resolveStudioPaneLoadState({
  required StudioLoadState reported,
  bool busy = false,
  bool hasData = true,
}) {
  if (reported == StudioLoadState.error) {
    return StudioLoadState.error;
  }
  if (reported == StudioLoadState.initial ||
      reported == StudioLoadState.loading ||
      busy) {
    return StudioLoadState.loading;
  }
  if (!hasData) {
    return StudioLoadState.empty;
  }
  return StudioLoadState.success;
}
