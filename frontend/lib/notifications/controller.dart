import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../content_compliance/controller.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'download_stub.dart'
    if (dart.library.html) 'download_web.dart'
    if (dart.library.io) 'download_io.dart';

typedef NotificationsAccessTokenProvider = String? Function();
typedef NotificationsErrorSink = void Function(String? error);
typedef NotificationsL10nProvider = AppLocalizations? Function();

class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required NotificationsAccessTokenProvider accessTokenProvider,
    required NotificationsErrorSink onErrorChanged,
    required NotificationsL10nProvider l10nProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider;

  final NotificationsAccessTokenProvider _accessTokenProvider;
  final NotificationsErrorSink _onErrorChanged;
  final NotificationsL10nProvider _l10nProvider;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  String? _wsToken;
  bool _primed = false;

  bool loading = false;
  bool loadingPreferences = false;
  bool savingPreferences = false;
  bool loadingMore = false;
  bool markingAllRead = false;
  int unreadCount = 0;
  bool hasMore = false;
  int? nextBeforeId;
  List<NotificationRecordV1> items = const <NotificationRecordV1>[];
  NotificationPreferencesV1 _preferences = NotificationPreferencesV1.defaults();
  NotificationPreferencesAuditMetaV1 _preferencesAudit =
      const NotificationPreferencesAuditMetaV1(
        updatedAt: null,
        updatedBy: 'self',
        source: 'manual',
      );
  List<ContentComplianceClearedTemplateItemV1> complianceClearedTemplates =
      const <ContentComplianceClearedTemplateItemV1>[];
  List<ContentComplianceClearedTemplateItemV1>
  workspaceSharedComplianceTemplates =
      const <ContentComplianceClearedTemplateItemV1>[];
  List<ContentComplianceClearedTemplateAuditItemV1>
  workspaceSharedComplianceAudit =
      const <ContentComplianceClearedTemplateAuditItemV1>[];
  bool canManageWorkspaceSharedTemplates = false;
  bool loadingWorkspaceSharedAudit = false;
  bool workspaceSharedAuditHasMore = false;
  int workspaceSharedAuditNextOffset = 0;
  String workspaceSharedAuditTemplateFilter = '';
  String workspaceSharedAuditActionFilter = '';
  DateTime? workspaceSharedAuditStartAtFilter;
  DateTime? workspaceSharedAuditEndAtFilter;
  List<WorkspaceSharedComplianceAuditExportRecordV1>
  workspaceSharedAuditExports =
      const <WorkspaceSharedComplianceAuditExportRecordV1>[];
  bool loadingExportHistory = false;
  bool enqueueingWorkspaceSharedAuditAsyncExport = false;

  /// 导出历史旁的信息条（轮询完成/超时等），不走全局错误条。
  String? workspaceSharedAsyncExportInfo;
  bool workspaceSharedExportHistoryHasMore = false;
  int workspaceSharedExportHistoryNextOffset = 0;

  /// 导出历史列表筛选：'' | 'json' | 'csv'
  String exportHistoryFormatFilter = '';
  DateTime? exportHistoryExportedStartFilter;
  DateTime? exportHistoryExportedEndFilter;
  List<String> complianceTemplateOrder = const <String>[];
  List<String> complianceTemplateRecent = const <String>[];

  int get contentComplianceClearedThrottleMinutes =>
      _preferences.contentComplianceClearedThrottleMinutes;
  Map<String, int> get contentComplianceClearedStageThrottleMinutes =>
      _preferences.contentComplianceClearedStageThrottleMinutes;
  NotificationPreferencesAuditMetaV1 get preferencesAudit => _preferencesAudit;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

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
    final l10n = _l10n;
    _setError(
      connected
          ? null
          : (l10n?.notificationsRealtimeDisconnected ??
                'Realtime notifications disconnected. You can still refresh manually.'),
    );
  }

  void addPlatformStatusTransitionNotification({
    required bool healthy,
    required List<String> degradedEndpoints,
  }) {
    final l10n = _l10n;
    final title = healthy
        ? (l10n?.notificationsPlatformStatusRecovered ??
              'Platform status recovered')
        : (l10n?.notificationsPlatformStatusDegraded ??
              'Platform status degraded');
    final message = healthy
        ? (l10n?.notificationsPlatformStatusRecoveredMessage ??
              'The status page detected that key endpoints recovered.')
        : degradedEndpoints.isEmpty
        ? (l10n?.notificationsPlatformStatusDegradedMessage ??
              'The status page detected key endpoint failures.')
        : (l10n?.notificationsPlatformStatusAffectedEndpoints(
                degradedEndpoints.join('、'),
              ) ??
              'Affected endpoints: ${degradedEndpoints.join(', ')}');
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

  void ingestContentComplianceAlerts(
    List<ContentComplianceQueueAlertV1> alerts,
  ) {
    final nextSyntheticIds = alerts
        .map((alert) => _contentComplianceAlertSyntheticId(alert.stage))
        .toSet();
    final stale = items
        .where(
          (item) =>
              item.notificationType == 'content_compliance_alert' &&
              !nextSyntheticIds.contains(item.id),
        )
        .toList(growable: false);
    if (stale.isNotEmpty) {
      final staleUnread = stale.where((item) => item.isUnread).length;
      items = items
          .where(
            (item) =>
                !(item.notificationType == 'content_compliance_alert' &&
                    !nextSyntheticIds.contains(item.id)),
          )
          .toList(growable: false);
      unreadCount = (unreadCount - staleUnread).clamp(0, 1 << 30);
    }
    for (final alert in alerts) {
      final syntheticId = _contentComplianceAlertSyntheticId(alert.stage);
      final existingIndex = items.indexWhere((item) => item.id == syntheticId);
      final existing = existingIndex >= 0 ? items[existingIndex] : null;
      final now = DateTime.now();
      final synthetic = NotificationRecordV1(
        id: syntheticId,
        userId: 'local',
        workspaceId: null,
        projectId: null,
        projectNumericId: null,
        jobId: null,
        notificationType: 'content_compliance_alert',
        title:
            _l10n?.notificationsComplianceAlertTitle(alert.title) ??
            'Content compliance alert: ${alert.title}',
        message: alert.message,
        linkPath: '/product/content-compliance?escalationStage=${alert.stage}',
        payload: <String, dynamic>{
          'level': alert.level,
          'stage': alert.stage,
          'count': alert.count,
          'severity': alert.level,
        },
        filePath: null,
        changedAt: null,
        readAt: existing?.readAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final hadItem = existing != null;
      final wasUnread = existing?.isUnread ?? false;
      _upsertItem(synthetic, pinToTop: true);
      if (!hadItem && synthetic.isUnread) {
        unreadCount += 1;
      } else if (wasUnread && !synthetic.isUnread) {
        unreadCount = unreadCount > 0 ? unreadCount - 1 : 0;
      }
    }
    notifyListeners();
  }

  int _contentComplianceAlertSyntheticId(String stage) {
    final normalized = stage.trim().toLowerCase();
    final hash = normalized.isEmpty ? 0 : normalized.hashCode.abs();
    return -(9_000_000 + (hash % 1_000_000));
  }

  void clearWorkspaceSharedAsyncExportInfo() {
    if (workspaceSharedAsyncExportInfo == null) {
      return;
    }
    workspaceSharedAsyncExportInfo = null;
    notifyListeners();
  }

  String _unsupportedDownloadMessage(String fileName, int bytes) {
    return _l10n?.notificationsDownloadUnsupported(fileName, bytes) ??
        'Downloads are not supported on this platform: $fileName ($bytes bytes).';
  }

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  void _reportRustOrDescribe(Object error) {
    if (error is RustApiException) {
      reportRustApiError(error, onErrorChanged: _setError);
    } else {
      _setError(describeUserVisibleApiError(_l10n ?? rustApiLookupL10nFromPlatform(), error));
    }
  }

  Future<void> prime() async {
    final token = _accessToken;
    if (token == null) {
      reset();
      return;
    }
    await _ensureLiveUpdates(token);
    await _loadComplianceClearedTemplates(token);
    await _loadWorkspaceSharedComplianceTemplates(token);
    await _loadPreferences(token);
    if (_primed && items.isNotEmpty) {
      return;
    }
    _primed = true;
    await refresh();
  }

  Future<void> _loadPreferences(String token) async {
    if (loadingPreferences) {
      return;
    }
    loadingPreferences = true;
    notifyListeners();
    try {
      final envelope = await fetchNotificationPreferencesExportV1(token);
      _preferences = envelope.preferences;
      _preferencesAudit = envelope.audit;
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      loadingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> _loadComplianceClearedTemplates(String token) async {
    try {
      complianceClearedTemplates =
          await fetchContentComplianceClearedTemplatesV1(token);
    } catch (_) {
      complianceClearedTemplates =
          const <ContentComplianceClearedTemplateItemV1>[];
    }
  }

  Future<void> _loadWorkspaceSharedComplianceTemplates(String token) async {
    try {
      final result = await fetchWorkspaceSharedComplianceClearedTemplatesV1(
        token,
      );
      workspaceSharedComplianceTemplates = result.templates;
      canManageWorkspaceSharedTemplates = result.canManage;
      await reloadWorkspaceSharedComplianceAudit();
      await _reloadExportHistoryPage(token, offset: 0);
    } catch (_) {
      workspaceSharedComplianceTemplates =
          const <ContentComplianceClearedTemplateItemV1>[];
      workspaceSharedComplianceAudit =
          const <ContentComplianceClearedTemplateAuditItemV1>[];
      canManageWorkspaceSharedTemplates = false;
      loadingWorkspaceSharedAudit = false;
      workspaceSharedAuditHasMore = false;
      workspaceSharedAuditNextOffset = 0;
      workspaceSharedAuditExports =
          const <WorkspaceSharedComplianceAuditExportRecordV1>[];
      loadingExportHistory = false;
      workspaceSharedExportHistoryHasMore = false;
      workspaceSharedExportHistoryNextOffset = 0;
    }
  }

  Future<void> applyExportHistoryFiltersAndReload({
    required String formatFilter,
    DateTime? exportedStart,
    DateTime? exportedEnd,
  }) async {
    exportHistoryFormatFilter = formatFilter.trim().toLowerCase();
    exportHistoryExportedStartFilter = exportedStart;
    exportHistoryExportedEndFilter = exportedEnd;
    final token = _accessToken;
    if (token == null) {
      return;
    }
    await _reloadExportHistoryPage(token, offset: 0);
  }

  Future<void> reloadExportHistory() async {
    final token = _accessToken;
    if (token == null) {
      return;
    }
    await _reloadExportHistoryPage(token, offset: 0);
  }

  Future<void> _reloadExportHistoryPage(
    String token, {
    required int offset,
  }) async {
    if (loadingExportHistory) {
      return;
    }
    loadingExportHistory = true;
    notifyListeners();
    try {
      final result =
          await fetchWorkspaceSharedComplianceClearedTemplateAuditExportsV1(
            token,
            format: exportHistoryFormatFilter.isEmpty
                ? null
                : exportHistoryFormatFilter,
            exportedStartAt: exportHistoryExportedStartFilter,
            exportedEndAt: exportHistoryExportedEndFilter,
            limit: 20,
            offset: offset,
          );
      final items = result.$1;
      final hasMore = result.$2;
      final nextOffset = result.$3;
      if (offset == 0) {
        workspaceSharedAuditExports = items;
      } else {
        workspaceSharedAuditExports =
            <WorkspaceSharedComplianceAuditExportRecordV1>[
              ...workspaceSharedAuditExports,
              ...items,
            ];
      }
      workspaceSharedExportHistoryHasMore = hasMore;
      workspaceSharedExportHistoryNextOffset =
          nextOffset ?? (offset + items.length);
    } catch (error) {
      _reportRustOrDescribe(error);
      if (offset == 0) {
        workspaceSharedAuditExports =
            const <WorkspaceSharedComplianceAuditExportRecordV1>[];
      }
    } finally {
      loadingExportHistory = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreExportHistory() async {
    final token = _accessToken;
    if (token == null ||
        loadingExportHistory ||
        !workspaceSharedExportHistoryHasMore) {
      return;
    }
    await _reloadExportHistoryPage(
      token,
      offset: workspaceSharedExportHistoryNextOffset,
    );
  }

  DateTime? _parseOptionalIso(String? raw) {
    if (raw == null) {
      return null;
    }
    final t = raw.trim();
    if (t.isEmpty) {
      return null;
    }
    return DateTime.tryParse(t);
  }

  Future<void> applyExportRecordToSharedAuditFilters(
    WorkspaceSharedComplianceAuditExportRecordV1 record,
  ) async {
    final tid = (record.templateId ?? '').trim();
    final act = (record.action ?? '').trim();
    workspaceSharedAuditTemplateFilter = tid;
    workspaceSharedAuditActionFilter = act;
    workspaceSharedAuditStartAtFilter = _parseOptionalIso(record.startAt);
    workspaceSharedAuditEndAtFilter = _parseOptionalIso(record.endAt);
    notifyListeners();
    await reloadWorkspaceSharedComplianceAudit(
      templateId: tid,
      action: act,
      startAt: workspaceSharedAuditStartAtFilter,
      endAt: workspaceSharedAuditEndAtFilter,
    );
  }

  Future<String?> downloadWorkspaceSharedComplianceAuditWithExportRecord(
    WorkspaceSharedComplianceAuditExportRecordV1 record,
  ) async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    final delivery = (record.exportDelivery ?? '').trim().toLowerCase();
    final jobId = (record.jobId ?? '').trim();
    if (delivery == 'async' && jobId.isNotEmpty) {
      try {
        final dl =
            await downloadWorkspaceSharedComplianceClearedTemplateAuditExportJobFileV1(
              token,
              jobId: jobId,
              fallbackFileName: record.fileName.isEmpty
                  ? null
                  : record.fileName,
            );
        final path = await saveNotificationExportToDevice(
          dl.bytes,
          dl.fileName,
          contentType: dl.contentType,
          unsupportedMessage: _unsupportedDownloadMessage(
            dl.fileName,
            dl.bytes.length,
          ),
        );
        _setError(null);
        return path;
      } catch (error) {
        _reportRustOrDescribe(error);
        return null;
      } finally {
        await reloadExportHistory();
      }
    }
    final normalizedFormat = record.format.trim().toLowerCase();
    final format = normalizedFormat == 'csv' ? 'csv' : 'json';
    try {
      final (
        fileName,
        content,
      ) = await exportWorkspaceSharedComplianceClearedTemplateAuditV1(
        token,
        format: format,
        templateId: (record.templateId ?? '').trim().isEmpty
            ? null
            : (record.templateId ?? '').trim(),
        action: (record.action ?? '').trim().isEmpty
            ? null
            : (record.action ?? '').trim(),
        startAt: _parseOptionalIso(record.startAt),
        endAt: _parseOptionalIso(record.endAt),
      );
      final path = await saveNotificationExportToDevice(
        utf8.encode(content),
        fileName,
        unsupportedMessage: _unsupportedDownloadMessage(
          fileName,
          utf8.encode(content).length,
        ),
      );
      _setError(null);
      return path;
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    } finally {
      await reloadExportHistory();
    }
  }

  Future<WorkspaceSharedAuditExportJobRecordV1?>
  enqueueWorkspaceSharedComplianceAuditExportAsync({
    required String format,
  }) async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    enqueueingWorkspaceSharedAuditAsyncExport = true;
    workspaceSharedAsyncExportInfo = null;
    notifyListeners();
    try {
      final job =
          await postWorkspaceSharedComplianceClearedTemplateAuditExportAsyncV1(
            token,
            format: format,
            templateId: workspaceSharedAuditTemplateFilter.isEmpty
                ? null
                : workspaceSharedAuditTemplateFilter,
            action: workspaceSharedAuditActionFilter.isEmpty
                ? null
                : workspaceSharedAuditActionFilter,
            startAt: workspaceSharedAuditStartAtFilter,
            endAt: workspaceSharedAuditEndAtFilter,
          );
      _setError(null);
      return job;
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    } finally {
      enqueueingWorkspaceSharedAuditAsyncExport = false;
      notifyListeners();
    }
  }

  /// Polls `export-jobs/{id}` in the background and calls [reloadExportHistory] when the job
  /// finishes (artifact ready, failed, or cancelled) or after a timeout.
  void scheduleWorkspaceSharedAuditExportHistoryPoll(String jobId) {
    final token = _accessToken;
    final id = jobId.trim();
    if (token == null || id.isEmpty) {
      return;
    }
    workspaceSharedAsyncExportInfo = null;
    notifyListeners();
    unawaited(
      _pollWorkspaceSharedAuditExportJobForHistory(
        snapshotToken: token,
        jobId: id,
      ),
    );
  }

  Future<void> _pollWorkspaceSharedAuditExportJobForHistory({
    required String snapshotToken,
    required String jobId,
  }) async {
    const maxAttempts = 90;
    const delay = Duration(seconds: 2);
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(delay);
      final t = _accessToken;
      if (t == null || t != snapshotToken) {
        return;
      }
      try {
        final job =
            await fetchWorkspaceSharedComplianceClearedTemplateAuditExportJobV1(
              t,
              jobId: jobId,
            );
        if (job.downloadReady || job.status == 'succeeded') {
          await reloadExportHistory();
          workspaceSharedAsyncExportInfo =
              _l10n?.notificationsComplianceSharedAsyncExportCompleted ??
              'Workspace shared audit background export completed. Export history refreshed.';
          notifyListeners();
          return;
        }
        if (job.status == 'failed' || job.status == 'cancelled') {
          workspaceSharedAsyncExportInfo = null;
          final tid = job.numericTaskId;
          if (job.status == 'cancelled') {
            _setError(
              _l10n?.notificationsComplianceSharedAsyncExportCancelled(tid) ??
                  'Workspace shared audit background export cancelled (task #$tid).',
            );
          } else {
            final detail = (job.errorMessage ?? '').trim();
            _setError(
              detail.isEmpty
                  ? (_l10n?.notificationsComplianceSharedAsyncExportFailed(
                          tid,
                        ) ??
                        'Workspace shared audit background export failed (task #$tid).')
                  : (_l10n?.notificationsComplianceSharedAsyncExportFailedWithDetail(
                          tid,
                          detail,
                        ) ??
                        'Workspace shared audit background export failed (task #$tid): $detail'),
            );
          }
          await reloadExportHistory();
          notifyListeners();
          return;
        }
      } catch (_) {
        return;
      }
    }
    if (_accessToken == snapshotToken) {
      await reloadExportHistory();
      workspaceSharedAsyncExportInfo =
          _l10n?.notificationsComplianceSharedAsyncExportTimedOut ??
          'Background export did not confirm completion within about 3 minutes and may still be queued. Check "Filter export history" shortly.';
      notifyListeners();
    }
  }

  Future<void> reloadWorkspaceSharedComplianceAudit({
    String? templateId,
    String? action,
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    final token = _accessToken;
    if (token == null || loadingWorkspaceSharedAudit) {
      return;
    }
    loadingWorkspaceSharedAudit = true;
    workspaceSharedAuditTemplateFilter = templateId?.trim() ?? '';
    workspaceSharedAuditActionFilter = action?.trim() ?? '';
    workspaceSharedAuditStartAtFilter = startAt;
    workspaceSharedAuditEndAtFilter = endAt;
    notifyListeners();
    try {
      final (items, hasMore, nextOffset) = await _fetchWorkspaceSharedAuditPage(
        token,
        offset: 0,
      );
      workspaceSharedComplianceAudit = items;
      workspaceSharedAuditHasMore = hasMore;
      workspaceSharedAuditNextOffset = nextOffset ?? items.length;
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      loadingWorkspaceSharedAudit = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreWorkspaceSharedComplianceAudit() async {
    final token = _accessToken;
    if (token == null ||
        loadingWorkspaceSharedAudit ||
        !workspaceSharedAuditHasMore) {
      return;
    }
    loadingWorkspaceSharedAudit = true;
    notifyListeners();
    try {
      final (items, hasMore, nextOffset) = await _fetchWorkspaceSharedAuditPage(
        token,
        offset: workspaceSharedAuditNextOffset,
      );
      workspaceSharedComplianceAudit =
          <ContentComplianceClearedTemplateAuditItemV1>[
            ...workspaceSharedComplianceAudit,
            ...items,
          ];
      workspaceSharedAuditHasMore = hasMore;
      workspaceSharedAuditNextOffset =
          nextOffset ?? (workspaceSharedAuditNextOffset + items.length);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      loadingWorkspaceSharedAudit = false;
      notifyListeners();
    }
  }

  Future<(List<ContentComplianceClearedTemplateAuditItemV1>, bool, int?)>
  _fetchWorkspaceSharedAuditPage(
    String token, {
    required int offset,
    int limit = 20,
  }) {
    return fetchWorkspaceSharedComplianceClearedTemplateAuditV1(
      token,
      templateId: workspaceSharedAuditTemplateFilter.isEmpty
          ? null
          : workspaceSharedAuditTemplateFilter,
      action: workspaceSharedAuditActionFilter.isEmpty
          ? null
          : workspaceSharedAuditActionFilter,
      startAt: workspaceSharedAuditStartAtFilter,
      endAt: workspaceSharedAuditEndAtFilter,
      limit: limit,
      offset: offset,
    );
  }

  Future<String?> downloadWorkspaceSharedComplianceAuditJson() async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    try {
      final (
        fileName,
        content,
      ) = await exportWorkspaceSharedComplianceClearedTemplateAuditV1(
        token,
        format: 'json',
        templateId: workspaceSharedAuditTemplateFilter.isEmpty
            ? null
            : workspaceSharedAuditTemplateFilter,
        action: workspaceSharedAuditActionFilter.isEmpty
            ? null
            : workspaceSharedAuditActionFilter,
        startAt: workspaceSharedAuditStartAtFilter,
        endAt: workspaceSharedAuditEndAtFilter,
      );
      return await saveNotificationExportToDevice(
        utf8.encode(content),
        fileName,
        unsupportedMessage: _unsupportedDownloadMessage(
          fileName,
          utf8.encode(content).length,
        ),
      );
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    } finally {
      await reloadExportHistory();
    }
  }

  Future<String?> downloadWorkspaceSharedComplianceAuditCsv() async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    try {
      final (
        fileName,
        content,
      ) = await exportWorkspaceSharedComplianceClearedTemplateAuditV1(
        token,
        format: 'csv',
        templateId: workspaceSharedAuditTemplateFilter.isEmpty
            ? null
            : workspaceSharedAuditTemplateFilter,
        action: workspaceSharedAuditActionFilter.isEmpty
            ? null
            : workspaceSharedAuditActionFilter,
        startAt: workspaceSharedAuditStartAtFilter,
        endAt: workspaceSharedAuditEndAtFilter,
      );
      return await saveNotificationExportToDevice(
        utf8.encode(content),
        fileName,
        unsupportedMessage: _unsupportedDownloadMessage(
          fileName,
          utf8.encode(content).length,
        ),
      );
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    } finally {
      await reloadExportHistory();
    }
  }

  Future<String?> exportComplianceClearedTemplatesJson() async {
    final token = _accessToken;
    if (token == null) {
      return null;
    }
    try {
      final (templates, order, recent) =
          await exportContentComplianceClearedTemplatesV1(token);
      complianceTemplateOrder = order;
      complianceTemplateRecent = recent;
      final payload = <String, dynamic>{
        'templates': templates.map((t) => t.toJson()).toList(growable: false),
        'order': order,
        'recent': recent,
      };
      return const JsonEncoder.withIndent('  ').convert(payload);
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    }
  }

  Future<int?> importComplianceClearedTemplatesJson(
    String rawJson, {
    required String mode,
  }) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return null;
    }
    Map<String, dynamic> parsed;
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        _setError(
          _l10n?.notificationsImportJsonObjectRequired ??
              'Imported content must be a JSON object.',
        );
        return null;
      }
      parsed = decoded;
    } catch (error) {
      final loc = _l10n ?? rustApiLookupL10nFromPlatform();
      final detail = describeUserVisibleApiError(loc, error);
      _setError(
        _l10n?.notificationsImportJsonParseFailed(detail) ??
            'Failed to parse imported JSON: $detail',
      );
      return null;
    }
    final templates =
        (parsed['templates'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) => ContentComplianceClearedTemplateItemV1.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .where((item) => item.id.isNotEmpty)
            .toList(growable: false);
    final order = (parsed['order'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final recent = (parsed['recent'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    savingPreferences = true;
    notifyListeners();
    try {
      final (
        count,
        nextTemplates,
        nextOrder,
        nextRecent,
      ) = await importContentComplianceClearedTemplatesV1(
        token,
        templates: templates,
        order: order,
        recent: recent,
        mode: mode,
      );
      complianceClearedTemplates = nextTemplates;
      complianceTemplateOrder = nextOrder;
      complianceTemplateRecent = nextRecent;
      await _loadPreferences(token);
      _setError(null);
      return count;
    } catch (error) {
      _reportRustOrDescribe(error);
      return null;
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> saveContentComplianceClearedThrottleMinutes(int minutes) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    final clamped = minutes.clamp(1, 1440);
    savingPreferences = true;
    notifyListeners();
    try {
      _preferences = await saveNotificationPreferencesV1(
        token,
        _preferences.copyWith(contentComplianceClearedThrottleMinutes: clamped),
      );
      await _loadPreferences(token);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> saveContentComplianceClearedThrottlePolicy({
    required int globalMinutes,
    required Map<String, int> stageMinutes,
  }) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    final cleanedStageMinutes = <String, int>{};
    stageMinutes.forEach((stage, minutes) {
      final normalized = stage.trim().toLowerCase();
      if (normalized.isEmpty) {
        return;
      }
      cleanedStageMinutes[normalized] = minutes.clamp(1, 1440);
    });
    savingPreferences = true;
    notifyListeners();
    try {
      _preferences = await saveNotificationPreferencesV1(
        token,
        _preferences.copyWith(
          contentComplianceClearedThrottleMinutes: globalMinutes.clamp(1, 1440),
          contentComplianceClearedStageThrottleMinutes: cleanedStageMinutes,
        ),
      );
      await _loadPreferences(token);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> applyComplianceClearedThrottleTemplate(String templateId) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      final (applied, templates) =
          await applyContentComplianceClearedTemplateV1(token, templateId);
      complianceClearedTemplates = templates;
      await _loadPreferences(token);
      if (!applied) {
        _setError(
          _l10n?.notificationsUnknownTemplate(templateId) ??
              'Unknown template: $templateId',
        );
      } else {
        _setError(null);
      }
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> upsertComplianceClearedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      complianceClearedTemplates =
          await upsertContentComplianceClearedTemplateV1(token, template);
      await _loadPreferences(token);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> deleteComplianceClearedTemplate(String id) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      complianceClearedTemplates =
          await deleteContentComplianceClearedTemplateV1(token, id);
      await _loadPreferences(token);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> reorderComplianceClearedTemplates(List<String> ids) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      complianceClearedTemplates =
          await reorderContentComplianceClearedTemplatesV1(token, ids);
      await _loadPreferences(token);
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> upsertWorkspaceSharedComplianceClearedTemplate(
    ContentComplianceClearedTemplateItemV1 template,
  ) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      final result = await upsertWorkspaceSharedComplianceClearedTemplateV1(
        token,
        template,
      );
      workspaceSharedComplianceTemplates = result.templates;
      canManageWorkspaceSharedTemplates = result.canManage;
      await reloadWorkspaceSharedComplianceAudit(
        templateId: workspaceSharedAuditTemplateFilter,
        action: workspaceSharedAuditActionFilter,
      );
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
  }

  Future<void> deleteWorkspaceSharedComplianceClearedTemplate(String id) async {
    final token = _accessToken;
    if (token == null || savingPreferences) {
      return;
    }
    savingPreferences = true;
    notifyListeners();
    try {
      final result = await deleteWorkspaceSharedComplianceClearedTemplateV1(
        token,
        id,
      );
      workspaceSharedComplianceTemplates = result.templates;
      canManageWorkspaceSharedTemplates = result.canManage;
      await reloadWorkspaceSharedComplianceAudit(
        templateId: workspaceSharedAuditTemplateFilter,
        action: workspaceSharedAuditActionFilter,
      );
      _setError(null);
    } catch (error) {
      _reportRustOrDescribe(error);
    } finally {
      savingPreferences = false;
      notifyListeners();
    }
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
    } catch (error) {
      _reportRustOrDescribe(error);
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
    } catch (error) {
      _reportRustOrDescribe(error);
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
    } catch (error) {
      _reportRustOrDescribe(error);
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
    } catch (error) {
      _reportRustOrDescribe(error);
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
    complianceClearedTemplates =
        const <ContentComplianceClearedTemplateItemV1>[];
    workspaceSharedComplianceTemplates =
        const <ContentComplianceClearedTemplateItemV1>[];
    workspaceSharedComplianceAudit =
        const <ContentComplianceClearedTemplateAuditItemV1>[];
    canManageWorkspaceSharedTemplates = false;
    loadingWorkspaceSharedAudit = false;
    workspaceSharedAuditHasMore = false;
    workspaceSharedAuditNextOffset = 0;
    workspaceSharedAuditTemplateFilter = '';
    workspaceSharedAuditActionFilter = '';
    workspaceSharedAuditStartAtFilter = null;
    workspaceSharedAuditEndAtFilter = null;
    workspaceSharedAuditExports =
        const <WorkspaceSharedComplianceAuditExportRecordV1>[];
    loadingExportHistory = false;
    enqueueingWorkspaceSharedAuditAsyncExport = false;
    workspaceSharedAsyncExportInfo = null;
    workspaceSharedExportHistoryHasMore = false;
    workspaceSharedExportHistoryNextOffset = 0;
    exportHistoryFormatFilter = '';
    exportHistoryExportedStartFilter = null;
    exportHistoryExportedEndFilter = null;
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
