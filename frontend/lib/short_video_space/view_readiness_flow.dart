part of 'view.dart';

/// One node in a horizontal flow lane (node row + caption row stay column-aligned).
class _FlowLaneCell {
  const _FlowLaneCell({required this.node, required this.caption});

  final Widget node;
  final Widget caption;
}

/// Handset-friendly vertical stack when a horizontal lane would overflow.
class _VerticalFlowLane extends StatelessWidget {
  const _VerticalFlowLane({
    required this.nodeMinHeight,
    required this.cells,
  });

  final double nodeMinHeight;
  final List<_FlowLaneCell> cells;

  @override
  Widget build(BuildContext context) {
    final muted = studioMutedTextColor(context);
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: StudioSpacing.xs),
            child: Align(
              alignment: Alignment.centerLeft,
              child: studioDecorativeIcon(
                Icons.arrow_downward_rounded,
                size: StudioIconSize.sm,
                color: muted.withValues(alpha: 0.78),
              ),
            ),
          ),
        );
      }
      children.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: nodeMinHeight,
              child: cells[i].node,
            ),
            const SizedBox(height: StudioSpacing.xs),
            cells[i].caption,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Arrows align to the vertical center of [nodeMinHeight]; captions sit in a second row.
class _HorizontalFlowLane extends StatefulWidget {
  const _HorizontalFlowLane({
    required this.nodeWidth,
    required this.nodeMinHeight,
    required this.cells,
  });

  static const double _arrowSlotWidth = 36;

  final double nodeWidth;
  final double nodeMinHeight;
  final List<_FlowLaneCell> cells;

  @override
  State<_HorizontalFlowLane> createState() => _HorizontalFlowLaneState();
}

class _HorizontalFlowLaneState extends State<_HorizontalFlowLane> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cells.isEmpty) return const SizedBox.shrink();
    final nodeChildren = <Widget>[];
    final captionChildren = <Widget>[];
    for (var i = 0; i < widget.cells.length; i++) {
      if (i > 0) {
        nodeChildren.add(
          SizedBox(
            width: _HorizontalFlowLane._arrowSlotWidth,
            height: widget.nodeMinHeight,
            child: const Center(child: _FlowArrowIcon()),
          ),
        );
        captionChildren.add(
          const SizedBox(width: _HorizontalFlowLane._arrowSlotWidth),
        );
      }
      nodeChildren.add(
        SizedBox(
          width: widget.nodeWidth,
          height: widget.nodeMinHeight,
          child: widget.cells[i].node,
        ),
      );
      captionChildren.add(
        SizedBox(width: widget.nodeWidth, child: widget.cells[i].caption),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final arrowCount = math.max(0, widget.cells.length - 1);
        final totalLaneWidth =
            widget.cells.length * widget.nodeWidth +
            arrowCount * _HorizontalFlowLane._arrowSlotWidth;
        if (viewportWidth < totalLaneWidth &&
            viewportWidth < kStudioHandsetMaxWidth) {
          return _VerticalFlowLane(
            nodeMinHeight: widget.nodeMinHeight,
            cells: widget.cells,
          );
        }
        final lane = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: nodeChildren,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: captionChildren,
            ),
          ],
        );
        return SizedBox(
          width: viewportWidth,
          child: StudioScrollbar(
            controller: _scrollController,
            notificationPredicate: (ScrollNotification notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.only(
                bottom: StudioSpacing.chromeActionGap,
                right: StudioSpacing.xs,
              ),
              child: SizedBox(width: totalLaneWidth, child: lane),
            ),
          ),
        );
      },
    );
  }
}

class _FlowArrowIcon extends StatelessWidget {
  const _FlowArrowIcon();

  @override
  Widget build(BuildContext context) {
    final muted = studioMutedTextColor(context);
    return studioDecorativeIcon(
      Icons.arrow_forward_rounded,
      size: StudioIconSize.sm,
      color: muted.withValues(alpha: 0.78),
    );
  }
}

/// Linear onboarding stages (立项 → 剧本 → 素材 → 出片).
class _StageFlowStrip extends StatelessWidget {
  const _StageFlowStrip({required this.cards});

  /// Must fit [_FlowNodeShell] vertical padding plus two label lines (see layout).
  static const double _nodeMinHeight = 68;

  final List<ShortVideoStageCardData> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final nodeWidth = studioFlowNodeWidth(
          laneWidth,
          cards.length,
          minNodeWidth: 140,
          maxNodeWidth: 220,
        );
        return _HorizontalFlowLane(
          nodeWidth: nodeWidth,
          nodeMinHeight: _nodeMinHeight,
          cells: cards
              .map(
                (card) => _FlowLaneCell(
                  node: _FlowNodeShell(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          card.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: studioControlLabelStyle(context),
                        ),
                        const SizedBox(height: StudioLayoutSpacing.titleTight),
                        Text(
                          card.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: tokens.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  caption: Text(
                    card.detail,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      height: 1.35,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _FlowNodeShell extends StatelessWidget {
  const _FlowNodeShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.bgInset.withValues(alpha: 0.88),
          border: Border.all(color: tokens.borderSubtle),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StudioLayoutSpacing.inlineGap,
            vertical: StudioSpacing.xs,
          ),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}

class _ReadinessFlowStrip extends StatelessWidget {
  const _ReadinessFlowStrip({required this.items});

  static const double _nodeMinHeight = 40;

  final List<ShortVideoReadinessItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final nodeWidth = studioFlowNodeWidth(
          laneWidth,
          items.length,
          minNodeWidth: 108,
          maxNodeWidth: 168,
        );
        return _HorizontalFlowLane(
          nodeWidth: nodeWidth,
          nodeMinHeight: _nodeMinHeight,
      cells: items
          .map(
            (item) => _FlowLaneCell(
              node: _ReadinessFlowNode(item: item),
              caption: Text(
                item.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.35,
                ),
              ),
            ),
          )
          .toList(growable: false),
        );
      },
    );
  }
}

class _ReadinessFlowNode extends StatelessWidget {
  const _ReadinessFlowNode({required this.item});

  final ShortVideoReadinessItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final accent = item.ready ? tokens.primary : muted;
    final border = item.ready
        ? tokens.primary.withValues(alpha: 0.45)
        : tokens.borderSubtle;
    final fill = item.ready
        ? tokens.primarySoft.withValues(alpha: 0.85)
        : tokens.bgInset.withValues(alpha: 0.88);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: StudioSpacing.xs,
            vertical: StudioLayoutSpacing.microGap,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: <Widget>[
                Icon(
                  item.ready
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  size: StudioIconSize.xs,
                  color: accent,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: item.ready ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
