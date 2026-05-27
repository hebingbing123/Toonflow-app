import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../rust_api.dart';
import '../design_system/tokens.dart';

/// Provides cached [ProjectModelRoutingResponse] for Studio step panels.
class ProjectStudioModelRoutingScope extends InheritedWidget {
  const ProjectStudioModelRoutingScope({
    super.key,
    required this.routing,
    required super.child,
  });

  final ProjectModelRoutingResponse? routing;

  static ProjectStudioModelRoutingScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProjectStudioModelRoutingScope>();
  }

  static ProjectModelRoutingResponse? routingOf(BuildContext context) {
    return maybeOf(context)?.routing;
  }

  @override
  bool updateShouldNotify(ProjectStudioModelRoutingScope oldWidget) {
    return oldWidget.routing != routing;
  }
}

/// Chip showing the effective model for the current studio step + slot.
class StudioStepModelChip extends StatelessWidget {
  const StudioStepModelChip({
    super.key,
    required this.stepSlug,
    required this.slot,
    this.onEdit,
  });

  final String stepSlug;
  final String slot;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final routing = ProjectStudioModelRoutingScope.routingOf(context);
    final modelId = routing?.effectiveModelFor(step: stepSlug, slot: slot);
    if (modelId == null || modelId.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: StudioSpacing.xs,
        children: <Widget>[
          StudioChip(
            avatar: const Icon(Icons.smart_toy_outlined, size: 16),
            label: Text(modelId, overflow: TextOverflow.ellipsis),
          ),
          if (onEdit != null)
            TextButton(onPressed: onEdit, child: const Text('…')),
        ],
      ),
    );
  }
}
