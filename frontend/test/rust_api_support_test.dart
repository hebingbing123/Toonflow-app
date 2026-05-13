import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('buildProjectStyleConfigPatchBody keeps partial update semantics', () {
    expect(
      buildProjectStyleConfigPatchBody(
        artStylePack: 'art_skills/realpeople_ancient_chinese',
      ),
      <String, dynamic>{
        'artStylePack': 'art_skills/realpeople_ancient_chinese',
      },
    );
    expect(
      buildProjectStyleConfigPatchBody(storyStylePack: null),
      <String, dynamic>{'storyStylePack': null},
    );
  });

  test('agent memory cost overview parses counts and timestamps', () {
    final overview = AgentMemoryCostOverview.fromJson(<String, dynamic>{
      'scope': 'user',
      'projectId': 7,
      'styleBibleCount': 1,
      'stageSummaryCount': 2,
      'deltaMemoryCount': 3,
      'messageCount': 4,
      'avgInjectedCharsLast30': 128,
      'avgHitTierCountLast30': 3,
      'lastInjectedAt': '2026-05-01T10:00:00.000Z',
    });

    expect(overview.scope, 'user');
    expect(overview.projectId, 7);
    expect(overview.styleBibleCount, 1);
    expect(overview.stageSummaryCount, 2);
    expect(overview.deltaMemoryCount, 3);
    expect(overview.messageCount, 4);
    expect(overview.avgInjectedCharsLast30, 128);
    expect(overview.avgHitTierCountLast30, 3);
    expect(overview.lastInjectedAt, '2026-05-01T10:00:00.000Z');
  });

  test('rollback skill version response parses camelCase payload', () {
    final response = RollbackSkillVersionResponse.fromJson(<String, dynamic>{
      'newVersionId': 'version-new',
      'filePath': 'story_skills/sweet_romance.md',
      'rolledBackFrom': 'version-current',
      'rolledBackTo': 'version-target',
      'hashAfter': 'abc123',
    });

    expect(response.newVersionId, 'version-new');
    expect(response.filePath, 'story_skills/sweet_romance.md');
    expect(response.rolledBackFrom, 'version-current');
    expect(response.rolledBackTo, 'version-target');
    expect(response.hashAfter, 'abc123');
  });

  test('429 formatter includes human wait time from retryAfterMs', () {
    final l10nZh = lookupAppLocalizations(const Locale('zh'));
    final message = formatRustApiExceptionForDisplay(
      l10nZh,
      RustApiException(
        '{"code":"quota_exceeded","message":"limit reached","retry_after_ms":61000}',
        statusCode: 429,
      ),
    );

    expect(message, '配额或频率已用尽，1 分 1 秒后重试。');
    expect(formatRetryAfterMsForDisplay(l10nZh, 0), '请稍后重试');
  });

  test('concurrent_limit_exceeded uses dedicated message not quota retry text', () {
    final l10nZh = lookupAppLocalizations(const Locale('zh'));
    final message = formatRustApiExceptionForDisplay(
      l10nZh,
      RustApiException(
        '{"code":"concurrent_limit_exceeded","message":"too many in flight"}',
        statusCode: 429,
      ),
    );

    expect(
      message,
      '同时进行的工作区审计导出已达上限，请等待已有任务完成或结束后再试。',
    );
  });
}
