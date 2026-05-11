import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/system_probes/models_catalog/production_probe_scope.dart';

void main() {
  test('production probe scope keeps explicit numeric ids', () async {
    var fetchCalls = 0;
    final scope = await resolveProductionProbeScope(
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
    expect(scope.scriptId, 8);
    expect(fetchCalls, 0);
  });

  test(
    'production probe scope resolves numeric project id from project uuid',
    () async {
      var fetchCalls = 0;
      final scope = await resolveProductionProbeScope(
        token: 'token',
        projectIdText: '',
        projectUuidText: '550e8400-e29b-41d4-a716-446655440123',
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

      expect(scope.projectId, 77);
      expect(scope.scriptId, 1);
      expect(fetchCalls, 1);
    },
  );

  test('production probe scope falls back when uuid is unknown', () async {
    final scope = await resolveProductionProbeScope(
      token: 'token',
      projectIdText: '',
      projectUuidText: '550e8400-e29b-41d4-a716-446655440999',
      scriptIdText: '0',
      fetchProjects: (token) async => const <ProjectRow>[
        ProjectRow(
          id: '550e8400-e29b-41d4-a716-446655440123',
          numericId: 77,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ],
    );

    expect(scope.projectId, 1);
    expect(scope.scriptId, 1);
  });
}
