import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('parseScriptAgentPlanDataResponse handles wrapped persisted shape', () {
    final plan = parseScriptAgentPlanDataResponse({
      'code': 200,
      'data': {
        'id': 18,
        'data': {
          'storySkeleton': '三幕结构',
          'adaptationStrategy': '先压后扬',
          'script': [
            {'id': 7, 'name': '第1集', 'content': '正文'},
          ],
        },
      },
    });

    expect(plan.planId, 18);
    expect(plan.storySkeleton, '三幕结构');
    expect(plan.adaptationStrategy, '先压后扬');
    expect(plan.scriptRows.length, 1);
    expect(plan.scriptRows.first.name, '第1集');
  });

  test('parseScriptAgentPlanDataResponse handles bootstrap flat shape', () {
    final plan = parseScriptAgentPlanDataResponse({
      'code': 200,
      'data': {'storySkeleton': '', 'adaptationStrategy': ''},
    });

    expect(plan.planId, isNull);
    expect(plan.storySkeleton, '');
    expect(plan.adaptationStrategy, '');
    expect(plan.scriptRows, isEmpty);
  });
}
