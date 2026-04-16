// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageRuntimeHelpers on _HomePageState {
  Session? get _session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;

  void _setErrorFromException(Object error) {
    if (!mounted) return;
    setState(() => _error = error.toString());
  }
}
