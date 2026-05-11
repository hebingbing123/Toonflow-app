/// Slugs aligned with backend `OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES`.
const List<String> kOutboundWebhookPlatformEventTypes = <String>[
  'job.completed',
  'job.failed',
  'project.created',
  'workspace.member.added',
];

/// UI label for [kOutboundWebhookPlatformEventTypes] entries.
String outboundWebhookPlatformEventLabel(String slug) {
  switch (slug) {
    case 'job.completed':
      return 'Job 完成';
    case 'job.failed':
      return 'Job 失败';
    case 'project.created':
      return '项目创建';
    case 'workspace.member.added':
      return '工作区成员加入';
    default:
      return slug;
  }
}

/// Stored `[]` or missing ⇒ treat as「订阅全部」。
Set<String> outboundWebhookEffectiveSelection(Iterable<String> stored) {
  final list = stored.toList();
  if (list.isEmpty) {
    return Set<String>.from(kOutboundWebhookPlatformEventTypes);
  }
  return Set<String>.from(list);
}

/// PATCH body: `[]` ⇒ backend normalizes to all platform types.
List<String> outboundWebhookEventTypesPayloadForPatch(Set<String> selected) {
  final all = kOutboundWebhookPlatformEventTypes.toSet();
  final inter = selected.intersection(all);
  if (inter.length == all.length) {
    return <String>[];
  }
  final out = inter.toList()..sort();
  return out;
}

/// Create body: omit key when subscribing to all (smaller payload).
List<String>? outboundWebhookEventTypesPayloadForCreate(Set<String> selected) {
  final payload = outboundWebhookEventTypesPayloadForPatch(selected);
  if (payload.isEmpty) {
    return null;
  }
  return payload;
}

final RegExp _outboundWebhookWorkspaceUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

bool outboundWebhookWorkspaceIdLooksValid(String trimmed) {
  return _outboundWebhookWorkspaceUuid.hasMatch(trimmed);
}
