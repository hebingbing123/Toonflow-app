import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

export 'outbound_webhook_platform.dart';

class OutboundWebhookCreateBodyV1 {
  const OutboundWebhookCreateBodyV1({
    required this.url,
    this.secret,
    this.workspaceId,
    this.eventTypes,
    this.enabled,
  });

  final String url;
  final String? secret;
  final String? workspaceId;
  final List<String>? eventTypes;
  final bool? enabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      if (secret != null) 'secret': secret,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (eventTypes != null) 'eventTypes': eventTypes,
      if (enabled != null) 'enabled': enabled,
    };
  }
}

class OutboundWebhookPatchBodyV1 {
  const OutboundWebhookPatchBodyV1({
    this.url,
    this.secret,
    this.clearWorkspaceId,
    this.workspaceId,
    this.eventTypes,
    this.enabled,
  });

  final String? url;
  final String? secret;
  /// When `true`, backend clears `workspace_id` (ignored when setting [workspaceId] in same request).
  final bool? clearWorkspaceId;
  final String? workspaceId;
  final List<String>? eventTypes;
  final bool? enabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (url != null) 'url': url,
      if (secret != null) 'secret': secret,
      if (clearWorkspaceId != null) 'clearWorkspaceId': clearWorkspaceId,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (eventTypes != null) 'eventTypes': eventTypes,
      if (enabled != null) 'enabled': enabled,
    };
  }
}

class OutboundWebhookCreatedResponseV1 {
  const OutboundWebhookCreatedResponseV1({
    required this.id,
    required this.url,
    required this.secret,
  });

  final String id;
  final String url;
  final String secret;

  factory OutboundWebhookCreatedResponseV1.fromJson(Map<String, dynamic> json) {
    return OutboundWebhookCreatedResponseV1(
      id: json['id'] as String,
      url: json['url'] as String,
      secret: json['secret'] as String,
    );
  }
}

class OutboundWebhookListItemV1 {
  const OutboundWebhookListItemV1({
    required this.id,
    required this.url,
    required this.createdAt,
    this.workspaceId,
    this.eventTypes = const <String>[],
    this.enabled = true,
    this.updatedAt,
  });

  final String id;
  final String url;
  final String createdAt;
  final String? workspaceId;
  final List<String> eventTypes;
  final bool enabled;
  final String? updatedAt;

  factory OutboundWebhookListItemV1.fromJson(Map<String, dynamic> json) {
    final et = json['eventTypes'];
    return OutboundWebhookListItemV1(
      id: json['id'] as String,
      url: json['url'] as String,
      createdAt: json['createdAt'] as String,
      workspaceId: json['workspaceId'] as String?,
      eventTypes: et is List<dynamic>
          ? et.map((e) => e as String).toList(growable: false)
          : const <String>[],
      enabled: json['enabled'] as bool? ?? true,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class OutboundWebhookListResponseV1 {
  const OutboundWebhookListResponseV1({required this.items});

  final List<OutboundWebhookListItemV1> items;

  factory OutboundWebhookListResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return OutboundWebhookListResponseV1(
      items: raw
          .cast<Map<String, dynamic>>()
          .map(OutboundWebhookListItemV1.fromJson)
          .toList(growable: false),
    );
  }
}

class OutboundWebhookTestBodyV1 {
  const OutboundWebhookTestBodyV1({this.eventType});

  final String? eventType;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{if (eventType != null) 'eventType': eventType};
  }
}

class OutboundWebhookTestResponseV1 {
  const OutboundWebhookTestResponseV1({
    required this.delivered,
    required this.httpStatus,
    required this.error,
  });

  final bool delivered;
  final int? httpStatus;
  final String? error;

  factory OutboundWebhookTestResponseV1.fromJson(Map<String, dynamic> json) {
    return OutboundWebhookTestResponseV1(
      delivered: json['delivered'] as bool,
      httpStatus: json['httpStatus'] as int?,
      error: json['error'] as String?,
    );
  }
}

class OutboundWebhookDeliveryItemV1 {
  const OutboundWebhookDeliveryItemV1({
    required this.id,
    required this.eventType,
    required this.status,
    this.httpStatus,
    this.error,
    required this.retryCount,
    required this.createdAt,
    this.deliveredAt,
    this.payload,
  });

