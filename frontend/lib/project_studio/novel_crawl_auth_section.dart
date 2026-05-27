import 'package:flutter/material.dart';

import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'novel_crawl_login_webview_dialog.dart';
import 'novel_crawl_platform_hint.dart';

/// Per-project novel site authentication (cookie / form login) for URL crawls.
class StudioNovelCrawlAuthSection extends StatefulWidget {
  const StudioNovelCrawlAuthSection({
    super.key,
    required this.accessToken,
    required this.projectId,
    required this.onOverrideChanged,
    this.siteUrlProvider,
  });

  final String accessToken;
  final String projectId;
  final ValueChanged<NovelCrawlAuthOverride?> onOverrideChanged;
  /// Latest novel/chapter URL (e.g. import URL field) used to prefill in-app login.
  final String? Function()? siteUrlProvider;

  @override
  State<StudioNovelCrawlAuthSection> createState() =>
      _StudioNovelCrawlAuthSectionState();
}

class _StudioNovelCrawlAuthSectionState
    extends State<StudioNovelCrawlAuthSection> {
  static const _modes = <String>[
    'none',
    'cookie',
    'password',
    'cookie_and_password',
  ];

  final TextEditingController _cookieCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _loginUrlCtrl = TextEditingController();
  final TextEditingController _loginUserFieldCtrl = TextEditingController(
    text: 'username',
  );
  final TextEditingController _loginPassFieldCtrl = TextEditingController(
    text: 'password',
  );

  bool _expanded = false;
  bool _loading = true;
  bool _saving = false;
  String _authMode = 'none';
  bool _hasStoredCookie = false;
  bool _hasStoredPassword = false;
  bool _encryptionConfigured = true;
  String? _statusLine;

  @override
  void initState() {
    super.initState();
    for (final c in <TextEditingController>[
      _cookieCtrl,
      _usernameCtrl,
      _passwordCtrl,
      _loginUrlCtrl,
      _loginUserFieldCtrl,
      _loginPassFieldCtrl,
    ]) {
      c.addListener(_notifyOverride);
    }
    _loadConfig();
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _loginUrlCtrl.dispose();
    _loginUserFieldCtrl.dispose();
    _loginPassFieldCtrl.dispose();
    super.dispose();
  }

  void _notifyOverride() {
    widget.onOverrideChanged(_buildOverride());
  }

  NovelCrawlAuthOverride? _buildOverride() {
    if (_authMode == 'none') {
      return null;
    }
    final override = NovelCrawlAuthOverride(
      cookie: _showCookieField ? _cookieCtrl.text.trim() : null,
      username: _showPasswordFields ? _usernameCtrl.text.trim() : null,
      password: _showPasswordFields ? _passwordCtrl.text.trim() : null,
    );
    return override.isEmpty ? null : override;
  }

  bool get _showCookieField =>
      _authMode == 'cookie' || _authMode == 'cookie_and_password';

  bool get _showPasswordFields =>
      _authMode == 'password' || _authMode == 'cookie_and_password';

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _statusLine = null;
    });
    try {
      final config = await getProjectNovelCrawlAuth(
        widget.accessToken,
        widget.projectId,
      );
      if (!mounted) return;
      setState(() {
        _authMode = config.authMode;
        _hasStoredCookie = config.hasCookie;
        _hasStoredPassword = config.hasPassword;
        _encryptionConfigured = config.encryptionConfigured;
        _loginUrlCtrl.text = config.loginUrl ?? '';
        _loginUserFieldCtrl.text = config.loginUsernameField;
        _loginPassFieldCtrl.text = config.loginPasswordField;
        _expanded = config.authMode != 'none';
      });
      _notifyOverride();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiErrorResolved(context, e);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _captureCookieInApp() async {
    final l10n = AppLocalizations.of(context)!;
    if (!supportsNovelCrawlInAppLogin(context)) {
      setState(() {
        _statusLine = l10n.studioNovelCrawlAuthCaptureCookieWebUnavailable;
      });
      return;
    }
    final hint = widget.siteUrlProvider?.call();
    final captured = await showNovelCrawlLoginWebViewDialog(
      context: context,
      initialUrl: hint,
    );
    if (!mounted || captured == null || captured.trim().isEmpty) return;
    setState(() {
      _authMode = switch (_authMode) {
        'password' => 'cookie_and_password',
        'cookie_and_password' => 'cookie_and_password',
        _ => 'cookie',
      };
      _cookieCtrl.text = captured.trim();
      _statusLine = l10n.studioNovelCrawlAuthCaptureOk;
    });
    _notifyOverride();
  }

  Future<void> _saveConfig() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _statusLine = null;
    });
    try {
      final saved = await putProjectNovelCrawlAuth(
        widget.accessToken,
        widget.projectId,
        NovelCrawlAuthPutBody(
          authMode: _authMode,
          cookie: _showCookieField ? _cookieCtrl.text.trim() : '',
          username: _showPasswordFields ? _usernameCtrl.text.trim() : '',
          password: _showPasswordFields ? _passwordCtrl.text.trim() : '',
          loginUrl: _showPasswordFields && _loginUrlCtrl.text.trim().isNotEmpty
              ? _loginUrlCtrl.text.trim()
              : null,
          loginUsernameField: _loginUserFieldCtrl.text.trim().isEmpty
              ? 'username'
              : _loginUserFieldCtrl.text.trim(),
          loginPasswordField: _loginPassFieldCtrl.text.trim().isEmpty
              ? 'password'
              : _loginPassFieldCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _hasStoredCookie = saved.hasCookie;
        _hasStoredPassword = saved.hasPassword;
        _encryptionConfigured = saved.encryptionConfigured;
        _cookieCtrl.clear();
        _passwordCtrl.clear();
        _statusLine = l10n.studioNovelCrawlAuthSaveOk;
      });
      _notifyOverride();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiErrorResolved(context, e);
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _modeLabel(AppLocalizations l10n, String mode) {
    switch (mode) {
      case 'cookie':
        return l10n.studioNovelCrawlAuthModeCookie;
      case 'password':
        return l10n.studioNovelCrawlAuthModePassword;
      case 'cookie_and_password':
        return l10n.studioNovelCrawlAuthModeBoth;
      default:
        return l10n.studioNovelCrawlAuthModeNone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final outline = tokens.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: _loading ? null : () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: <Widget>[
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: outline,
                ),
                const SizedBox(width: StudioSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.studioNovelCrawlAuthSectionTitle,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (_authMode != 'none')
                  Text(
                    _modeLabel(l10n, _authMode),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: tokens.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
        NovelCrawlDesktopDownloadHintTeaser(
          onTap: () => setState(() => _expanded = true),
        ),
        if (_expanded) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.studioNovelCrawlAuthSectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          if (!_encryptionConfigured) ...<Widget>[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.studioNovelCrawlAuthEncryptionMissing,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _authMode,
            decoration: InputDecoration(
              labelText: l10n.studioNovelCrawlAuthModeLabel,
              isDense: true,
            ),
            items: _modes
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m,
                    child: Text(_modeLabel(l10n, m)),
                  ),
                )
                .toList(),
            onChanged: _loading || _saving
                ? null
                : (v) {
                    if (v == null) return;
                    setState(() => _authMode = v);
                    _notifyOverride();
                  },
          ),
          if (supportsNovelCrawlInAppLogin(context)) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: _loading || _saving ? null : _captureCookieInApp,
                icon: const Icon(Icons.login, size: 18),
                label: Text(l10n.studioNovelCrawlAuthCaptureCookieButton),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            const NovelCrawlDesktopDownloadHintPanel(),
          ],
          if (_showCookieField) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _cookieCtrl,
              enabled: !_loading && !_saving,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.studioNovelCrawlAuthCookieLabel,
                helperText: _hasStoredCookie
                    ? l10n.studioNovelCrawlAuthCookieStoredHint
                    : l10n.studioNovelCrawlAuthCookieHelper,
                isDense: true,
                alignLabelWithHint: true,
              ),
            ),
          ],
          if (_showPasswordFields) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _usernameCtrl,
              enabled: !_loading && !_saving,
              decoration: InputDecoration(
                labelText: l10n.studioNovelCrawlAuthUsernameLabel,
                isDense: true,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: _passwordCtrl,
              enabled: !_loading && !_saving,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.studioNovelCrawlAuthPasswordLabel,
                helperText: _hasStoredPassword
                    ? l10n.studioNovelCrawlAuthPasswordStoredHint
                    : null,
                isDense: true,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: _loginUrlCtrl,
              enabled: !_loading && !_saving,
              decoration: InputDecoration(
                labelText: l10n.studioNovelCrawlAuthLoginUrlLabel,
                helperText: l10n.studioNovelCrawlAuthLoginUrlHelper,
                isDense: true,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _loginUserFieldCtrl,
                    enabled: !_loading && !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.studioNovelCrawlAuthLoginUserFieldLabel,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _loginPassFieldCtrl,
                    enabled: !_loading && !_saving,
                    decoration: InputDecoration(
                      labelText: l10n.studioNovelCrawlAuthLoginPassFieldLabel,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          StudioDenseActionRow(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: _loading || _saving ? null : _loadConfig,
                child: Text(l10n.studioNovelCrawlAuthReload),
              ),
              FilledButton.tonal(
                style: studioFormTonalButtonStyle(context),
                onPressed: _loading || _saving || _authMode == 'none'
                    ? null
                    : _saveConfig,
                child: Text(l10n.studioNovelCrawlAuthSave),
              ),
            ],
          ),
          if (_statusLine != null) ...<Widget>[
            const SizedBox(height: StudioSpacing.xs),
            Text(
              _statusLine!,
              style: theme.textTheme.bodySmall?.copyWith(color: outline),
            ),
          ],
          if (_loading || _saving)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ],
    );
  }
}
