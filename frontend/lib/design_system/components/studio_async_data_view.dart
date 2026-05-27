import 'package:flutter/material.dart';

import '../../platform/studio_load_state.dart';
import 'studio_empty_state.dart';
import 'studio_loading_placeholders.dart';

/// Unified loading / empty / error / success body for async Studio panes.
class StudioAsyncDataView extends StatelessWidget {
  const StudioAsyncDataView({
    super.key,
    required this.child,
    this.loading = false,
    this.loadState,
    this.error,
    this.onRetry,
    this.isEmpty = false,
    this.empty,
    this.loadingPlaceholder = StudioLoadingPlaceholder.pane,
    this.loadingItemCount = 4,
    this.loadingCrossAxisCount = 3,
    this.scrollableLoading = true,
    this.loadingPadding,
  });

  final Widget child;
  final bool loading;
  final StudioLoadState? loadState;
  final Object? error;
  final VoidCallback? onRetry;
  final bool isEmpty;
  final Widget? empty;
  final StudioLoadingPlaceholder loadingPlaceholder;
  final int loadingItemCount;
  final int loadingCrossAxisCount;
  final bool scrollableLoading;
  final EdgeInsetsGeometry? loadingPadding;

  bool get _isLoading {
    if (loadState != null) {
      return loadState == StudioLoadState.initial ||
          loadState == StudioLoadState.loading;
    }
    return loading;
  }

  bool get _isError {
    if (loadState != null) {
      return loadState == StudioLoadState.error;
    }
    return error != null;
  }

  bool get _isEmpty {
    if (loadState != null) {
      return loadState == StudioLoadState.empty;
    }
    return isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return StudioLoadingPlaceholders.build(
        context,
        loadingPlaceholder,
        itemCount: loadingItemCount,
        crossAxisCount: loadingCrossAxisCount,
        scrollable: scrollableLoading,
        padding: loadingPadding,
      );
    }
    if (_isError) {
      return StudioEmptyState.loadFailed(
        context,
        error: error,
        onRetry: onRetry ?? () {},
      );
    }
    if (_isEmpty && empty != null) {
      return empty!;
    }
    return child;
  }
}