  final String id;
  final String eventType;
  final String status;
  final int? httpStatus;
  final String? error;
  final int retryCount;
  final String createdAt;
  final String? deliveredAt;
  final Map<String, dynamic>? payload;

  factory OutboundWebhookDeliveryItemV1.fromJson(Map<String, dynamic> json) {
    final p = json['payload'];
    return OutboundWebhookDeliveryItemV1(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      status: json['status'] as String,
      httpStatus: json['httpStatus'] as int?,
      error: json['error'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      createdAt: json['createdAt'] as String,
      deliveredAt: json['deliveredAt'] as String?,
      payload: p is Map<String, dynamic> ? p : null,
    );
  }
}

class OutboundWebhookDeliveryListResponseV1 {
  const OutboundWebhookDeliveryListResponseV1({required this.items});

  final List<OutboundWebhookDeliveryItemV1> items;

  factory OutboundWebhookDeliveryListResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final raw = json['items'] as List<dynamic>;
    return OutboundWebhookDeliveryListResponseV1(
      items: raw
          .cast<Map<String, dynamic>>()
          .map(OutboundWebhookDeliveryItemV1.fromJson)
          .toList(growable: false),
    );
  }
}

/// `POST /api/v1/settings/webhooks/outbound` — OpenAPI `postSettingsOutboundWebhookCreateV1`.
Future<OutboundWebhookCreatedResponseV1> postSettingsOutboundWebhookCreateV1(
  String accessToken,
  OutboundWebhookCreateBodyV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/webhooks/outbound');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return OutboundWebhookCreatedResponseV1.fromJson(map);
}

/// `GET /api/v1/settings/webhooks/outbound` — OpenAPI `getSettingsOutboundWebhookListV1`.
Future<OutboundWebhookListResponseV1> getSettingsOutboundWebhookListV1(
  String accessToken, {
  int? limit,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/webhooks/outbound',
  ).replace(queryParameters: {if (limit != null) 'limit': limit.toString()});
  final res = await http
      .get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return OutboundWebhookListResponseV1.fromJson(map);
}

/// `PATCH /api/v1/settings/webhooks/outbound/{id}` — OpenAPI `patchSettingsOutboundWebhookV1`.
Future<OutboundWebhookListItemV1> patchSettingsOutboundWebhookV1(
  String accessToken,
  String id,
  OutboundWebhookPatchBodyV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/webhooks/outbound/$id');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return OutboundWebhookListItemV1.fromJson(map);
}

/// `DELETE /api/v1/settings/webhooks/outbound/{id}` — OpenAPI `deleteSettingsOutboundWebhookV1`.
Future<void> deleteSettingsOutboundWebhookV1(
  String accessToken,
  String id,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/webhooks/outbound/$id');
  final res = await http
      .delete(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
}

/// `POST /api/v1/settings/webhooks/outbound/{id}/test` — OpenAPI `postSettingsOutboundWebhookTestV1`.
Future<OutboundWebhookTestResponseV1> postSettingsOutboundWebhookTestV1(
  String accessToken,
  String id,
  OutboundWebhookTestBodyV1 body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/webhooks/outbound/$id/test',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return OutboundWebhookTestResponseV1.fromJson(map);
}

/// `GET /api/v1/settings/webhooks/outbound/{id}/deliveries` — OpenAPI `getSettingsOutboundWebhookDeliveriesV1`.
Future<OutboundWebhookDeliveryListResponseV1>
getSettingsOutboundWebhookDeliveriesV1(
  String accessToken,
  String id, {
  int? limit,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/webhooks/outbound/$id/deliveries',
  ).replace(queryParameters: {if (limit != null) 'limit': limit.toString()});
  final res = await http
      .get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return OutboundWebhookDeliveryListResponseV1.fromJson(map);
}
