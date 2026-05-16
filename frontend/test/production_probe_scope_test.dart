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
      expect(scope.scriptId, isNull);
      expect(fetchCalls, 1);
    },
  );

  test('production probe scope leaves scope empty when uuid is unknown', () async {
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

    expect(scope.projectId, isNull);
    expect(scope.scriptId, isNull);
  });

  test('production probe resource scope prefers explicit project uuid', () async {
    final resources = await resolveProductionProbeResourceScope(
      token: 'token',
      scope: const ProductionProbeScope(projectId: 23, scriptId: 8),
      projectUuidText: '550e8400-e29b-41d4-a716-446655440777',
      fetchProjects: (token) async => throw StateError('unused'),
      fetchAssets: (
        token,
        projectUuid, {
        int? scriptNumericId,
      }) async {
        expect(projectUuid, '550e8400-e29b-41d4-a716-446655440777');
        expect(scriptNumericId, 8);
        return const ListAssetsResponse(
          items: [
            AssetRow(
              id: 'asset-1',
              numericId: 41,
              name: 'A',
              assetType: 'role',
            ),
          ],
          total: 1,
        );
      },
      fetchStoryboards: (token, projectUuid, scriptNumericId) async {
        expect(projectUuid, '550e8400-e29b-41d4-a716-446655440777');
        expect(scriptNumericId, 8);
        return const [
          StoryboardRow(id: 'sb-1', scriptId: 'script-1', numericId: 51),
        ];
      },
    );

    expect(resources.projectUuid, '550e8400-e29b-41d4-a716-446655440777');
    expect(resources.assetId, 41);
    expect(resources.storyboardId, 51);
  });

  test(
    'production probe resource scope resolves uuid from numeric project id',
    () async {
      var fetchProjectsCalls = 0;
      final resources = await resolveProductionProbeResourceScope(
        token: 'token',
        scope: const ProductionProbeScope(projectId: 77, scriptId: 5),
        projectUuidText: '',
        fetchProjects: (token) async {
          fetchProjectsCalls += 1;
          return const [
            ProjectRow(
              id: '550e8400-e29b-41d4-a716-446655440123',
              numericId: 77,
              projectAccessMode: 'inherited',
              projectAccessRole: 'member',
            ),
          ];
        },
        fetchAssets: (
          token,
          projectUuid, {
          int? scriptNumericId,
        }) async {
          expect(projectUuid, '550e8400-e29b-41d4-a716-446655440123');
          expect(scriptNumericId, 5);
          return const ListAssetsResponse(items: [], total: 0);
        },
        fetchStoryboards: (token, projectUuid, scriptNumericId) async {
          expect(projectUuid, '550e8400-e29b-41d4-a716-446655440123');
          expect(scriptNumericId, 5);
          return const [];
        },
      );

      expect(fetchProjectsCalls, 1);
      expect(resources.projectUuid, '550e8400-e29b-41d4-a716-446655440123');
      expect(resources.assetId, 1);
      expect(resources.storyboardId, 1);
    },
  );

  test('production probe resource scope falls back when lookups fail', () async {
    final resources = await resolveProductionProbeResourceScope(
      token: 'token',
      scope: const ProductionProbeScope(projectId: 77, scriptId: 5),
      projectUuidText: '',
      fetchProjects: (token) async => throw StateError('boom'),
      fetchAssets: (
        token,
        projectUuid, {
        int? scriptNumericId,
      }) async => throw StateError('boom'),
      fetchStoryboards: (token, projectUuid, scriptNumericId) async =>
          throw StateError('boom'),
    );

    expect(resources.projectUuid, isNull);
    expect(resources.assetId, 1);
    expect(resources.storyboardId, 1);
  });
}
