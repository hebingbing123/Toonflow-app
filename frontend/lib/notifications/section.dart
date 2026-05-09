import 'package:flutter/material.dart';
import 'controller.dart';
import '../rust_api/settings/notifications.dart';

/// Notifications section widget
class NotificationsSection extends StatelessWidget {
  final NotificationsController controller;
  final Function(NotificationRecordV1) onOpenNotification;

  const NotificationsSection({
    super.key,
    required this.controller,
    required this.onOpenNotification,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final notifications = controller.items;
        
        if (controller.loading && notifications.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (notifications.isEmpty) {
          return const Center(
            child: Text('No notifications'),
          );
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return ListTile(
              title: Text(notification.title),
              subtitle: Text(notification.message),
              onTap: () => onOpenNotification(notification),
            );
          },
        );
      },
    );
  }
}
