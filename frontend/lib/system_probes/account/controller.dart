import 'package:flutter/material.dart';

import '../../rust_api.dart';

typedef AccountProbesAccessTokenProvider = String? Function();
typedef AccountProbesErrorSink = void Function(String? error);

class AccountProbesController extends ChangeNotifier {
  AccountProbesController({
    required AccountProbesAccessTokenProvider accessTokenProvider,
    required AccountProbesErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final AccountProbesAccessTokenProvider _accessTokenProvider;
  final AccountProbesErrorSink _onErrorChanged;

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
    } on RustApiException catch (error) {
      _onErrorChanged(error.toString());
    } catch (error) {
      _onErrorChanged(error.toString());
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
          'events_last_24h=${summary.eventsLast24h} · '
          'events_last_7d=${summary.eventsLast7d} · '
          'event_counts_last_7d=${summary.eventCountsLast7d}';
    } on RustApiException catch (error) {
      _onErrorChanged(error.toString());
    } catch (error) {
      _onErrorChanged(error.toString());
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
    } on RustApiException catch (error) {
      _onErrorChanged(error.toString());
    } catch (error) {
      _onErrorChanged(error.toString());
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
      var numericIdForClear = 1;
      String? uuidForClear;
      try {
        final projects = await fetchProjects(token);
        if (projects.isNotEmpty) {
          numericIdForClear = projects.first.numericId;
          uuidForClear = projects.first.id;
        }
      } on RustApiException catch (_) {
        // Keep default project id 1 when project probing is unavailable.
      }
      final clearStatus = await postSettingsClearAgentMemoriesV1(
        token,
        projectUuid: uuidForClear,
        projectId: uuidForClear != null ? null : numericIdForClear,
        agentType: 'scriptAgent',
      );
      if (!const [200, 404, 503].contains(clearStatus)) {
        throw StateError(
          'POST clear-agent-memories expected 503/200/404, got '
          '$clearStatus (numeric id #$numericIdForClear)',
        );
      }
      final clearNote = switch (clearStatus) {
        503 => '503 no DB',
        200 => '200 ok',
        404 => '404 no project numeric#$numericIdForClear',
        _ => '$clearStatus',
      };
      memoryConfigProbeBody = '$line · clear-agent-memories -> $clearNote';
    } on RustApiException catch (error) {
      _onErrorChanged(error.toString());
    } catch (error) {
      _onErrorChanged(error.toString());
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
        throw StateError(
          'POST download-app expected 200, got $downloadStatus',
        );
      }
      aboutProbeBody =
          'check-update: needUpdate=${checkUpdate.needUpdate} '
          'latest=${checkUpdate.latestVersion} · '
          'download-app -> $downloadStatus';
    } on RustApiException catch (error) {
      _onErrorChanged(error.toString());
    } catch (error) {
      _onErrorChanged(error.toString());
    } finally {
      loadingAboutProbe = false;
      notifyListeners();
    }
  }
}
