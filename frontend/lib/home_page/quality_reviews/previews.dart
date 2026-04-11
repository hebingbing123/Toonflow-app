import 'package:flutter/material.dart';

import '../../rust_api.dart';

class QualityReviewsCompatibilityPanel extends StatelessWidget {
  const QualityReviewsCompatibilityPanel({
    super.key,
    required this.outlineColor,
    required this.creatingQualityReview,
    required this.onCreateQualityReviewProbe,
  });

  final Color outlineColor;
  final bool creatingQualityReview;
  final VoidCallback onCreateQualityReviewProbe;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '保留质量评审回归创建入口，默认折叠',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Legacy review probe',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: outlineColor),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: creatingQualityReview ? null : onCreateQualityReviewProbe,
              child: Text(creatingQualityReview ? '…' : '创建回归评审'),
            ),
          ],
        ),
      ],
    );
  }
}

class QualityReviewsListPreview extends StatelessWidget {
  const QualityReviewsListPreview({
    super.key,
    required this.reviews,
    required this.onSelectQualityReview,
  });

  final List<QualityReview> reviews;
  final ValueChanged<QualityReview> onSelectQualityReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('${reviews.length} 条评审', style: Theme.of(context).textTheme.labelLarge),
        ...reviews.take(8).map(
          (review) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
            ),
            subtitle: Text(
              [
                review.id,
                if (review.targetId != null && review.targetId!.isNotEmpty)
                  'target=${review.targetId}',
                if (review.passed != null) 'passed=${review.passed}',
                if (review.isBadCase) 'bad_case',
              ].join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelectQualityReview(review),
          ),
        ),
      ],
    );
  }
}
