import '../l10n/app_localizations.dart';
import '../rust_api/quality/index.dart';

/// Stable [QualityReview.source] for creator review-pack team feedback (T8).
const String kReviewPackFeedbackSource = 'review_pack';

enum ReviewPackFeedbackStatus { pending, approved, needsChanges, flagged }

class ReviewPackRowFeedback {
  const ReviewPackRowFeedback({
    required this.status,
    this.comment,
    this.reviewId,
  });

  final ReviewPackFeedbackStatus status;
  final String? comment;
  final String? reviewId;
}

class ReviewPackFeedbackRollup {
  const ReviewPackFeedbackRollup({
    required this.approved,
    required this.needsChanges,
    required this.flagged,
    required this.pending,
  });

  final int approved;
  final int needsChanges;
  final int flagged;
  final int pending;

  factory ReviewPackFeedbackRollup.forStoryboards({
    required Iterable<int> storyboardNumericIds,
    required Map<int, ReviewPackRowFeedback> byStoryboard,
  }) {
    var approved = 0;
    var needsChanges = 0;
    var flagged = 0;
    var pending = 0;
    for (final id in storyboardNumericIds) {
      switch (byStoryboard[id]?.status ?? ReviewPackFeedbackStatus.pending) {
        case ReviewPackFeedbackStatus.approved:
          approved++;
        case ReviewPackFeedbackStatus.needsChanges:
          needsChanges++;
        case ReviewPackFeedbackStatus.flagged:
          flagged++;
        case ReviewPackFeedbackStatus.pending:
          pending++;
      }
    }
    return ReviewPackFeedbackRollup(
      approved: approved,
      needsChanges: needsChanges,
      flagged: flagged,
      pending: pending,
    );
  }
}

ReviewPackFeedbackStatus reviewPackStatusFromReview(QualityReview review) {
  if (review.isBadCase) {
    return ReviewPackFeedbackStatus.flagged;
  }
  if (review.passed == true) {
    return ReviewPackFeedbackStatus.approved;
  }
  if (review.passed == false) {
    return ReviewPackFeedbackStatus.needsChanges;
  }
  return ReviewPackFeedbackStatus.pending;
}

/// Latest `review_pack` review per storyboard numeric id (by [QualityReview.updatedAt]).
Map<int, ReviewPackRowFeedback> indexReviewPackFeedbackByStoryboard(
  List<QualityReview> reviews,
) {
  final latest = <int, QualityReview>{};
  for (final review in reviews) {
    if (review.source != kReviewPackFeedbackSource) {
      continue;
    }
    if (review.targetType != 'storyboard') {
      continue;
    }
    final numericId = int.tryParse((review.targetId ?? '').trim());
    if (numericId == null || numericId <= 0) {
      continue;
    }
    final existing = latest[numericId];
    if (existing == null || review.updatedAt.compareTo(existing.updatedAt) > 0) {
      latest[numericId] = review;
    }
  }

  return latest.map(
    (int id, QualityReview review) => MapEntry<int, ReviewPackRowFeedback>(
      id,
      ReviewPackRowFeedback(
        status: reviewPackStatusFromReview(review),
        comment: review.comments?.trim().isEmpty == true
            ? null
            : review.comments?.trim(),
        reviewId: review.id,
      ),
    ),
  );
}

String reviewPackFeedbackStatusLabel(
  AppLocalizations l10n,
  ReviewPackFeedbackStatus status,
) {
  switch (status) {
    case ReviewPackFeedbackStatus.pending:
      return l10n.studioReviewPackFeedbackPending;
    case ReviewPackFeedbackStatus.approved:
      return l10n.studioReviewPackFeedbackApproved;
    case ReviewPackFeedbackStatus.needsChanges:
      return l10n.studioReviewPackFeedbackNeedsChanges;
    case ReviewPackFeedbackStatus.flagged:
      return l10n.studioReviewPackFeedbackFlagged;
  }
}
