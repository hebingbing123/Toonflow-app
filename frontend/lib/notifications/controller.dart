import 'package:flutter/material.dart';

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

  final TextEditingController queryController = TextEditingController();

  bool loading = false;
  bool loadingMore = false;
  bool mutating = false;

  bool unreadOnly = false;
  String notificationType = '';

  List<NotificationRecordV1> items = const <NotificationRecordV1>[];
  int unreadCount = 0;
  bool hasMore = false;
  int? nextBeforeId;

  String? _lastQueryApplied;

  String? get _accessToken => _accessTokenProvider();

  Future<void> prime() async {
    if (items.isNotEmpty || loading || loadingMore) {
      return;
    }
    await refresh();
  }

  void reset() {
    loading = false;
    loadingMore = false;
    mutating = false;
    unreadOnly = false;
    notificationType = '';
    queryController.clear();
    items = const <NotificationRecordV1>[];
    unreadCount = 0;
    hasMore = false;
    nextBeforeId = null;
    _lastQueryApplied = null;
    notifyListeners();
  }

  void setUnreadOnly(bool value) {
    if (unreadOnly == value) {
      return;
    }
    unreadOnly = value;
    notifyListeners();
  }

  void setNotificationType(String value) {
    final next = value.trim();
    if (notificationType == next) {
      return;
    }
    notificationType = next;
    notifyListeners();
  }

  void notifyQueryChanged() {
    notifyListeners();
  }

  bool get queryDirty {
    return (_lastQueryApplied ?? '') != queryController.text.trim();
  }

  List<String> get availableTypes {
    final set = <String>{};
    for (final item in items) {
      final t = item.notificationType.trim();
      if (t.isNotEmpty) {
        set.add(t);
      }
    }
    final out = set.toList()..sort();
    return out;
  }

  Future<void> refresh() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      return;
    }
    loading = true;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final query = ListNotificationsQueryV1(
        notificationType: notificationType,
        unreadOnly: unreadOnly ? true : null,
        query: queryController.text,
        limit: 50,
      );
      final res = await getSettingsNotificationsV1(token, query: query);
      items = res.items;
      unreadCount = res.unreadCount;
      hasMore = res.hasMore;
      nextBeforeId = res.nextBeforeId;
      _lastQueryApplied = queryController.text.trim();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _onErrorChanged);
    } catch (e) {
      _onErrorChanged('$e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final token = _accessToken;
    if (token == null || token.isEmpty || loadingMore || !hasMore) {
      return;
    }
    loadingMore = true;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final res = await getSettingsNotificationsV1(
        token,
        query: ListNotificationsQueryV1(
          notificationType: notificationType,
          unreadOnly: unreadOnly ? true : null,
          query: queryController.text,
          limit: 50,
          beforeId: nextBeforeId,
        ),
      );
      items = <NotificationRecordV1>[...items, ...res.items];
      unreadCount = res.unreadCount;
      hasMore = res.hasMore;
      nextBeforeId = res.nextBeforeId;
      _lastQueryApplied = queryController.text.trim();
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _onErrorChanged);
    } catch (e) {
      _onErrorChanged('$e');
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markReadById(int id, bool read) async {
    final token = _accessToken;
    if (token == null || token.isEmpty || mutating) {
      return;
    }
    mutating = true;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final res = await postSettingsNotificationsMarkReadV1(
        token,
        MarkNotificationsReadBodyV1(ids: <int>[id], read: read),
      );
      unreadCount = res.unreadCount;
      final updatedById = <int, NotificationRecordV1>{
        for (final item in res.items) item.id: item,
      };
      items = items
          .map((item) => updatedById[item.id] ?? item)
          .where((item) => !unreadOnly || !item.isRead)
          .toList(growable: false);
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _onErrorChanged);
    } catch (e) {
      _onErrorChanged('$e');
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    final token = _accessToken;
    if (token == null || token.isEmpty || mutating) {
      return;
    }
    mutating = true;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final res = await postSettingsNotificationsMarkAllReadV1(token);
      unreadCount = res.unreadCount;
      if (unreadOnly) {
        items = const <NotificationRecordV1>[];
      } else {
        final now = DateTime.now().toUtc();
        items = items
            .map(
              (item) => item.isRead
                  ? item
                  : NotificationRecordV1(
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
                      readAt: now,
                      createdAt: item.createdAt,
                      updatedAt: now,
                    ),
            )
            .toList(growable: false);
      }
    } on RustApiException catch (e) {
      reportRustApiError(e, onErrorChanged: _onErrorChanged);
    } catch (e) {
      _onErrorChanged('$e');
    } finally {
      mutating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }
}
