// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

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
    await _skillsHarnessController.closeChannel();
    setState(() {
      _wsLog.clear();
      _taskProjects = null;
      _taskApiJobs = null;
      _taskCategoriesLine = null;
      _taskApiSummaryLine = null;
      _taskDetailNumericIdLine = null;
      _taskDetailUuidLine = null;
      _usageSummaryBody = null;
      _versionBody = null;
      _readyBody = null;
    });
    _skillsHarnessController.reset();
    _projectsController.reset();
    _jobsController.reset();
    _qualityReviewsController.reset();
  }
}
