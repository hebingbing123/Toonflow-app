import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_primary_button.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api/project/overview_api.dart';
import '../rust_api/project/overview_models.dart';
import '../rust_api/project/overview_models_assembly.dart';
import '../rust_api/quality/index.dart';
import 'creator_journey_telemetry.dart';
import 'studio_review_pack_export_bridge.dart';
import 'studio_review_pack_feedback.dart';
import 'studio_review_pack_storyboard_row.dart';
import 'studio_review_pack_team_summary.dart';
import 'studio_step.dart';

/// Standalone “review pack” surface: lists storyboards with short-video readiness.
class StudioReviewPackScope extends StatefulWidget {
  const StudioReviewPackScope({
    super.key,
    required this.accessToken,
    required this.projectNumericId,
    required this.projectUuid,
    this.projectName,
  });

  final String accessToken;
  final int projectNumericId;
  final String projectUuid;
  final String? projectName;

  @override
  State<StudioReviewPackScope> createState() => _StudioReviewPackScopeState();
}

class _StudioReviewPackScopeState extends State<StudioReviewPackScope> {
  var _loading = true;
  Object? _error;
  ProjectShortVideoReadiness? _readiness;
  ProjectProductionOverview? _production;
  ProjectShortVideoExportCheck? _exportCheck;
  var _exportCheckLoadFailed = false;
  Map<int, ReviewPackRowFeedback> _feedbackByStoryboard =
      const <int, ReviewPackRowFeedback>{};
  var _submittingFeedback = false;

  @override
  void initState() {
    super.initState();
    CreatorJourneyTelemetry.bindProject(
      accessToken: widget.accessToken,
      projectUuid: widget.projectUuid,
      projectNumericId: widget.projectNumericId,
    );
    CreatorJourneyTelemetry.record(
      CreatorJourneyEvent(
        'review_pack_view',
        <String, Object?>{'project_id': widget.projectNumericId},
      ),
    );
    _load();
  }

  @override
  void dispose() {
    CreatorJourneyTelemetry.clearProject();
    super.dispose();
  }

