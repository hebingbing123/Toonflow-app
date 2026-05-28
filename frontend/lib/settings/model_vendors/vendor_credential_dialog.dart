import 'dart:async';

import 'package:flutter/material.dart';
import '../../design_system/tokens.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/ix/studio_mobile_affordances.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';

/// Store or remove LLM vendor API credentials (never shown in plain text after save).
Future<bool?> showVendorCredentialDialog({
  required BuildContext context,
  required String accessToken,
  required String vendorId,
  required String vendorName,
  required bool hasCredential,
  bool apiKeyOptional = false,
}) {
  return showStudioDialog<bool>(
    context: context,
    builder: (ctx) => _VendorCredentialDialog(
      accessToken: accessToken,
      vendorId: vendorId,
      vendorName: vendorName,
      hasCredential: hasCredential,
      apiKeyOptional: apiKeyOptional,
    ),
  );
}

class _VendorCredentialDialog extends StatefulWidget {
  const _VendorCredentialDialog({
    required this.accessToken,
    required this.vendorId,
    required this.vendorName,
    required this.hasCredential,
    this.apiKeyOptional = false,
  });

  final String accessToken;
  final String vendorId;
  final String vendorName;
  final bool hasCredential;
  final bool apiKeyOptional;

  @override
  State<_VendorCredentialDialog> createState() => _VendorCredentialDialogState();
}

class _VendorCredentialDialogState extends State<_VendorCredentialDialog> {
  final _apiKeyCtrl = TextEditingController();
  final _apiSecretCtrl = TextEditingController();
  final _apiTokenCtrl = TextEditingController();
  bool _busy = false;
  String? _keyHint;

  @override
  void initState() {
    super.initState();
    if (widget.hasCredential) _loadHint();
  }

  Future<void> _loadHint() async {
    try {
      final cred = await getSettingsVendorCredentialV1(
        widget.accessToken,
        vendorId: widget.vendorId,
      );
      if (!mounted) return;
      setState(() => _keyHint = cred.keyHint);
    } catch (_) {
      // Ignore — user can still replace credentials.
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _apiSecretCtrl.dispose();
    _apiTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _apiKeyCtrl.text.trim();
    final secret = _apiSecretCtrl.text.trim();
    final token = _apiTokenCtrl.text.trim();
    if (key.isEmpty && secret.isEmpty && token.isEmpty) return;

    setState(() => _busy = true);
    try {
      unawaited(studioLightImpact());
      await postSettingsVendorCredentialV1(
        widget.accessToken,
        vendorId: widget.vendorId,
        apiKey: key.isEmpty ? null : key,
        apiSecret: secret.isEmpty ? null : secret,
        apiToken: token.isEmpty ? null : token,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showStudioConfirmDialog(
      context: context,
      title: 'Delete vendor credential?',
      message:
          'This will remove the saved credential for this vendor and cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      destructive: true,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      unawaited(studioMediumImpact());
      await deleteSettingsVendorCredentialV1(
        widget.accessToken,
        vendorId: widget.vendorId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(describeUserVisibleApiErrorResolved(context, e)),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StudioAlertDialog(
      title: Text(l10n.settingsModelVendorsCredentialDialogTitle(widget.vendorName)),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.apiKeyOptional
                  ? l10n.settingsModelVendorsCredentialDialogBodyLocal
                  : l10n.settingsModelVendorsCredentialDialogBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_keyHint != null && _keyHint!.isNotEmpty) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.settingsModelVendorsCredentialHint(_keyHint!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: StudioSpacing.sm),
            TextField(
              controller: _apiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsModelVendorsFieldApiKey,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: _apiSecretCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsModelVendorsFieldApiSecret,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: _apiTokenCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.settingsModelVendorsFieldApiToken,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        if (widget.hasCredential)
          TextButton(
            onPressed: _busy ? null : _delete,
            child: Text(l10n.settingsModelVendorsCredentialRemove),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.notificationsActionCancel),
        ),
        FilledButton(
          style: studioFormPrimaryButtonStyle(context),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.projectEditorAssetCrudSave),
        ),
      ],
    );
  }
}
