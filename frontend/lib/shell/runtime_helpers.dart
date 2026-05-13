// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageRuntimeHelpers on _HomePageState {
  void _setErrorFromException(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _error = describeUserVisibleApiError(l10n, error));
  }
}
