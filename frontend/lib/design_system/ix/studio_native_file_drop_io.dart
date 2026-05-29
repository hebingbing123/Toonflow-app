import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';

/// Wraps [child] with [DropTarget] on desktop (20.1b).
Widget studioWrapNativeFileDrop({
  required Widget child,
  required bool enabled,
  required void Function(List<String> paths) onPathsDropped,
}) {
  if (!enabled) {
    return child;
  }
  return DropTarget(
    onDragDone: (DropDoneDetails detail) {
      final paths = detail.files
          .map((file) => file.path)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toList(growable: false);
      if (paths.isNotEmpty) {
        onPathsDropped(paths);
      }
    },
    child: child,
  );
}
