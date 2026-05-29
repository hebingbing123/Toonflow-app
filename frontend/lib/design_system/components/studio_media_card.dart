import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import 'studio_surfaces.dart';
import 'studio_entrance_motion.dart';
import '../ix/studio_pointer.dart';
import '../studio_network_image.dart';
import '../studio_typography.dart';
import '../tokens.dart';
import 'studio_decorative_icon.dart';
import 'studio_loading_placeholders.dart';
import 'studio_text_styles.dart';

/// 16:9 media preview card (Wave 4).
class StudioMediaCard extends StatelessWidget {
  const StudioMediaCard({
    super.key,
    this.imageUrl,
    this.accessToken,
    this.label,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onTap,
    this.heroTag,
  });

  final String? imageUrl;
  final String? accessToken;
  final String? label;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    Widget child;
    if (loading) {
      child = const StudioMediaTileSkeleton();
    } else if (error != null) {
      child = Center(
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              studioDecorativeIcon(Icons.cloud_off_outlined, color: tokens.danger),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: StudioSpacing.xs),
                TextButton(
                  onPressed: onRetry,
                  child: Text(AppLocalizations.of(context)!.studioRetry),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = StudioNetworkImage(
        url: imageUrl!,
        accessToken: accessToken,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      child = studioDecorativeIcon(
        Icons.movie_outlined,
        size: 48,
        color: tokens.textMuted,
      );
    }

    final radius = BorderRadius.circular(StudioSpacing.radiusCard);
    final interactive = onTap != null;

    final card = AspectRatio(
      aspectRatio: 16 / 9,
      child: StudioPointerHover(
        enabled: interactive,
        borderRadius: radius,
        builder: (context, hovered) {
          return studioWrapClickCursor(
            enabled: interactive,
            child: Material(
              color: tokens.bgInset,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                hoverColor: studioNestedMaterialHover,
                highlightColor: studioNestedMaterialHighlight,
                child: AnimatedScale(
                  scale: hovered ? 1.01 : 1,
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      child,
                      if (label != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.overlay,
                              borderRadius: BorderRadius.circular(
                                StudioSpacing.radiusDense,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                label!,
                                style: studioControlLabelStyle(context)?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: StudioTypography.of(context).meta,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    return StudioHero(tag: heroTag, child: card);
  }
}
