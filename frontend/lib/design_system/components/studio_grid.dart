import 'package:flutter/material.dart';

import '../studio_responsive_layout.dart';
import '../tokens.dart';
import 'studio_loading_placeholders.dart';

/// Virtualized grid with responsive columns and loading skeleton.
class StudioGrid extends StatelessWidget {
  const StudioGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.loading = false,
    this.skeletonItemCount = 6,
    this.padding,
    this.scrollable = true,
    this.childAspectRatio = 1,
    this.handsetColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.wideColumns = 4,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool loading;
  final int skeletonItemCount;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;
  final double childAspectRatio;
  final int handsetColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int wideColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = studioGridCrossAxisCount(
          constraints.maxWidth,
          handset: handsetColumns,
          tablet: tabletColumns,
          desktop: desktopColumns,
          desktopWide: wideColumns,
        );
        if (loading) {
          return StudioGridSkeleton(
            itemCount: skeletonItemCount,
            crossAxisCount: crossAxisCount,
            scrollable: scrollable,
            padding: padding,
          );
        }
        return GridView.builder(
          padding: padding,
          shrinkWrap: !scrollable,
          physics: scrollable
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: StudioSpacing.sm,
            crossAxisSpacing: StudioSpacing.sm,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
