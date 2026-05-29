import 'package:flutter/material.dart';

import '../tokens.dart';
import 'studio_icon_button.dart';
import 'studio_text_styles.dart';

/// Node in a [StudioTree].
class StudioTreeNode {
  const StudioTreeNode({
    required this.id,
    required this.label,
    this.subtitle,
    this.children = const [],
    this.leading,
  });

  final String id;
  final String label;
  final String? subtitle;
  final List<StudioTreeNode> children;
  final Widget? leading;
}

/// Expandable hierarchical list with Studio spacing and motion.
class StudioTree extends StatefulWidget {
  const StudioTree({
    super.key,
    required this.nodes,
    this.expandedIds = const {},
    this.onExpansionChanged,
    this.onNodeTap,
    this.indent = StudioSpacing.md,
  });

  final List<StudioTreeNode> nodes;
  final Set<String> expandedIds;
  final ValueChanged<Set<String>>? onExpansionChanged;
  final ValueChanged<StudioTreeNode>? onNodeTap;
  final double indent;

  @override
  State<StudioTree> createState() => _StudioTreeState();
}

class _StudioTreeState extends State<StudioTree> {
  late Set<String> _expanded = Set<String>.from(widget.expandedIds);

  @override
  void didUpdateWidget(covariant StudioTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expandedIds != widget.expandedIds) {
      _expanded = Set<String>.from(widget.expandedIds);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
    widget.onExpansionChanged?.call(Set<String>.from(_expanded));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in widget.nodes)
          _TreeTile(
            node: node,
            depth: 0,
            expandedIds: _expanded,
            indent: widget.indent,
            onToggle: _toggle,
            onNodeTap: widget.onNodeTap,
          ),
      ],
    );
  }
}

class _TreeTile extends StatelessWidget {
  const _TreeTile({
    required this.node,
    required this.depth,
    required this.expandedIds,
    required this.indent,
    required this.onToggle,
    this.onNodeTap,
  });

  final StudioTreeNode node;
  final int depth;
  final Set<String> expandedIds;
  final double indent;
  final ValueChanged<String> onToggle;
  final ValueChanged<StudioTreeNode>? onNodeTap;

  bool get _hasChildren => node.children.isNotEmpty;
  bool get _expanded => expandedIds.contains(node.id);

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onNodeTap == null ? null : () => onNodeTap!(node),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent * depth + StudioSpacing.xs,
                top: StudioSpacing.xs,
                bottom: StudioSpacing.xs,
                right: StudioSpacing.sm,
              ),
              child: Row(
                children: [
                  if (_hasChildren)
                    StudioIconButton(
                      icon: _expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      label: _expanded ? 'Collapse' : 'Expand',
                      onPressed: () => onToggle(node.id),
                    )
                  else
                    const SizedBox(width: 36),
                  if (node.leading != null) ...[
                    node.leading!,
                    const SizedBox(width: StudioSpacing.xs),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                        if (node.subtitle != null)
                          Text(
                            node.subtitle!,
                            style: studioHintStyle(context),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_hasChildren && _expanded)
          Column(
            children: [
              for (final child in node.children)
                _TreeTile(
                  node: child,
                  depth: depth + 1,
                  expandedIds: expandedIds,
                  indent: indent,
                  onToggle: onToggle,
                  onNodeTap: onNodeTap,
                ),
            ],
          ),
      ],
    );
  }
}
