import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../short_video_space/desktop_capability.dart';

/// Where in-app login + cookie capture is available.
enum NovelCrawlInAppLoginPlatform {
  desktop,
  web,
  mobile,
}

NovelCrawlInAppLoginPlatform resolveNovelCrawlInAppLoginPlatform() {
  if (kIsWeb) return NovelCrawlInAppLoginPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      NovelCrawlInAppLoginPlatform.desktop,
    _ => NovelCrawlInAppLoginPlatform.mobile,
  };
}

bool supportsNovelCrawlInAppLogin(BuildContext context) {
  return resolveNovelCrawlInAppLoginPlatform() ==
      NovelCrawlInAppLoginPlatform.desktop;
}

/// Web / mobile guidance: download desktop app for one-click cookie capture.
class NovelCrawlDesktopDownloadHintPanel extends StatelessWidget {
  const NovelCrawlDesktopDownloadHintPanel({
    super.key,
    this.downloadUrl = kOpenflowDesktopDownloadsUrl,
  });

  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final platform = resolveNovelCrawlInAppLoginPlatform();
    final isWeb = platform == NovelCrawlInAppLoginPlatform.web;

    final title = isWeb
        ? l10n.studioNovelCrawlAuthWebGuideTitle
        : l10n.studioNovelCrawlAuthMobileGuideTitle;
    final body = isWeb
        ? l10n.studioNovelCrawlAuthWebGuideBody
        : l10n.studioNovelCrawlAuthMobileGuideBody;
    final steps = isWeb ? l10n.studioNovelCrawlAuthWebGuideSteps : null;

    final foreground = theme.colorScheme.onSecondaryContainer;
    final background = theme.colorScheme.secondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                isWeb ? Icons.laptop_mac_outlined : Icons.phone_iphone_outlined,
                color: tokens.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (steps != null) ...<Widget>[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  steps,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: () => unawaited(_openDownloads(downloadUrl)),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: Text(l10n.shortVideoDownloadDesktopApp),
              ),
              if (isWeb)
                OutlinedButton.icon(
                  onPressed: () => unawaited(
                    _openDownloads('$downloadUrl#novel-crawl-auth'),
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(l10n.studioNovelCrawlAuthWebGuideLearnMore),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDownloads(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Collapsed teaser on web/mobile — tap to expand the auth section.
class NovelCrawlDesktopDownloadHintTeaser extends StatelessWidget {
  const NovelCrawlDesktopDownloadHintTeaser({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (supportsNovelCrawlInAppLogin(context)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final isWeb =
        resolveNovelCrawlInAppLoginPlatform() == NovelCrawlInAppLoginPlatform.web;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: tokens.primarySoft.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: <Widget>[
                Icon(
                  isWeb ? Icons.laptop_outlined : Icons.info_outline,
                  size: 18,
                  color: tokens.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.studioNovelCrawlAuthWebGuideCollapsed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
