import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class OutboundWebhookCreateBodyV1 {
  const OutboundWebhookCreateBodyV1({required this.url, this.secret});

  final String url;
  final String? secret;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'url': url, if (secret != null) 'secret': secret};
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
  });

  final String id;
  final String url;
  final String createdAt;

  factory OutboundWebhookListItemV1.fromJson(Map<String, dynamic> json) {
    return OutboundWebhookListItemV1(
      id: json['id'] as String,
      url: json['url'] as String,
      createdAt: json['createdAt'] as String,
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
