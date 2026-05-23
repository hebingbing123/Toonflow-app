import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

import 'novel_crawl_platform_hint.dart';

/// Normalizes a novel/chapter URL to `scheme://host` for opening the site home.
String? normalizeNovelSiteOrigin(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  var uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    uri = Uri.tryParse('https://$trimmed');
  }
  if (uri == null) return null;
  if (!(uri.scheme == 'http' || uri.scheme == 'https')) return null;
  if (uri.host.isEmpty) return null;
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// Opens an in-app browser; returns a `Cookie` header value after the user signs in.
Future<String?> showNovelCrawlLoginWebViewDialog({
  required BuildContext context,
  String? initialUrl,
}) {
  if (!supportsNovelCrawlInAppLogin(context)) {
    return Future<String?>.value();
  }
  return showStudioDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => NovelCrawlLoginWebViewDialog(
      initialUrl: normalizeNovelSiteOrigin(initialUrl),
    ),
  );
}

class NovelCrawlLoginWebViewDialog extends StatefulWidget {
  const NovelCrawlLoginWebViewDialog({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<NovelCrawlLoginWebViewDialog> createState() =>
      _NovelCrawlLoginWebViewDialogState();
}

class _NovelCrawlLoginWebViewDialogState
    extends State<NovelCrawlLoginWebViewDialog> {
  final TextEditingController _urlCtrl = TextEditingController();
  InAppWebViewController? _webController;
  double _progress = 0;
  bool _capturing = false;
  String? _errorLine;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  WebUri? get _startUri {
    final origin = normalizeNovelSiteOrigin(_urlCtrl.text);
    return origin == null ? null : WebUri(origin);
  }

  Future<void> _openUrl() async {
    final uri = _startUri;
    if (uri == null || _webController == null) {
      setState(() {
        _errorLine = AppLocalizations.of(context)!.studioNovelCrawlLoginDialogInvalidUrl;
      });
      return;
    }
    setState(() => _errorLine = null);
    await _webController!.loadUrl(urlRequest: URLRequest(url: uri));
  }

  Future<void> _captureCookies() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = _webController;
    if (controller == null) return;

    setState(() {
      _capturing = true;
      _errorLine = null;
    });

    try {
      final pageUrl = await controller.getUrl();
      if (pageUrl == null) {
        setState(() {
          _errorLine = l10n.studioNovelCrawlLoginDialogNoCookies;
        });
        return;
      }

      final candidates = <WebUri>{pageUrl};
      final origin = normalizeNovelSiteOrigin(pageUrl.toString());
      if (origin != null) {
        candidates.add(WebUri(origin));
      }

      final seen = <String>{};
      final parts = <String>[];
      for (final uri in candidates) {
        final cookies = await CookieManager.instance().getCookies(url: uri);
        for (final cookie in cookies) {
          final name = cookie.name.trim();
          if (name.isEmpty) continue;
          final key = '$name=${cookie.value}';
          if (seen.add(key)) {
            parts.add(key);
          }
        }
      }

      if (parts.isEmpty) {
        setState(() {
          _errorLine = l10n.studioNovelCrawlLoginDialogNoCookies;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(parts.join('; '));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorLine = describeUserVisibleApiErrorResolved(context, e);
      });
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final startUri = _startUri;

    return StudioDialogShell(
      title: l10n.studioNovelCrawlLoginDialogTitle,
      subtitle: l10n.studioNovelCrawlLoginDialogSubtitle,
      maxWidth: 920,
      maxHeightFactor: 0.92,
      scrollable: false,
      onClose: _capturing ? null : () => Navigator.of(context).pop(),
      actions: <Widget>[
        TextButton(
          onPressed: _capturing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.studioNovelCrawlLoginDialogCancel),
        ),
        FilledButton.icon(
          onPressed: _capturing || startUri == null ? null : _captureCookies,
          icon: _capturing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cookie_outlined, size: 18),
          label: Text(l10n.studioNovelCrawlLoginDialogConfirm),
        ),
      ],
      child: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    enabled: !_capturing,
                    decoration: InputDecoration(
                      labelText: l10n.studioNovelCrawlLoginDialogUrlLabel,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _openUrl(),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _capturing || startUri == null ? null : _openUrl,
                  child: Text(l10n.studioNovelCrawlLoginDialogGo),
                ),
              ],
            ),
            if (_errorLine != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                _errorLine!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_progress > 0 && _progress < 1) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              LinearProgressIndicator(value: _progress, minHeight: 2),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: studioPanelBorderColor(context).withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  child: startUri == null
                      ? Center(
                          child: Text(
                            l10n.studioNovelCrawlLoginDialogInvalidUrl,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : InAppWebView(
                          initialUrlRequest: URLRequest(url: startUri),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            useOnDownloadStart: true,
                            allowsInlineMediaPlayback: true,
                          ),
                          onWebViewCreated: (controller) {
                            _webController = controller;
                          },
                          onLoadStart: (_, _) {
                            setState(() => _progress = 0.05);
                          },
                          onProgressChanged: (_, progress) {
                            setState(() => _progress = progress / 100);
                          },
                          onLoadStop: (_, _) {
                            setState(() => _progress = 1);
                          },
                          onReceivedError: (_, request, error) {
                            if (request.isForMainFrame != true) return;
                            setState(() {
                              _errorLine = error.description;
                            });
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
