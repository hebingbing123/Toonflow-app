import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../rust_api.dart';

typedef NotificationsAccessTokenProvider = String? Function();
typedef NotificationsErrorSink = void Function(String? error);

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required NotificationsAccessTokenProvider accessTokenProvider,
    required NotificationsErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final NotificationsAccessTokenProvider _accessTokenProvider;
  final NotificationsErrorSink _onErrorChanged;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _wsToken;
  bool _primed = false;

  bool loading = false;
  bool loadingMore = false;
  bool markingAllRead = false;
  int unreadCount = 0;
  bool hasMore = false;
  int? nextBeforeId;
  List<NotificationRecordV1> items = const <NotificationRecordV1>[];

  String? get _accessToken => _accessTokenProvider();

  void ingestWsNotificationEvent(NotificationRecordV1 item) {
    final hadItem = items.any((existing) => existing.id == item.id);
    final previous = hadItem
        ? items.firstWhere((existing) => existing.id == item.id)
        : null;
    _upsertItem(item, pinToTop: !hadItem);
    if (!hadItem && item.isUnread) {
      unreadCount += 1;
    } else if (previous != null && previous.isUnread && !item.isUnread) {
      unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
    } else if (previous != null && !previous.isUnread && item.isUnread) {
      unreadCount += 1;
    }
    notifyListeners();
  }

  void setRealtimeConnection(bool connected) {
    _setError(connected ? null : '实时通知连接已断开，仍可手动刷新通知中心。');
  }

  void addPlatformStatusTransitionNotification({
    required bool healthy,
    required List<String> degradedEndpoints,
  }) {
    final title = healthy ? '平台状态恢复' : '平台状态降级';
    final message = healthy
        ? '平台状态面检测到关键端点已恢复正常。'
        : degradedEndpoints.isEmpty
        ? '平台状态面检测到关键端点异常。'
        : '受影响端点：${degradedEndpoints.join('、')}';
    final now = DateTime.now();
    final synthetic = NotificationRecordV1(
      id: -now.microsecondsSinceEpoch,
      userId: 'local',
      workspaceId: null,
      projectId: null,
      projectNumericId: null,
      jobId: null,
      notificationType: 'system_platform_status',
      title: title,
      message: message,
      linkPath: '/product/platform-status',
      payload: <String, dynamic>{
        'healthy': healthy,
        'degradedEndpoints': degradedEndpoints,
      },
      filePath: null,
      changedAt: null,
      readAt: null,
      createdAt: now,
      updatedAt: now,
    );
    _upsertItem(synthetic, pinToTop: true);
    unreadCount += 1;
    notifyListeners();
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  Future<void> prime() async {
    final token = _accessToken;
    if (token == null) {
      reset();
      return;
    }
    await _ensureLiveUpdates(token);
    if (_primed && items.isNotEmpty) {
      return;
    }
    _primed = true;
    await refresh();
  }

  Future<void> refresh() async {
    final token = _accessToken;
    if (token == null) {
      reset();
      return;
    }
    await _ensureLiveUpdates(token);
    loading = true;
    _setError(null);
    notifyListeners();
    try {
      final response = await fetchNotificationsV1(token);
      items = response.items;
      unreadCount = response.unreadCount;
      hasMore = response.hasMore;
      nextBeforeId = response.nextBeforeId;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final token = _accessToken;
    if (token == null || loadingMore || !hasMore || nextBeforeId == null) {
      return;
    }
    loadingMore = true;
    notifyListeners();
    try {
      final response = await fetchNotificationsV1(
        token,
        beforeId: nextBeforeId,
      );
      items = <NotificationRecordV1>[...items, ...response.items];
      unreadCount = response.unreadCount;
      hasMore = response.hasMore;
      nextBeforeId = response.nextBeforeId;
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markRead(NotificationRecordV1 item, {bool read = true}) async {
    final token = _accessToken;
    if (token == null) {
      return;
    }
    try {
      final response = await markNotificationsReadV1(token, <int>[
        item.id,
      ], read: read);
      _mergeUpdatedItems(response.items);
      unreadCount = response.unreadCount;
      notifyListeners();
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    }
  }

  Future<void> markAllRead() async {
    final token = _accessToken;
    if (token == null || markingAllRead) {
      return;
    }
    markingAllRead = true;
    notifyListeners();
    try {
      final response = await markAllNotificationsReadV1(token);
      unreadCount = response.unreadCount;
      items = items
          .map(
            (item) => item.isUnread
                ? NotificationRecordV1(
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
                    readAt: DateTime.now(),
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt,
                  )
                : item,
          )
          .toList(growable: false);
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      markingAllRead = false;
      notifyListeners();
    }
  }

  void reset() {
    unawaited(closeLiveUpdates());
    loading = false;
    loadingMore = false;
    markingAllRead = false;
    unreadCount = 0;
    hasMore = false;
    nextBeforeId = null;
    items = const <NotificationRecordV1>[];
    _primed = false;
    notifyListeners();
  }

  Future<void> _ensureLiveUpdates(String token) async {
    if (_ws != null && _wsToken == token) {
      return;
    }
    await closeLiveUpdates();
    try {
      final channel = WebSocketChannel.connect(
        rustWebSocketUri(kApiBaseUrl, accessToken: token),
      );
      _ws = channel;
      _wsToken = token;
      _wsSub = channel.stream.listen(
        (message) => _handleWsMessage(message.toString()),
        onError: (_) {
          _ws = null;
          _wsSub = null;
          _wsToken = null;
        },
        onDone: () {
          _ws = null;
          _wsSub = null;
          _wsToken = null;
        },
      );
    } catch (_) {
      _ws = null;
      _wsSub = null;
      _wsToken = null;
    }
  }

  void _handleWsMessage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final type = decoded['type'];
      if (type != 'settings.notification.created' &&
          type != 'settings.notification.updated') {
        return;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic>) {
        return;
      }
      final item = NotificationRecordV1.fromJson(payload);
      if (type == 'settings.notification.created') {
        final hadItem = items.any((existing) => existing.id == item.id);
        _upsertItem(item, pinToTop: true);
        if (!hadItem && item.isUnread) {
          unreadCount += 1;
        }
      } else {
        final index = items.indexWhere((existing) => existing.id == item.id);
        if (index >= 0) {
          final previousUnread = items[index].isUnread;
          final nextUnread = item.isUnread;
          if (previousUnread && !nextUnread && unreadCount > 0) {
            unreadCount -= 1;
          } else if (!previousUnread && nextUnread) {
            unreadCount += 1;
          }
          _upsertItem(item);
        } else {
          unawaited(refresh());
          return;
        }
      }
      notifyListeners();
    } catch (_) {
      // Ignore unrelated WS envelopes.
    }
  }

  void _mergeUpdatedItems(List<NotificationRecordV1> updates) {
    for (final item in updates) {
      _upsertItem(item);
    }
  }

  void _upsertItem(NotificationRecordV1 item, {bool pinToTop = false}) {
    final next = List<NotificationRecordV1>.from(items);
    final index = next.indexWhere((existing) => existing.id == item.id);
    if (index >= 0) {
      next[index] = item;
      if (pinToTop && index > 0) {
        next.removeAt(index);
        next.insert(0, item);
      }
    } else if (pinToTop) {
      next.insert(0, item);
    } else {
      next.add(item);
      next.sort((a, b) => b.id.compareTo(a.id));
    }
    items = next;
  }

  Future<void> closeLiveUpdates() async {
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    _wsToken = null;
  }

  @override
  void dispose() {
    unawaited(closeLiveUpdates());
    super.dispose();
  }
}
