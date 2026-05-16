import '../../l10n/app_localizations.dart';

/// Slugs aligned with backend `OUTBOUND_WEBHOOK_PLATFORM_EVENT_TYPES`.
const List<String> kOutboundWebhookPlatformEventTypes = <String>[
  'job.completed',
  'job.failed',
  'project.created',
  'workspace.member.added',
];

/// UI label for [kOutboundWebhookPlatformEventTypes] entries.
String outboundWebhookPlatformEventLabel(AppLocalizations l10n, String slug) {
  switch (slug) {
    case 'job.completed':
      return l10n.rustApiOutboundWebhookJobCompleted;
    case 'job.failed':
      return l10n.rustApiOutboundWebhookJobFailed;
    case 'project.created':
      return l10n.rustApiOutboundWebhookProjectCreated;
    case 'workspace.member.added':
      return l10n.rustApiOutboundWebhookWorkspaceMemberAdded;
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
