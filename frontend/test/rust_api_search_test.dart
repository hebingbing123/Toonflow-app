import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  group('SearchResult', () {
    test('fromJson parses all fields correctly', () {
      final json = <String, dynamic>{
        'id': 'test-id-123',
        'result_type': 'project',
        'title': 'Test Project',
        'snippet': 'This is a <mark>test</mark> snippet',
        'rank': 0.85,
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-02T15:30:00Z',
        'metadata': <String, dynamic>{
          'project_id': 'proj-123',
          'project_name': 'My Project',
        },
      };

      final result = SearchResult.fromJson(json);

      expect(result.id, 'test-id-123');
      expect(result.resultType, ResultType.project);
      expect(result.title, 'Test Project');
      expect(result.snippet, 'This is a <mark>test</mark> snippet');
      expect(result.rank, 0.85);
      expect(result.createdAt, '2024-01-01T10:00:00Z');
      expect(result.updatedAt, '2024-01-02T15:30:00Z');
      expect(result.metadata, isNotNull);
      expect(result.metadata!['project_id'], 'proj-123');
      expect(result.metadata!['project_name'], 'My Project');
    });

    test('fromJson handles null metadata', () {
      final json = <String, dynamic>{
        'id': 'test-id-456',
        'result_type': 'script',
        'title': 'Test Script',
        'snippet': 'Script snippet',
        'rank': 0.75,
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-02T15:30:00Z',
      };

      final result = SearchResult.fromJson(json);

      expect(result.id, 'test-id-456');
      expect(result.resultType, ResultType.script);
      expect(result.metadata, isNull);
    });

    test('toJson serializes all fields correctly', () {
      final result = SearchResult(
        id: 'test-id-789',
        resultType: ResultType.asset,
        title: 'Test Asset',
        snippet: 'Asset <mark>snippet</mark>',
        rank: 0.95,
        createdAt: '2024-01-01T10:00:00Z',
        updatedAt: '2024-01-02T15:30:00Z',
        metadata: <String, dynamic>{
          'asset_type': 'image',
        },
      );

      final json = result.toJson();

      expect(json['id'], 'test-id-789');
      expect(json['result_type'], 'asset');
      expect(json['title'], 'Test Asset');
      expect(json['snippet'], 'Asset <mark>snippet</mark>');
      expect(json['rank'], 0.95);
      expect(json['created_at'], '2024-01-01T10:00:00Z');
      expect(json['updated_at'], '2024-01-02T15:30:00Z');
      expect(json['metadata'], isNotNull);
      expect(json['metadata']['asset_type'], 'image');
    });
  });

  group('SearchResponse', () {
    test('fromJson parses response with results', () {
      final json = <String, dynamic>{
        'results': [
          <String, dynamic>{
            'id': 'result-1',
            'result_type': 'project',
            'title': 'Project 1',
            'snippet': 'Snippet 1',
            'rank': 0.9,
            'created_at': '2024-01-01T10:00:00Z',
            'updated_at': '2024-01-02T15:30:00Z',
          },
          <String, dynamic>{
            'id': 'result-2',
            'result_type': 'script',
            'title': 'Script 1',
            'snippet': 'Snippet 2',
            'rank': 0.8,
            'created_at': '2024-01-01T11:00:00Z',
            'updated_at': '2024-01-02T16:30:00Z',
          },
        ],
        'total': 25,
        'page': 1,
        'page_size': 20,
        'has_more': true,
      };

      final response = SearchResponse.fromJson(json);

      expect(response.results.length, 2);
      expect(response.results[0].id, 'result-1');
      expect(response.results[0].resultType, ResultType.project);
      expect(response.results[1].id, 'result-2');
      expect(response.results[1].resultType, ResultType.script);
      expect(response.total, 25);
      expect(response.page, 1);
      expect(response.pageSize, 20);
      expect(response.hasMore, true);
    });

    test('fromJson handles empty results', () {
      final json = <String, dynamic>{
        'results': [],
        'total': 0,
        'page': 1,
        'page_size': 20,
        'has_more': false,
      };

      final response = SearchResponse.fromJson(json);

      expect(response.results, isEmpty);
      expect(response.total, 0);
      expect(response.page, 1);
      expect(response.pageSize, 20);
      expect(response.hasMore, false);
    });

    test('toJson serializes correctly', () {
      final response = SearchResponse(
        results: [
          SearchResult(
            id: 'test-1',
            resultType: ResultType.project,
            title: 'Test',
            snippet: 'Snippet',
            rank: 0.9,
            createdAt: '2024-01-01T10:00:00Z',
            updatedAt: '2024-01-02T15:30:00Z',
          ),
        ],
        total: 1,
        page: 1,
        pageSize: 20,
        hasMore: false,
      );

      final json = response.toJson();

      expect(json['results'], isA<List>());
      expect((json['results'] as List).length, 1);
      expect(json['total'], 1);
      expect(json['page'], 1);
      expect(json['page_size'], 20);
      expect(json['has_more'], false);
    });
  });

  group('HistoryEntry', () {
    test('fromJson parses all fields correctly', () {
      final json = <String, dynamic>{
        'id': 'history-123',
        'query': 'test search',
        'result_count': 15,
        'searched_at': '2024-01-01T10:00:00Z',
      };

      final entry = HistoryEntry.fromJson(json);

      expect(entry.id, 'history-123');
      expect(entry.query, 'test search');
      expect(entry.resultCount, 15);
      expect(entry.searchedAt, '2024-01-01T10:00:00Z');
    });

    test('toJson serializes correctly', () {
      final entry = HistoryEntry(
        id: 'history-456',
        query: 'another search',
        resultCount: 8,
        searchedAt: '2024-01-02T12:00:00Z',
      );

      final json = entry.toJson();

      expect(json['id'], 'history-456');
      expect(json['query'], 'another search');
      expect(json['result_count'], 8);
      expect(json['searched_at'], '2024-01-02T12:00:00Z');
    });
  });

  group('HistoryResponse', () {
    test('fromJson parses history list', () {
      final json = <String, dynamic>{
        'history': [
          <String, dynamic>{
            'id': 'h1',
            'query': 'search 1',
            'result_count': 10,
            'searched_at': '2024-01-01T10:00:00Z',
          },
          <String, dynamic>{
            'id': 'h2',
            'query': 'search 2',
            'result_count': 5,
            'searched_at': '2024-01-01T11:00:00Z',
          },
        ],
      };

      final response = HistoryResponse.fromJson(json);

      expect(response.history.length, 2);
      expect(response.history[0].id, 'h1');
      expect(response.history[0].query, 'search 1');
      expect(response.history[1].id, 'h2');
      expect(response.history[1].query, 'search 2');
    });

    test('fromJson handles empty history', () {
      final json = <String, dynamic>{
        'history': [],
      };

      final response = HistoryResponse.fromJson(json);

      expect(response.history, isEmpty);
    });
  });

  group('ResultType', () {
    test('toJson returns correct string', () {
      expect(ResultType.project.toJson(), 'project');
      expect(ResultType.script.toJson(), 'script');
      expect(ResultType.asset.toJson(), 'asset');
    });

    test('fromJson parses valid types', () {
      expect(ResultType.fromJson('project'), ResultType.project);
      expect(ResultType.fromJson('script'), ResultType.script);
      expect(ResultType.fromJson('asset'), ResultType.asset);
    });

    test('fromJson throws on invalid type', () {
      expect(
        () => ResultType.fromJson('invalid'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('CancellationToken', () {
    test('initial state is not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, false);
    });

    test('cancel sets isCancelled to true', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('cancel is idempotent', () {
      final token = CancellationToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, true);
    });

    test('executeWithCancellation throws when already cancelled', () async {
      final token = CancellationToken();
      token.cancel();

      expect(
        () => token.executeWithCancellation(() async => 'result'),
        throwsA(
          isA<RustApiException>().having(
            (e) => e.message,
            'message',
            '请求已取消',
          ),
        ),
      );
    });

    test('executeWithCancellation completes normally when not cancelled',
        () async {
      final token = CancellationToken();

      final result = await token.executeWithCancellation(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 'success';
      });

      expect(result, 'success');
    });

    test('executeWithCancellation throws when cancelled during execution',
        () async {
      final token = CancellationToken();

      final future = token.executeWithCancellation(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'should not complete';
      });

      // Cancel after a short delay
      Future.delayed(const Duration(milliseconds: 10), token.cancel);

      expect(
        () => future,
        throwsA(
          isA<RustApiException>().having(
            (e) => e.message,
            'message',
            '请求已取消',
          ),
        ),
      );
    });
  });
}
