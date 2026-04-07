// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageAuthSessionController on _HomePageState {
  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signUp() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    _wsSub?.cancel();
    _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    setState(() {
      _wsLog.clear();
      _projects = null;
      _creatingProject = false;
      _jobs = null;
      _jobByIdLine = null;
      _usageSummaryBody = null;
      _agentMemoryBody = null;
      _versionBody = null;
      _readyBody = null;
      _harnessToolsLine = null;
      _skillsAggregateLine = null;
      _skillsListSummary = null;
    });
  }
}
