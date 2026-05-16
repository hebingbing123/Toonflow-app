part of '../../../home_page.dart';

typedef SettingsProbeFetchAgentDeployList =
    Future<List<AgentDeployListItemV1>> Function(String token);

Future<int> resolveSettingsProbeAgentDeployId({
  required String token,
  required SettingsProbeFetchAgentDeployList fetchAgentDeployList,
  int fallbackId = 1,
}) async {
  try {
    final items = await fetchAgentDeployList(token);
    if (items.isNotEmpty) {
      return items.first.id;
    }
  } catch (_) {}
  return fallbackId;
}
