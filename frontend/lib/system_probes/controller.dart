// ignore_for_file: invalid_use_of_protected_member

part of '../../home_page.dart';

extension _HomePageSystemProbesController on _HomePageState {
  String _formatProbeStatusMap(Map<String, int> statuses) {
    return statuses.entries
        .map((entry) => '${entry.key}->${entry.value}')
        .join(' · ');
  }
}
