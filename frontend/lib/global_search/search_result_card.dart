import 'package:flutter/material.dart';

import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../rust_api/search/api.dart';
import '../utils/localized_formatting.dart';

/// Individual search result card component.
///
/// **Validates: Requirements 4.5, 4.6, 9.5, 11.4**
///
/// Features:
/// - Display type icon (project/script/asset/novel/novel_event)
/// - Display title and updated time
/// - Parse <mark> tags in snippet and highlight matching keywords
/// - Implement click navigation to detail page
/// - Visual indication when selected via keyboard navigation
class SearchResultCard extends StatelessWidget {
  const SearchResultCard({
    super.key,
    required this.result,
    this.onTap,
    this.isSelected = false,
  });

  /// The search result to display
  final SearchResult result;

  /// Callback when the card is tapped
  /// If null, default navigation will be used
  final VoidCallback? onTap;

  /// Whether this card is currently selected via keyboard navigation
  final bool isSelected;

  /// Get display name for result type
  String _getTypeDisplayName(AppLocalizations l10n, ResultType type) {
    switch (type) {
      case ResultType.project:
        return l10n.globalSearchTypeProject;
      case ResultType.script:
        return l10n.globalSearchTypeScript;
      case ResultType.asset:
        return l10n.globalSearchTypeAsset;
      case ResultType.novel:
        return l10n.globalSearchTypeNovel;
      case ResultType.novelEvent:
        return l10n.globalSearchTypeNovelEvent;
    }
  }

  /// Get icon for result type
  IconData _getTypeIcon(ResultType type) {
    switch (type) {
      case ResultType.project:
        return Icons.folder_outlined;
      case ResultType.script:
        return Icons.description_outlined;
      case ResultType.asset:
        return Icons.image_outlined;
      case ResultType.novel:
        return Icons.menu_book_outlined;
      case ResultType.novelEvent:
        return Icons.event_note_outlined;
    }
  }

  /// Format time display using localized formatting
  String _formatTime(AppLocalizations l10n, BuildContext context, String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return LocalizedFormatting.formatRelativeTime(context, dateTime);
    } catch (_) {
      return '';
    }
  }

  /// Build highlighted snippet with <mark> tags parsed
  ///
  /// Parses the snippet string and extracts text within <mark>...</mark> tags,
  /// applying highlight styling to matched keywords.
  Widget _buildHighlightedSnippet(BuildContext context, String snippet) {
    final theme = Theme.of(context);
    final parts = <InlineSpan>[];

    // Parse <mark> tags and build TextSpan
    final regex = RegExp(r'<mark>(.*?)</mark>');
    int lastIndex = 0;

    for (final match in regex.allMatches(snippet)) {
      // Add text before match
      if (match.start > lastIndex) {
        parts.add(TextSpan(
          text: snippet.substring(lastIndex, match.start),
        ));
      }

      // Add highlighted text
      parts.add(TextSpan(
        text: match.group(1),
        style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
          backgroundColor: StudioTokens.of(context).primarySoft,
          color: StudioTokens.of(context).textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < snippet.length) {
      parts.add(TextSpan(
        text: snippet.substring(lastIndex),
      ));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: StudioTokens.of(context).textSecondary,
        ),
        children: parts,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: StudioSpacing.radiusComfort),
      elevation: isSelected ? 4 : 1,
      color: isSelected 
          ? StudioTokens.of(context).primarySoft.withValues(alpha: 0.3)
          : null,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
          child: Padding(
            padding: const EdgeInsets.all(StudioSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and type badge
                Row(
                  children: [
                    StudioHero(
                      tag: studioHeroTagSearchResultLeading(
                        result.resultType,
                        result.id,
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: StudioTokens.of(context).primarySoft,
                        child: Icon(
                          _getTypeIcon(result.resultType),
                          size: StudioIconSize.md,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(
                        result.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: StudioTokens.of(context).primarySoft,
                        borderRadius: BorderRadius.circular(
                          StudioSpacing.radiusDense,
                        ),
                      ),
                      child: Text(
                        _getTypeDisplayName(l10n, result.resultType),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StudioSpacing.sm),

                // Highlighted snippet
                _buildHighlightedSnippet(context, result.snippet),

                const SizedBox(height: StudioSpacing.sm),

                // Metadata row
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: StudioIconSize.xxs,
                      color: StudioTokens.of(context).textSecondary,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Text(
                      _formatTime(l10n, context, result.updatedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: StudioTokens.of(context).textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: StudioIconSize.xxs,
                      color: StudioTokens.of(context).textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
