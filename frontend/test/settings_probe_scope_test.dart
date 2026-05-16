import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('settings probe agent deploy id prefers first real deploy row', () async {
    var fetchCalls = 0;
    final id = await resolveSettingsProbeAgentDeployId(
      token: 'token',
      fetchAgentDeployList: (token) async {
        fetchCalls += 1;
        return const [
          AgentDeployListItemV1(
            id: 23,
            model: 'm',
            key: 'k',
            modelName: 'mn',
            vendorId: null,
            desc: 'd',
            name: 'n',
            disabled: false,
            icon: 'i',
          ),
        ];
      },
    );

    expect(fetchCalls, 1);
    expect(id, 23);
  });

  test('settings probe agent deploy id falls back when list is empty', () async {
    final id = await resolveSettingsProbeAgentDeployId(
      token: 'token',
      fetchAgentDeployList: (token) async => const [],
    );

    expect(id, 1);
  });

  test('settings probe agent deploy id falls back when list fails', () async {
    final id = await resolveSettingsProbeAgentDeployId(
      token: 'token',
      fetchAgentDeployList: (token) async => throw RustApiException('boom'),
    );

    expect(id, 1);
  });
}
