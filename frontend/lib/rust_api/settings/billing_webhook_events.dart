import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class BillingWebhookEventsQueryV1 {
  const BillingWebhookEventsQueryV1({
    this.informationalEvent,
    this.provider,
    this.rawEventId,
    this.rawEventIdPrefix,
    this.eventType,
    this.providerEventId,
    this.providerEventIdPrefix,
    this.eventCreatedFrom,
    this.eventCreatedTo,
    this.createdFrom,
    this.createdTo,
    this.idMin,
    this.idMax,
    this.sort,
    this.limit,
    this.offset,
  });

  final bool? informationalEvent;
  final String? provider;
  final String? rawEventId;
  final String? rawEventIdPrefix;
  final String? eventType;
  final String? providerEventId;
  final String? providerEventIdPrefix;
  final String? eventCreatedFrom;
  final String? eventCreatedTo;
  final String? createdFrom;
  final String? createdTo;
  final int? idMin;
  final int? idMax;
  final String? sort;
  final int? limit;
  final int? offset;

  Map<String, String> toQueryParameters() {
    final map = <String, String>{};
    void putText(String key, String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        map[key] = text;
      }
    }

    if (informationalEvent != null) {
      map['informational_event'] = '$informationalEvent';
    }
    putText('provider', provider);
    putText('raw_event_id', rawEventId);
    putText('raw_event_id_prefix', rawEventIdPrefix);
    putText('event_type', eventType);
    putText('provider_event_id', providerEventId);
    putText('provider_event_id_prefix', providerEventIdPrefix);
    putText('event_created_from', eventCreatedFrom);
    putText('event_created_to', eventCreatedTo);
    putText('created_from', createdFrom);
    putText('created_to', createdTo);
    if (idMin != null) {
      map['id_min'] = '$idMin';
    }
    if (idMax != null) {
      map['id_max'] = '$idMax';
    }
    putText('sort', sort);
    if (limit != null) {
      map['limit'] = '$limit';
    }
    if (offset != null && offset! > 0) {
      map['offset'] = '$offset';
    }
    return map;
  }
}

class BillingWebhookEventItemV1 {
  const BillingWebhookEventItemV1({
    required this.id,
    required this.providerEventId,
    this.provider,
    this.rawEventId,
    this.eventType,
    this.eventCreatedAt,
    required this.isInformationalEvent,
    required this.createdAt,
  });

  final int id;
  final String providerEventId;
  final String? provider;
  final String? rawEventId;
  final String? eventType;
  final DateTime? eventCreatedAt;
  final bool isInformationalEvent;
  final DateTime createdAt;

  factory BillingWebhookEventItemV1.fromJson(Map<String, dynamic> json) {
    return BillingWebhookEventItemV1(
      id: (json['id'] as num).toInt(),
      providerEventId: json['provider_event_id'] as String,
      provider: json['provider'] as String?,
      rawEventId: json['raw_event_id'] as String?,
      eventType: json['event_type'] as String?,
      eventCreatedAt: json['event_created_at'] == null
          ? null
          : DateTime.parse(json['event_created_at'] as String),
      isInformationalEvent: json['is_informational_event'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BillingWebhookEventsResponseV1 {
  const BillingWebhookEventsResponseV1({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
    this.nextOffset,
  });

  final List<BillingWebhookEventItemV1> items;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;
  final int? nextOffset;

  factory BillingWebhookEventsResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return BillingWebhookEventsResponseV1(
      items: raw
          .map(
            (e) =>
                BillingWebhookEventItemV1.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
      nextOffset: (json['next_offset'] as num?)?.toInt(),
    );
  }
}

Future<BillingWebhookEventsResponseV1> getBillingWebhookEventsV1(
  String accessToken, {
  BillingWebhookEventsQueryV1 query = const BillingWebhookEventsQueryV1(),
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/webhooks/billing/events',
  ).replace(queryParameters: query.toQueryParameters());
  final res = await http
      .get(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BillingWebhookEventsResponseV1.fromJson(map);
}
