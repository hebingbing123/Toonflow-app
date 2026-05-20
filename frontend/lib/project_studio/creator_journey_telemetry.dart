import 'dart:async';

import 'package:flutter/foundation.dart';

import '../rust_api/project/creator_journey_api.dart';

/// Lightweight creator-journey signals for debug dashboards and backend audit ingest (T7).
typedef CreatorJourneyTelemetrySink = void Function(CreatorJourneyEvent event);

class CreatorJourneyTelemetry {
  CreatorJourneyTelemetry._();

  static CreatorJourneyTelemetrySink? debugSink;

  /// Immediately uploads pending events (used by tests and [clearProject]).
  @visibleForTesting
  static Future<void> flushNow({
    String? accessToken,
    String? projectUuid,
  }) =>
      _flushPending(accessToken: accessToken, projectUuid: projectUuid);

  /// Test hook: when set, replaces [postCreatorJourneyEvents] for flush batches.
  @visibleForTesting
  static Future<void> Function(
    String accessToken,
    String projectUuid,
    List<CreatorJourneyEventPayload> events,
  )?
  postOverride;

  static String? _accessToken;
  static String? _projectUuid;
  static int? _projectNumericId;
  static final List<CreatorJourneyEvent> _pending = <CreatorJourneyEvent>[];
  static Timer? _flushTimer;

  /// Binds the active project so [record] can batch-upload to the backend.
  static void bindProject({
    required String accessToken,
    required String projectUuid,
    required int projectNumericId,
  }) {
    _accessToken = accessToken;
    _projectUuid = projectUuid;
    _projectNumericId = projectNumericId;
  }

  /// Clears project binding; optionally flushes pending events first.
  static void clearProject({bool flush = true}) {
    _flushTimer?.cancel();
    _flushTimer = null;
    final token = _accessToken;
    final uuid = _projectUuid;
    _accessToken = null;
    _projectUuid = null;
    _projectNumericId = null;
    if (flush && token != null && uuid != null) {
      unawaited(
        _flushPending(
          silent: true,
          accessToken: token,
          projectUuid: uuid,
        ),
      );
    } else {
      _pending.clear();
    }
  }

  static void record(CreatorJourneyEvent event) {
    final enriched = _enrich(event);
    debugSink?.call(enriched);
    if (kDebugMode) {
      debugPrint('creator_journey:${enriched.name} ${enriched.properties}');
    }
    if (_accessToken != null && _projectUuid != null) {
      _pending.add(enriched);
      _scheduleFlush();
    }
  }

  static CreatorJourneyEvent _enrich(CreatorJourneyEvent event) {
    final numericId = _projectNumericId;
    if (numericId == null || event.properties.containsKey('project_id')) {
      return event;
    }
    return CreatorJourneyEvent(
      event.name,
      <String, Object?>{'project_id': numericId, ...event.properties},
    );
  }

  static void _scheduleFlush() {
    if (_flushTimer?.isActive == true) {
      return;
    }
    _flushTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_flushPending());
    });
  }

  static Future<void> _flushPending({
    bool silent = false,
    String? accessToken,
    String? projectUuid,
  }) async {
    final token = accessToken ?? _accessToken;
    final uuid = projectUuid ?? _projectUuid;
    if (token == null || uuid == null || _pending.isEmpty) {
      return;
    }

    while (_pending.isNotEmpty) {
      final take = _pending.length > 32 ? 32 : _pending.length;
      final batch = List<CreatorJourneyEvent>.from(_pending.sublist(0, take));
      _pending.removeRange(0, take);
      final payloads = batch
          .map(
            (CreatorJourneyEvent e) => CreatorJourneyEventPayload(
              name: e.name,
              properties: e.properties,
            ),
          )
          .toList(growable: false);
      try {
        final override = postOverride;
        if (override != null) {
          await override(token, uuid, payloads);
        } else {
          await postCreatorJourneyEvents(token, uuid, events: payloads);
        }
      } catch (e) {
        if (!silent && kDebugMode) {
          debugPrint('creator_journey:flush_failed $e');
        }
        break;
      }
    }
  }
}

class CreatorJourneyEvent {
  const CreatorJourneyEvent(this.name, [this.properties = const {}]);

  final String name;
  final Map<String, Object?> properties;
}
