// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageSystemProbesAccountSettings on _HomePageState {
  Future<void> _callDevSwitchProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingDevSwitchProbe = true;
      _error = null;
      _devSwitchProbeBody = null;
    });
    try {
      final g = await fetchSwitchAiDevToolV1(token);
      final target = g.value == '1' ? '0' : '1';
      final put = await putSwitchAiDevToolV1(token, target);
      final after = await fetchSwitchAiDevToolV1(token);
      if (!mounted) return;
      if (put.value != target || after.value != target) {
        setState(() {
          _error =
              'PUT switch-ai-tool expected value=$target, got put=${put.value} get=${after.value}';
          _loadingDevSwitchProbe = false;
        });
        return;
      }
      setState(() {
        _devSwitchProbeBody =
            'GET value=${g.value} · PUT body {value:$target} -> ${put.value} · GET value=${after.value}';
        _loadingDevSwitchProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDevSwitchProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingDevSwitchProbe = false;
      });
    }
  }

  Future<void> _callMemoryConfigProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingMemoryConfigProbe = true;
      _error = null;
      _memoryConfigProbeBody = null;
    });
    try {
      final orig = await fetchMemoryConfigV1(token);
      final probeRag = orig.ragLimit == 42 ? 43 : 42;
      final patched = orig.copyWith(ragLimit: probeRag);
      final msg = await postMemoryConfigV1(token, patched);
      final mid = await fetchMemoryConfigV1(token);
      await postMemoryConfigV1(token, orig);
      final fin = await fetchMemoryConfigV1(token);
      if (!mounted) return;
      if (mid.ragLimit != probeRag) {
        setState(() {
          _error = 'memory-config POST did not stick: ragLimit ${mid.ragLimit}';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      if (fin.ragLimit != orig.ragLimit) {
        setState(() {
          _error =
              'memory-config restore failed: expected ragLimit ${orig.ragLimit}, got ${fin.ragLimit}';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      final line =
          'GET ragLimit=${orig.ragLimit} · POST -> "$msg" · GET ragLimit=${mid.ragLimit} · restored';
      var legacyForClear = 1;
      try {
        final plist = await fetchProjects(token);
        if (plist.isNotEmpty) {
          legacyForClear = plist.first.legacyId;
        }
      } on RustApiException catch (_) {
        // Keep default **1** (often **404** when DB up but empty / no such legacy).
      }
      final clr = await postSettingsClearAgentMemoriesV1(
        token,
        projectId: legacyForClear,
        agentType: 'scriptAgent',
      );
      if (!mounted) return;
      final okClear = clr == 503 || clr == 200 || clr == 404;
      if (!okClear) {
        setState(() {
          _error =
              'POST clear-agent-memories expected 503/200/404, got $clr (legacy #$legacyForClear)';
          _loadingMemoryConfigProbe = false;
        });
        return;
      }
      final clearNote = switch (clr) {
        503 => '503 no DB',
        200 => '200 ok',
        404 => '404 no project legacy#$legacyForClear',
        _ => '$clr',
      };
      setState(() {
        _memoryConfigProbeBody = '$line · clear-agent-memories -> $clearNote';
        _loadingMemoryConfigProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMemoryConfigProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingMemoryConfigProbe = false;
      });
    }
  }

  Future<void> _callAboutProbe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingAboutProbe = true;
      _error = null;
      _aboutProbeBody = null;
    });
    try {
      final cu = await postAboutCheckUpdateV1(token, 'toonflow');
      final dl = await postAboutDownloadAppV1(
        token,
        url: 'https://example.com/toonflow-setup.dmg',
        reinstall: true,
      );
      if (!mounted) return;
      if (dl != 200) {
        setState(() {
          _error = 'POST download-app expected 200, got $dl';
          _loadingAboutProbe = false;
        });
        return;
      }
      setState(() {
        _aboutProbeBody =
            'check-update: needUpdate=${cu.needUpdate} latest=${cu.latestVersion} · download-app -> $dl';
        _loadingAboutProbe = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAboutProbe = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingAboutProbe = false;
      });
    }
  }
}
