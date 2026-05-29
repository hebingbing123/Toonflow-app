import '../../rust_api/settings/notifications.dart';

NotificationRecordV1 studioNotificationWithReadState(
  NotificationRecordV1 item, {
  required bool read,
}) {
  return NotificationRecordV1(
    id: item.id,
    userId: item.userId,
    workspaceId: item.workspaceId,
    projectId: item.projectId,
    projectNumericId: item.projectNumericId,
    jobId: item.jobId,
    notificationType: item.notificationType,
    title: item.title,
    message: item.message,
    linkPath: item.linkPath,
    payload: item.payload,
    filePath: item.filePath,
    changedAt: item.changedAt,
    readAt: read ? DateTime.now().toUtc() : null,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
  );
}

List<NotificationRecordV1> studioNotificationsMarkAllRead(
  List<NotificationRecordV1> items,
) {
  return items
      .map((row) => studioNotificationWithReadState(row, read: true))
      .toList(growable: false);
}
