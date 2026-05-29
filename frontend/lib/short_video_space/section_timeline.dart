// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

extension _ShortVideoSpaceSectionTimelineExtension
    on _ShortVideoSpaceSectionState {
  Future<void> _loadShortVideoTimeline() async {
    if (ProductDemoMode.instance.shouldSkipLiveApi) {
      final snap = widget.debugOverviewSnapshot;
      if (!mounted) {
        return;
      }
      setState(() {
        _shortVideoTimeline =
            snap?.timeline ?? buildDemoStudioShortVideoTimeline();
        _loadingTimeline = false;
        _timelineLoadError = null;
      });
      return;
    }
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    setState(() {
      _loadingTimeline = true;
      _timelineLoadError = null;
    });
    try {
      final timeline = await fetchProjectShortVideoTimelineByProjectId(
        token,
        project.id,
      );
      if (!mounted) return;
      setState(() {
        _shortVideoTimeline = timeline;
        _loadingTimeline = false;
        _timelineLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _shortVideoTimeline = null;
        _loadingTimeline = false;
        _timelineLoadError = e;
      });
    }
  }

  Widget? _buildShortVideoTimelinePanel() {
    final project = _selectedProject;
    if (project == null) {
      return null;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final timeline = _shortVideoTimeline;
    if (timeline == null && !_loadingTimeline) {
      unawaited(_loadShortVideoTimeline());
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.shortVideoTimelinePanelTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  style: studioFormTextButtonIconStyle(context),
                  onPressed: _loadingTimeline ? null : _loadShortVideoTimeline,
                  icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
                  label: Text(l10n.shortVideoCharactersRefresh),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            if (_loadingTimeline)
              const StudioListSkeleton(itemCount: 3)
            else if (_timelineLoadError != null)
              StudioEmptyState.loadFailed(
                context,
                error: _timelineLoadError,
                onRetry: _loadShortVideoTimeline,
              )
            else if (timeline == null || timeline.scripts.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.shortVideoTimelineEmpty,
                icon: Icons.timeline_outlined,
              )
            else
              _TimelineNleEditor(
                timeline: timeline,
                projectId: project.id,
                accessToken: widget.accessToken!,
                videoRatio: _videoRatio,
                saveBusy: _timelineSaveBusy,
                previewBusy: _timelinePreviewBusy,
                previewUrl: _timelinePreviewUrl,
                onSave: _saveTimelineTracks,
                onPreview: _generateTimelinePreview,
                onReordered: () async {
                  await _loadShortVideoTimeline();
                  await _loadProjectOverview();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTimelineTracks(ShortVideoTimelineTracksV1 tracks) async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || project == null || _timelineSaveBusy) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _timelineSaveBusy = true;
    });
    try {
      final resp = await putProjectShortVideoTimeline(
        token,
        project.id,
        tracks: tracks,
        expectedTimelineVersion: _shortVideoTimeline?.timelineVersion,
        expectedRevision: _shortVideoTimeline?.revision,
      );
      if (!mounted) return;
      await _loadShortVideoTimeline();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.shortVideoTimelineSaveDone} (${resp.updatedClipCount})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelineSaveFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _timelineSaveBusy = false;
        });
      }
    }
  }

  Future<void> _generateTimelinePreview() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || project == null || _timelinePreviewBusy) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _timelinePreviewBusy = true;
      _timelinePreviewUrl = null;
    });
    try {
      final enqueued = await postProjectShortVideoTimelinePreview(
        token,
        project.id,
      );
      final url = await pollTimelinePreviewJobFileUrl(token, enqueued.jobId);
      if (!mounted) return;
      setState(() {
        _timelinePreviewUrl = url;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l10n.shortVideoTimelinePreviewDone)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoTimelinePreviewFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _timelinePreviewBusy = false;
        });
      }
    }
  }
}
