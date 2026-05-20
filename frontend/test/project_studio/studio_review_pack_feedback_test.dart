import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/studio_review_pack_feedback.dart';
import 'package:openflow_app/rust_api/quality/index.dart';

QualityReview _review({
  required String id,
  required String updatedAt,
  required int storyboardNumericId,
  bool? passed,
  bool isBadCase = false,
  String? comments,
}) {
  return QualityReview(
    id: id,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    userId: 'user-1',
    projectId: 42,
    targetType: 'storyboard',
    targetId: '$storyboardNumericId',
    source: kReviewPackFeedbackSource,
    passed: passed,
    comments: comments,
    isBadCase: isBadCase,
  );
}

void main() {
  test('indexReviewPackFeedbackByStoryboard keeps latest review per shot', () {
    final indexed = indexReviewPackFeedbackByStoryboard(
      <QualityReview>[
        _review(
          id: 'a',
          updatedAt: '2026-01-01T00:00:00Z',
          storyboardNumericId: 7,
          passed: false,
        ),
        _review(
          id: 'b',
          updatedAt: '2026-01-02T00:00:00Z',
          storyboardNumericId: 7,
          passed: true,
          comments: ' LGTM ',
        ),
        _review(
          id: 'c',
          updatedAt: '2026-01-03T00:00:00Z',
          storyboardNumericId: 9,
          isBadCase: true,
        ),
      ],
    );

    expect(indexed[7]?.status, ReviewPackFeedbackStatus.approved);
    expect(indexed[7]?.comment, 'LGTM');
    expect(indexed[9]?.status, ReviewPackFeedbackStatus.flagged);
  });

  test('ReviewPackFeedbackRollup counts statuses across storyboards', () {
    final rollup = ReviewPackFeedbackRollup.forStoryboards(
      storyboardNumericIds: <int>[1, 2, 3],
      byStoryboard: <int, ReviewPackRowFeedback>{
        1: const ReviewPackRowFeedback(
          status: ReviewPackFeedbackStatus.approved,
        ),
        2: const ReviewPackRowFeedback(
          status: ReviewPackFeedbackStatus.needsChanges,
        ),
      },
    );

    expect(rollup.approved, 1);
    expect(rollup.needsChanges, 1);
    expect(rollup.pending, 1);
    expect(rollup.flagged, 0);
  });
}
