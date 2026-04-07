// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageOverviewController on _HomePageState {
  Future<void> _pingHealth() async {
    setState(() {
      _loadingHealth = true;
      _error = null;
      _healthBody = null;
    });
    try {
      final h = await fetchHealthV1();
      if (!mounted) return;
      setState(() {
        _healthBody = 'status=${h.status} service=${h.service}';
        _loadingHealth = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealth = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealth = false;
      });
    }
  }

  Future<void> _pingHealthRoot() async {
    setState(() {
      _loadingHealthRoot = true;
      _error = null;
      _healthRootBody = null;
    });
    try {
      final h = await fetchHealthRoot();
      if (!mounted) return;
      setState(() {
        _healthRootBody = 'status=${h.status} service=${h.service}';
        _loadingHealthRoot = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealthRoot = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHealthRoot = false;
      });
    }
  }

  Future<void> _pingPing() async {
    setState(() {
      _loadingPing = true;
      _error = null;
      _pingBody = null;
    });
    try {
      final p = await fetchPingV1();
      if (!mounted) return;
      setState(() {
        _pingBody = 'ok=${p.ok}';
        _loadingPing = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingPing = false;
      });
    }
  }

  Future<void> _pingVersion() async {
    setState(() {
      _loadingVersion = true;
      _error = null;
      _versionBody = null;
    });
    try {
      final v = await fetchVersionV1();
      if (!mounted) return;
      final parts = <String>['service=${v.service}', 'version=${v.version}'];
      if (v.gitSha != null && v.gitSha!.isNotEmpty) {
        parts.add('git_sha=${v.gitSha}');
      }
      setState(() {
        _versionBody = parts.join(' · ');
        _loadingVersion = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVersion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingVersion = false;
      });
    }
  }

  Future<void> _pingReady() async {
    setState(() {
      _loadingReady = true;
      _error = null;
      _readyBody = null;
    });
    try {
      final r = await fetchReadyV1();
      if (!mounted) return;
      setState(() {
        _readyBody = 'status=${r.status}, database=${r.database}';
        _loadingReady = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingReady = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingReady = false;
      });
    }
  }
}
