import 'package:flutter/material.dart';

import 'studio_loading_placeholders.dart';

/// Virtualized list with optional loading skeleton.
class StudioList extends StatelessWidget {
  const StudioList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.loading = false,
    this.skeletonItemCount = 4,
    this.padding,
    this.scrollable = true,
    this.separatorBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool loading;
  final int skeletonItemCount;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final IndexedWidgetBuilder? separatorBuilder;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return StudioListSkeleton(
        itemCount: skeletonItemCount,
        scrollable: scrollable,
        padding: padding,
      );
    }
    if (separatorBuilder != null) {
      return ListView.separated(
        padding: padding,
        shrinkWrap: !scrollable,
        physics: scrollable
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: separatorBuilder!,
        itemBuilder: itemBuilder,
      );
    }
    return ListView.builder(
      padding: padding,
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
