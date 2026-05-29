part of 'section.dart';

class _AssemblyClipDeskFilterKit {
  const _AssemblyClipDeskFilterKit({
    required this.filterState,
    required this.pausedStoryboardIds,
    required this.l10n,
    required this.context,
    required this.ordered,
  });

  final FilterState filterState;
  final Set<int> pausedStoryboardIds;
  final AppLocalizations l10n;
  final BuildContext context;
  final List<_AssemblyClipDeskOpEntry> ordered;

  static int? parseDurationSeconds(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
    if (digits == null) return null;
    return int.tryParse(digits.group(1)!);
  }

  String subtitleMismatchLine(_AssemblyClipDeskOpEntry item) {
    final durationSec = parseDurationSeconds(item.durationText);
    final hasSubtitle = item.subtitleText.isNotEmpty;
    if (hasSubtitle && durationSec == null) {
      return l10n.shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing;
    }
    if (!hasSubtitle && (durationSec ?? 0) > 0) {
      return l10n.shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty;
    }
    if (hasSubtitle && (durationSec ?? 0) <= 0) {
      return l10n.shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal;
    }
    return l10n.shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch;
  }

  bool hasSubtitleDurationMismatch(_AssemblyClipDeskOpEntry item) {
    final durationSec = parseDurationSeconds(item.durationText);
    final hasSubtitle = item.subtitleText.isNotEmpty;
    if (hasSubtitle && durationSec == null) return true;
    if (!hasSubtitle && (durationSec ?? 0) > 0) return true;
    if (hasSubtitle && (durationSec ?? 0) <= 0) return true;
    return false;
  }

  bool hasQualityIssue(_AssemblyClipDeskOpEntry item) {
    return item.voiceoverState == 'failed' || hasSubtitleDurationMismatch(item);
  }

  bool matchesSearch(_AssemblyClipDeskOpEntry item) {
    final keyword = filterState.searchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return true;
    }
    final searchTargets = <String>[
      item.storyboardNumericId.toString(),
      item.scriptNumericId.toString(),
      item.selectedMediaUrl,
      if (filterState.searchInSubtitles) item.subtitleText,
      if (filterState.searchInVoiceover) ...[
        item.voiceoverState,
        item.voiceoverError,
        item.voiceoverAudioUrl,
      ],
    ];
    return searchTargets.any(
      (value) => value.toLowerCase().contains(keyword),
    );
  }

  Widget buildHighlightedText(
    String text,
    String keyword, {
    TextStyle? style,
  }) {
    if (keyword.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final matches = <int>[];

    var startIndex = 0;
    while (true) {
      final index = lowerText.indexOf(lowerKeyword, startIndex);
      if (index == -1) break;
      matches.add(index);
      startIndex = index + lowerKeyword.length;
    }

    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    var currentIndex = 0;

    for (final matchIndex in matches) {
      if (matchIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, matchIndex),
            style: style,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(
            matchIndex,
            matchIndex + lowerKeyword.length,
          ),
          style: (style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
              .copyWith(
            backgroundColor: StudioTokens.of(context).primarySoft,
            color: StudioTokens.of(context).textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      currentIndex = matchIndex + lowerKeyword.length;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(text: text.substring(currentIndex), style: style),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  bool matchesStatusFilters(_AssemblyClipDeskOpEntry item) {
    if (filterState.statusFilters.isEmpty) {
      return true;
    }
    final paused = pausedStoryboardIds.contains(item.storyboardNumericId);
    final durationSec = parseDurationSeconds(item.durationText);
    final hasSubtitle = item.subtitleText.isNotEmpty;
    final hasVoiceover =
        item.voiceoverScriptReady || item.voiceoverAssetReady;
    for (final filter in filterState.statusFilters) {
      switch (filter) {
        case ShotStatusFilter.enabled:
          if (!paused) return true;
          break;
        case ShotStatusFilter.disabled:
          if (paused) return true;
          break;
        case ShotStatusFilter.hasVideo:
          if (item.selectedMediaUrl.isNotEmpty) return true;
          break;
        case ShotStatusFilter.noVideo:
          if (item.selectedMediaUrl.isEmpty) return true;
          break;
        case ShotStatusFilter.hasDuration:
          if ((durationSec ?? 0) > 0) return true;
          break;
        case ShotStatusFilter.noDuration:
          if ((durationSec ?? 0) <= 0) return true;
          break;
        case ShotStatusFilter.hasSubtitle:
          if (hasSubtitle) return true;
          break;
        case ShotStatusFilter.noSubtitle:
          if (!hasSubtitle) return true;
          break;
        case ShotStatusFilter.hasVoiceover:
          if (hasVoiceover) return true;
          break;
        case ShotStatusFilter.noVoiceover:
          if (!hasVoiceover) return true;
          break;
        case ShotStatusFilter.voiceoverFailed:
          if (item.voiceoverState == 'failed') return true;
          break;
      }
    }
    return false;
  }

  bool matchesQualityFilters(_AssemblyClipDeskOpEntry item) {
    if (filterState.qualityFilters.isEmpty) {
      return true;
    }
    final qualityIssue = hasQualityIssue(item);
    final postProductionReady =
        item.selectedMediaUrl.isNotEmpty &&
        parseDurationSeconds(item.durationText) != null;
    for (final filter in filterState.qualityFilters) {
      switch (filter) {
        case QualityFilter.hasBadExample:
          if (qualityIssue) return true;
          break;
        case QualityFilter.noBadExample:
          if (!qualityIssue) return true;
          break;
        case QualityFilter.generationStage:
          if (!postProductionReady) return true;
          break;
        case QualityFilter.postProductionStage:
          if (postProductionReady) return true;
          break;
        case QualityFilter.hasDegradation:
          if (qualityIssue ||
              pausedStoryboardIds.contains(item.storyboardNumericId)) {
            return true;
          }
          break;
        case QualityFilter.noDegradation:
          if (!qualityIssue &&
              !pausedStoryboardIds.contains(item.storyboardNumericId)) {
            return true;
          }
          break;
      }
    }
    return false;
  }

  List<_AssemblyClipDeskOpEntry> buildVisibleEntries() {
    return ordered
        .where((item) {
          return matchesSearch(item) &&
              matchesStatusFilters(item) &&
              matchesQualityFilters(item);
        })
        .toList(growable: false);
  }

  int calculateCurrentTotalDuration() {
    var total = 0;
    for (final item in ordered) {
      if (pausedStoryboardIds.contains(item.storyboardNumericId)) {
        continue;
      }
      final durationSec = parseDurationSeconds(item.durationText);
      if (durationSec != null && durationSec > 0) {
        total += durationSec;
      }
    }
    return total;
  }

  static String formatDurationHHMMSS(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
