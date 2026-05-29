import 'package:flutter/material.dart';

import '../../design_system/components/studio_loading_placeholders.dart';

/// Shared async loading chrome for notifications pane (rebuild plan P1-2 split).
class NotificationsPaneLoadingBody extends StatelessWidget {
  const NotificationsPaneLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const StudioPaneLoadingSkeleton();
  }
}
