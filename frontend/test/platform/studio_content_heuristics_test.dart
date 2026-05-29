import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_content_heuristics.dart';

void main() {
  test('studioProjectModeLooksLiveAction matches zh and en tokens', () {
    expect(studioProjectModeLooksLiveAction('live_action.short_drama'), isTrue);
    expect(studioProjectModeLooksLiveAction('真人短剧'), isTrue);
    expect(studioProjectModeLooksLiveAction('animated.short_drama'), isFalse);
  });

  test('studioTaskMessageLooksLikeWritebackFailure matches en and zh tokens', () {
    expect(studioTaskMessageLooksLikeWritebackFailure('writeback failed'), isTrue);
    expect(studioTaskMessageLooksLikeWritebackFailure('视频写回超时'), isTrue);
    expect(studioTaskMessageLooksLikeWritebackFailure('network error'), isFalse);
  });

  test('studioNormalizeProductionStoryboardTableColumn maps zh headers', () {
    expect(studioNormalizeProductionStoryboardTableColumn('序号'), 'id');
    expect(studioNormalizeProductionStoryboardTableColumn('画面描述'), 'description');
  });
}