  Future<void> _load({bool isRetry = false}) async {
    if (isRetry) {
      CreatorJourneyTelemetry.record(
        CreatorJourneyEvent(
          'review_pack_retry',
          <String, Object?>{'project_id': widget.projectNumericId},
        ),
      );
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final readiness = await fetchProjectShortVideoReadinessByProjectId(
        widget.accessToken,
        widget.projectUuid,
      );
      ProjectProductionOverview? production;
      ProjectShortVideoExportCheck? exportCheck;
      var exportCheckLoadFailed = false;
      try {
        production = await fetchProjectProductionOverviewByProjectId(
          widget.accessToken,
          widget.projectUuid,
        );
      } catch (_) {}
      try {
        exportCheck = await fetchProjectShortVideoExportCheckByProjectId(
          widget.accessToken,
          widget.projectUuid,
        );
      } catch (_) {
        exportCheckLoadFailed = true;
      }
      List<QualityReview> teamReviews = const <QualityReview>[];
      try {
        teamReviews = await fetchQualityReviews(
          widget.accessToken,
          projectId: widget.projectNumericId,
          targetType: 'storyboard',
          source: kReviewPackFeedbackSource,
          limit: 500,
        );
      } catch (_) {}
      final feedbackByStoryboard = indexReviewPackFeedbackByStoryboard(
        teamReviews,
      );
      if (!mounted) return;
      CreatorJourneyTelemetry.record(
        CreatorJourneyEvent(
          'review_pack_load_ok',
          <String, Object?>{
            'project_id': widget.projectNumericId,
            'storyboard_count': readiness.storyboards.length,
            'export_ready': exportCheck?.exportReady,
            'blocking_issues': exportCheck?.summary.blockingIssueCount,
            'feedback_rows': feedbackByStoryboard.length,
            if (isRetry) 'retry': true,
          },
        ),
      );
      setState(() {
        _readiness = readiness;
        _production = production;
        _exportCheck = exportCheck;
        _exportCheckLoadFailed = exportCheckLoadFailed;
        _feedbackByStoryboard = feedbackByStoryboard;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      CreatorJourneyTelemetry.record(
        CreatorJourneyEvent(
          'review_pack_load_error',
          <String, Object?>{
            'project_id': widget.projectNumericId,
            if (isRetry) 'retry': true,
          },
        ),
      );
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _submitReviewPackFeedback({
    required StoryboardShortVideoReadiness row,
    required ReviewPackFeedbackStatus status,
    String? comment,
  }) async {
    if (_submittingFeedback) {
      return;
    }
    setState(() => _submittingFeedback = true);
    try {
      await createQualityReview(
        widget.accessToken,
        CreateQualityReviewBody(
          targetType: 'storyboard',
          projectId: widget.projectNumericId,
          scriptId: row.scriptNumericId,
          targetId: '${row.storyboardNumericId}',
          source: kReviewPackFeedbackSource,
          stage: 'review_pack',
          passed: status == ReviewPackFeedbackStatus.approved
              ? true
              : status == ReviewPackFeedbackStatus.needsChanges
              ? false
              : null,
          isBadCase: status == ReviewPackFeedbackStatus.flagged,
          comments: comment,
        ),
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.studioReviewPackFeedbackSaved),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingFeedback = false);
      }
    }
  }

  String _shareablePath() {
    return '/projects/${widget.projectNumericId}/review-pack';
  }

  String _shareableLinkText() {
    final pathOnly = _shareablePath();
    try {
      final base = Uri.base;
      if (base.hasScheme && base.host.isNotEmpty) {
        return base.replace(path: pathOnly).toString();
      }
    } catch (_) {}
    return pathOnly;
  }

  Future<void> _copyLink(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final text = _shareableLinkText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.studioReviewPackLinkCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final title =
        widget.projectName ??
        l10n.projectsUnnamedProject(widget.projectNumericId);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.studioReviewPackTitle),
          actions: <Widget>[
            IconButton(
              tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
              onPressed: () => _load(isRetry: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(
              '/projects/${widget.projectNumericId}/${StudioStep.deliver.slug}',
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                l10n.studioReviewPackLoading,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: StudioTokens.of(context).textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.studioReviewPackTitle),
          actions: <Widget>[
            IconButton(
              tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
              onPressed: () => _load(isRetry: true),
              icon: const Icon(Icons.refresh),
            ),
          ],
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(
              '/projects/${widget.projectNumericId}/${StudioStep.deliver.slug}',
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StudioApiErrorCallout(
              error: _error!,
              onRetry: () => _load(isRetry: true),
              showDiagnostic: false,
            ),
          ),
        ),
      );
    }

    final readiness = _readiness;
    final rows = readiness?.storyboards ?? const <StoryboardShortVideoReadiness>[];
    final rollup = readiness?.rollup;
    final production = _production;
    final feedbackRollup = ReviewPackFeedbackRollup.forStoryboards(
      storyboardNumericIds: rows.map((row) => row.storyboardNumericId),
      byStoryboard: _feedbackByStoryboard,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.studioReviewPackTitle),
        actions: <Widget>[
          IconButton(
            tooltip: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            onPressed: () => _load(isRetry: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(
            '/projects/${widget.projectNumericId}/${StudioStep.deliver.slug}',
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.studioReviewPackSubtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: StudioTokens.of(context).textSecondary,
                  ),
                ),
                if (rollup != null || production != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    l10n.studioReviewPackRollupLine(
                      production?.readyStoryboardCount ??
                          rollup?.readyCount ??
                          0,
                      production?.totalStoryboardCount ??
                          rollup?.totalStoryboards ??
                          rows.length,
                    ),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          StudioReviewPackExportBridge(
            projectNumericId: widget.projectNumericId,
            exportCheck: _exportCheck,
            exportCheckLoadFailed: _exportCheckLoadFailed,
          ),
          if (rows.isNotEmpty)
            StudioReviewPackTeamSummary(rollup: feedbackRollup),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                StudioPrimaryButton(
                  label: l10n.studioReviewPackOpenAssembly,
                  icon: Icons.movie_filter_outlined,
                  onPressed: () => context.go(
                    '/projects/${widget.projectNumericId}/${StudioStep.deliver.slug}?tab=assembly',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(l10n.studioReviewPackCopyLink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: StudioEmptyState.emptyData(
                        title: l10n.studioReviewPackEmpty,
                        icon: Icons.movie_filter_outlined,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return StudioReviewPackStoryboardRow(
                        row: row,
                        projectNumericId: widget.projectNumericId,
                        feedback: _feedbackByStoryboard[row.storyboardNumericId],
                        onSubmitFeedback: _submitReviewPackFeedback,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
