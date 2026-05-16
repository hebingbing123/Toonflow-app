import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';

typedef AccountProbesAccessTokenProvider = String? Function();
typedef AccountProbesErrorSink = void Function(String? error);
typedef AccountProbesScopeTextProvider = String Function();
typedef AccountProbesFetchProjects =
    Future<List<ProjectRow>> Function(String token);
typedef AccountProbesL10nProvider = AppLocalizations? Function();

class AccountProbeClearScope {
  const AccountProbeClearScope({
    required this.projectId,
    this.projectUuid,
    this.scriptId,
  });

  final int? projectId;
  final String? projectUuid;
  final int? scriptId;
}

Future<AccountProbeClearScope> resolveAccountProbeClearScope({
  required String token,
  required String projectIdText,
  required String projectUuidText,
  required String scriptIdText,
  required AccountProbesFetchProjects fetchProjects,
}) async {
  final explicitProjectUuid = _trimmedNonEmpty(projectUuidText);
  var projectId = _parsePositiveInt(projectIdText);
  if (explicitProjectUuid == null && projectId == null) {
    try {
      final projects = await fetchProjects(token);
      if (projects.isNotEmpty) {
        projectId = projects.first.numericId;
        return AccountProbeClearScope(
          projectId: projectId,
          projectUuid: projects.first.id,
          scriptId: _parsePositiveInt(scriptIdText),
        );
      }
    } on RustApiException catch (_) {
      // Keep the legacy fallback when project probing is unavailable.
    }
  }
  return AccountProbeClearScope(
    projectId: projectId,
    projectUuid: explicitProjectUuid,
    scriptId: _parsePositiveInt(scriptIdText),
  );
}

class AccountProbesController extends ChangeNotifier {
  AccountProbesController({
    required AccountProbesAccessTokenProvider accessTokenProvider,
    required AccountProbesErrorSink onErrorChanged,
    required AccountProbesL10nProvider l10nProvider,
    AccountProbesScopeTextProvider? projectIdTextProvider,
    AccountProbesScopeTextProvider? projectUuidTextProvider,
    AccountProbesScopeTextProvider? scriptIdTextProvider,
    AccountProbesFetchProjects fetchProjects = fetchProjects,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider,
       _projectIdTextProvider = projectIdTextProvider ?? _emptyScopeText,
       _projectUuidTextProvider = projectUuidTextProvider ?? _emptyScopeText,
       _scriptIdTextProvider = scriptIdTextProvider ?? _emptyScopeText,
       _fetchProjects = fetchProjects;

  final AccountProbesAccessTokenProvider _accessTokenProvider;
  final AccountProbesErrorSink _onErrorChanged;
  final AccountProbesL10nProvider _l10nProvider;
  final AccountProbesScopeTextProvider _projectIdTextProvider;
  final AccountProbesScopeTextProvider _projectUuidTextProvider;
  final AccountProbesScopeTextProvider _scriptIdTextProvider;
  final AccountProbesFetchProjects _fetchProjects;

  bool loadingMe = false;
  bool loadingDevSwitchProbe = false;
  bool loadingMemoryConfigProbe = false;
  bool loadingAboutProbe = false;
  bool loadingUsageSummary = false;
  String? meBody;
  String? devSwitchProbeBody;
  String? memoryConfigProbeBody;
  String? aboutProbeBody;
  String? usageSummaryBody;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  void reset() {
    loadingMe = false;
    loadingDevSwitchProbe = false;
    loadingMemoryConfigProbe = false;
    loadingAboutProbe = false;
    loadingUsageSummary = false;
    meBody = null;
    devSwitchProbeBody = null;
    memoryConfigProbeBody = null;
    aboutProbeBody = null;
    usageSummaryBody = null;
    notifyListeners();
  }

  Future<void> callMe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingMe = true;
    meBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final response = await fetchMeV1(token);
      final parts = <String>[
        'sub=${response.sub}',
        'plan_tier=${response.planTier}',
      ];
      if (response.email != null && response.email!.isNotEmpty) {
        parts.add('email=${response.email}');
      }
      if (response.billingCurrency != null &&
          response.billingCurrency!.isNotEmpty) {
        parts.add('billing_currency=${response.billingCurrency}');
      }
      if (response.billingProvider != null &&
          response.billingProvider!.isNotEmpty) {
        parts.add('billing_provider=${response.billingProvider}');
      }
      meBody = parts.join(' · ');
    } catch (error) {
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      loadingMe = false;
      notifyListeners();
    }
  }

