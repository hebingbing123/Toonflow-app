import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

import '../studio_typography.dart';
import '../tokens.dart';
import 'studio_text_styles.dart';

/// 16:9 media preview card (Wave 4).
class StudioMediaCard extends StatelessWidget {
  const StudioMediaCard({
    super.key,
    this.imageUrl,
    this.label,
    this.loading = false,
    this.error,
    this.onRetry,
    this.onTap,
  });

  final String? imageUrl;
  final String? label;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    Widget child;
    if (loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (error != null) {
      child = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: tokens.danger),
            const SizedBox(height: 8),
            Text(error!, style: Theme.of(context).textTheme.bodySmall),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context)!.studioRetry),
              ),
          ],
        ),
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(imageUrl!, fit: BoxFit.cover);
    } else {
      child = Icon(Icons.movie_outlined, size: 48, color: tokens.textMuted);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: tokens.bgInset,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        label!,
                        style: studioControlLabelStyle(context)?.copyWith(
                          color: Colors.white,
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
    );
  }
}
