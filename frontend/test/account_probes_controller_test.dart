import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/system_probes/account/controller.dart';

void main() {
  test('account probe clear scope prefers explicit workspace inputs', () async {
    var fetchCalls = 0;
    final scope = await resolveAccountProbeClearScope(
      token: 'token',
      projectIdText: '23',
      projectUuidText: '550e8400-e29b-41d4-a716-446655440000',
      scriptIdText: '8',
      fetchProjects: (token) async {
        fetchCalls += 1;
        return const <ProjectRow>[];
      },
    );

    expect(scope.projectId, 23);
    expect(scope.projectUuid, '550e8400-e29b-41d4-a716-446655440000');
    expect(scope.scriptId, 8);
    expect(fetchCalls, 0);
  });

  test('account probe clear scope falls back to first visible project', () async {
    var fetchCalls = 0;
    final scope = await resolveAccountProbeClearScope(
      token: 'token',
      projectIdText: '',
      projectUuidText: '',
      scriptIdText: '',
      fetchProjects: (token) async {
        fetchCalls += 1;
        return const <ProjectRow>[
          ProjectRow(
            id: '550e8400-e29b-41d4-a716-446655440123',
            numericId: 77,
            projectAccessMode: 'inherited',
            projectAccessRole: 'member',
          ),
        ];
      },
    );

    expect(fetchCalls, 1);
    expect(scope.projectId, 77);
    expect(scope.projectUuid, '550e8400-e29b-41d4-a716-446655440123');
    expect(scope.scriptId, isNull);
  });

  test('account probe clear scope keeps legacy fallback when probing fails', () async {
    final scope = await resolveAccountProbeClearScope(
      token: 'token',
      projectIdText: '',
      projectUuidText: '',
      scriptIdText: '0',
      fetchProjects: (token) async => throw RustApiException('boom'),
    );

    expect(scope.projectId, 1);
    expect(scope.projectUuid, isNull);
    expect(scope.scriptId, isNull);
  });
}