  Future<void> callUsageSummary() async {
    final token = _accessToken;
    if (token == null) return;
    loadingUsageSummary = true;
    usageSummaryBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final summary = await fetchUsageSummary(token);
      usageSummaryBody =
          'scope=${summary.scope} · '
          'events_last_24h=${summary.eventsLast24h} · '
          'events_last_7d=${summary.eventsLast7d} · '
          'event_counts_last_7d=${summary.eventCountsLast7d}';
    } catch (error) {
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      loadingUsageSummary = false;
      notifyListeners();
    }
  }

  Future<void> callDevSwitchProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingDevSwitchProbe = true;
    devSwitchProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final before = await fetchSwitchAiDevToolV1(token);
      final target = before.value == '1' ? '0' : '1';
      final updated = await putSwitchAiDevToolV1(token, target);
      final after = await fetchSwitchAiDevToolV1(token);
      if (updated.value != target || after.value != target) {
        throw StateError(
          'PUT switch-ai-tool expected value=$target, '
          'got put=${updated.value} get=${after.value}',
        );
      }
      devSwitchProbeBody =
          'GET value=${before.value} · '
          'PUT body {value:$target} -> ${updated.value} · '
          'GET value=${after.value}';
    } catch (error) {
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      loadingDevSwitchProbe = false;
      notifyListeners();
    }
  }

  Future<void> callMemoryConfigProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingMemoryConfigProbe = true;
    memoryConfigProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final original = await fetchMemoryConfigV1(token);
      final probeRag = original.ragLimit == 42 ? 43 : 42;
      final patched = original.copyWith(ragLimit: probeRag);
      final message = await postMemoryConfigV1(token, patched);
      final interim = await fetchMemoryConfigV1(token);
      await postMemoryConfigV1(token, original);
      final restored = await fetchMemoryConfigV1(token);
      if (interim.ragLimit != probeRag) {
        throw StateError(
          'memory-config POST did not stick: ragLimit ${interim.ragLimit}',
        );
      }
      if (restored.ragLimit != original.ragLimit) {
        throw StateError(
          'memory-config restore failed: expected ragLimit '
          '${original.ragLimit}, got ${restored.ragLimit}',
        );
      }
      final line =
          'GET ragLimit=${original.ragLimit} · '
          'POST -> "$message" · '
          'GET ragLimit=${interim.ragLimit} · restored';
      final clearScope = await resolveAccountProbeClearScope(
        token: token,
        projectIdText: _projectIdTextProvider(),
        projectUuidText: _projectUuidTextProvider(),
        scriptIdText: _scriptIdTextProvider(),
        fetchProjects: _fetchProjects,
      );
      final clearStatus = await postSettingsClearAgentMemoriesV1(
        token,
        projectUuid: clearScope.projectUuid,
        projectId: clearScope.projectId,
        agentType: 'scriptAgent',
        episodesId: clearScope.scriptId,
      );
      if (!const [200, 404, 503].contains(clearStatus)) {
        throw StateError(
          'POST clear-agent-memories expected 503/200/404, got '
          '$clearStatus (projectUuid=${clearScope.projectUuid ?? "-"} '
          'numeric id #${clearScope.projectId ?? "-"})',
        );
      }
      final clearNote = switch (clearStatus) {
        503 => '503 no DB',
        200 => '200 ok',
        404 => clearScope.projectUuid != null
            ? '404 no project uuid=${clearScope.projectUuid}'
            : '404 no project numeric#${clearScope.projectId ?? "-"}',
        _ => '$clearStatus',
      };
      memoryConfigProbeBody = '$line · clear-agent-memories -> $clearNote';
    } catch (error) {
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      loadingMemoryConfigProbe = false;
      notifyListeners();
    }
  }

  Future<void> callAboutProbe() async {
    final token = _accessToken;
    if (token == null) return;
    loadingAboutProbe = true;
    aboutProbeBody = null;
    _onErrorChanged(null);
    notifyListeners();
    try {
      final checkUpdate = await postAboutCheckUpdateV1(token, 'openflow');
      final downloadStatus = await postAboutDownloadAppV1(
        token,
        url: 'https://example.com/openflow-setup.dmg',
        reinstall: true,
      );
      if (downloadStatus != 200) {
        throw StateError('POST download-app expected 200, got $downloadStatus');
      }
      aboutProbeBody =
          'check-update: needUpdate=${checkUpdate.needUpdate} '
          'latest=${checkUpdate.latestVersion} · '
          'download-app -> $downloadStatus';
    } catch (error) {
      reportRustOrDescribeApiError(
        error,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      loadingAboutProbe = false;
      notifyListeners();
    }
  }
}

String _emptyScopeText() => '';

int? _parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

String? _trimmedNonEmpty(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}
