part of 'filter_panel.dart';

class FilterState {
  const FilterState({
    this.searchKeyword = '',
    this.statusFilters = const {},
    this.qualityFilters = const {},
    this.searchInSubtitles = true,
    this.searchInVoiceover = true,
  });

  /// Search keyword
  final String searchKeyword;

  /// Status filters
  final Set<ShotStatusFilter> statusFilters;

  /// Quality filters
  final Set<QualityFilter> qualityFilters;

  /// Whether to search in subtitles
  final bool searchInSubtitles;

  /// Whether to search in voiceover
  final bool searchInVoiceover;

  /// Create empty filter state
  factory FilterState.empty() => const FilterState();

  /// Copy with new values
  FilterState copyWith({
    String? searchKeyword,
    Set<ShotStatusFilter>? statusFilters,
    Set<QualityFilter>? qualityFilters,
    bool? searchInSubtitles,
    bool? searchInVoiceover,
  }) {
    return FilterState(
      searchKeyword: searchKeyword ?? this.searchKeyword,
      statusFilters: statusFilters ?? this.statusFilters,
      qualityFilters: qualityFilters ?? this.qualityFilters,
      searchInSubtitles: searchInSubtitles ?? this.searchInSubtitles,
      searchInVoiceover: searchInVoiceover ?? this.searchInVoiceover,
    );
  }

  /// Check if filter is empty
  bool get isEmpty =>
      searchKeyword.isEmpty &&
      statusFilters.isEmpty &&
      qualityFilters.isEmpty;

  /// Check if filter is not empty
  bool get isNotEmpty => !isEmpty;
}

/// Shot status filter enum
enum ShotStatusFilter {
  enabled,
  disabled,
  hasVideo,
  noVideo,
  hasDuration,
  noDuration,
  hasSubtitle,
  noSubtitle,
  hasVoiceover,
  noVoiceover,
  voiceoverFailed,
}

extension ShotStatusFilterLocalization on ShotStatusFilter {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case ShotStatusFilter.enabled:
        return l10n.shortVideoFilterStatusEnabled;
      case ShotStatusFilter.disabled:
        return l10n.shortVideoFilterStatusDisabled;
      case ShotStatusFilter.hasVideo:
        return l10n.shortVideoFilterStatusHasVideo;
      case ShotStatusFilter.noVideo:
        return l10n.shortVideoFilterStatusNoVideo;
      case ShotStatusFilter.hasDuration:
        return l10n.shortVideoFilterStatusHasDuration;
      case ShotStatusFilter.noDuration:
        return l10n.shortVideoFilterStatusNoDuration;
      case ShotStatusFilter.hasSubtitle:
        return l10n.shortVideoFilterStatusHasSubtitle;
      case ShotStatusFilter.noSubtitle:
        return l10n.shortVideoFilterStatusNoSubtitle;
      case ShotStatusFilter.hasVoiceover:
        return l10n.shortVideoFilterStatusHasVoiceover;
      case ShotStatusFilter.noVoiceover:
        return l10n.shortVideoFilterStatusNoVoiceover;
      case ShotStatusFilter.voiceoverFailed:
        return l10n.shortVideoFilterStatusVoiceoverFailed;
    }
  }
}

/// Quality filter enum
enum QualityFilter {
  hasBadExample,
  noBadExample,
  generationStage,
  postProductionStage,
  hasDegradation,
  noDegradation,
}

extension QualityFilterLocalization on QualityFilter {
  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case QualityFilter.hasBadExample:
        return l10n.shortVideoFilterQualityHasBadExample;
      case QualityFilter.noBadExample:
        return l10n.shortVideoFilterQualityNoBadExample;
      case QualityFilter.generationStage:
        return l10n.shortVideoFilterQualityGenerationStage;
      case QualityFilter.postProductionStage:
        return l10n.shortVideoFilterQualityPostProductionStage;
      case QualityFilter.hasDegradation:
        return l10n.shortVideoFilterQualityHasDegradation;
      case QualityFilter.noDegradation:
        return l10n.shortVideoFilterQualityNoDegradation;
    }
  }
}

/// Filter tag model
class FilterTag {
  const FilterTag({
    required this.type,
    required this.label,
    required this.value,
  });

  final FilterTagType type;
  final String label;
  final Object value;
}

/// Filter tag type enum
enum FilterTagType {
  search,
  status,
  quality,
}

/// Filter preset model
class FilterPreset {
  const FilterPreset({
    required this.name,
    required this.filter,
    required this.createdAt,
  });

  /// Preset name
  final String name;

  /// Filter state
  final FilterState filter;

  /// Creation timestamp
  final DateTime createdAt;

  /// Summary of filters for preset list rows
  String summarize(AppLocalizations l10n) {
    final parts = <String>[];

    if (filter.searchKeyword.isNotEmpty) {
      parts.add(l10n.shortVideoFilterPresetPartSearch(filter.searchKeyword));
    }

    if (filter.statusFilters.isNotEmpty) {
      parts.add(l10n.shortVideoFilterPresetPartStatusCount(filter.statusFilters.length));
    }

    if (filter.qualityFilters.isNotEmpty) {
      parts.add(l10n.shortVideoFilterPresetPartQualityCount(filter.qualityFilters.length));
    }

    return parts.isEmpty ? l10n.shortVideoFilterPresetSummaryEmpty : parts.join(', ');
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'filter': {
        'searchKeyword': filter.searchKeyword,
        'statusFilters': filter.statusFilters.map((f) => f.name).toList(),
        'qualityFilters': filter.qualityFilters.map((f) => f.name).toList(),
        'searchInSubtitles': filter.searchInSubtitles,
        'searchInVoiceover': filter.searchInVoiceover,
      },
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      name: json['name'] as String,
      filter: FilterState(
        searchKeyword: json['filter']['searchKeyword'] as String? ?? '',
        statusFilters: (json['filter']['statusFilters'] as List<dynamic>?)
                ?.map((name) => ShotStatusFilter.values.firstWhere(
                      (f) => f.name == name,
                      orElse: () => ShotStatusFilter.enabled,
                    ))
                .toSet() ??
            {},
        qualityFilters: (json['filter']['qualityFilters'] as List<dynamic>?)
                ?.map((name) => QualityFilter.values.firstWhere(
                      (f) => f.name == name,
                      orElse: () => QualityFilter.hasBadExample,
                    ))
                .toSet() ??
            {},
        searchInSubtitles: json['filter']['searchInSubtitles'] as bool? ?? true,
        searchInVoiceover: json['filter']['searchInVoiceover'] as bool? ?? true,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Dialog for saving a filter preset
