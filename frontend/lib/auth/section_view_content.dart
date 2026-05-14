part of 'section_view.dart';

class _AuthSectionContent extends StatelessWidget {
  const _AuthSectionContent({required this.model, required this.callbacks});

  final AuthSectionViewModel model;
  final AuthSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text(
          l10n.authSupabaseAuthTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (!kSupabaseConfigured)
          Text(
            l10n.authSupabaseNotConfigured,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          TextField(
            controller: model.emailController,
            decoration: InputDecoration(labelText: l10n.authEmailFieldLabel),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: model.passwordController,
            decoration: InputDecoration(labelText: l10n.authPasswordFieldLabel),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: callbacks.onSignIn,
                child: Text(l10n.authSignIn),
              ),
              OutlinedButton(
                onPressed: callbacks.onSignUp,
                child: Text(l10n.authSignUp),
              ),
              if (model.signedIn)
                TextButton(
                  onPressed: callbacks.onSignOut,
                  child: Text(l10n.authSignOut),
                ),
            ],
          ),
          if (model.signedIn)
            _AuthSignedInPanel(model: model, callbacks: callbacks),
        ],
      ],
    );
  }
}

class _AuthSignedInPanel extends StatelessWidget {
  const _AuthSignedInPanel({required this.model, required this.callbacks});

  final AuthSectionViewModel model;
  final AuthSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(l10n.authSignedInUser(model.session?.user.id ?? '')),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingMe ? null : callbacks.onCallMe,
          child: Text(
            model.loadingMe ? l10n.authRequestInProgress : l10n.authGetMeBearer,
          ),
        ),
        if (model.meBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authMeResponse(model.meBody!)),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingDevSwitchProbe
              ? null
              : callbacks.onCallDevSwitchProbe,
          child: Text(
            model.loadingDevSwitchProbe
                ? l10n.authRequestInProgress
                : l10n.authDevSwitchProbe,
          ),
        ),
        if (model.devSwitchProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authDevSwitchResponse(model.devSwitchProbeBody!)),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingMemoryConfigProbe
              ? null
              : callbacks.onCallMemoryConfigProbe,
          child: Text(
            model.loadingMemoryConfigProbe
                ? l10n.authRequestInProgress
                : l10n.authMemoryConfigProbe,
          ),
        ),
        if (model.memoryConfigProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.authMemoryConfigResponse(model.memoryConfigProbeBody!),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingAboutProbe
              ? null
              : callbacks.onCallAboutProbe,
          child: Text(
            model.loadingAboutProbe
                ? l10n.authRequestInProgress
                : l10n.authAboutProbe,
          ),
        ),
        if (model.aboutProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authAboutResponse(model.aboutProbeBody!)),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingUsageSummary
              ? null
              : callbacks.onCallUsageSummary,
          child: Text(
            model.loadingUsageSummary
                ? l10n.authRequestInProgress
                : l10n.authUsageSummary,
          ),
        ),
        if (model.usageSummaryBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authUsageResponse(model.usageSummaryBody!)),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingPromptsProbe
              ? null
              : callbacks.onCallPromptsProbe,
          child: Text(
            model.loadingPromptsProbe
                ? l10n.authRequestInProgress
                : l10n.authPromptsProbe,
          ),
        ),
        if (model.promptsProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authPromptsResponse(model.promptsProbeBody!)),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingVisualManualProbe
              ? null
              : callbacks.onCallVisualManualProbe,
          child: Text(
            model.loadingVisualManualProbe
                ? l10n.authRequestInProgress
                : l10n.authVisualManualProbe,
          ),
        ),
        if (model.visualManualProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.authVisualManualResponse(model.visualManualProbeBody!),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingDirectorManualProbe
              ? null
              : callbacks.onCallDirectorManualProbe,
          child: Text(
            model.loadingDirectorManualProbe
                ? l10n.authRequestInProgress
                : l10n.authDirectorManualProbe,
          ),
        ),
        if (model.directorManualProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.authDirectorManualResponse(model.directorManualProbeBody!),
          ),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingSkillsBinaryProbe
              ? null
              : callbacks.onCallSkillsBinaryProbe,
          child: Text(
            model.loadingSkillsBinaryProbe
                ? l10n.authRequestInProgress
                : l10n.authSkillsBinaryProbe,
          ),
        ),
        if (model.skillsBinaryProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.authSkillsBinaryResponse(model.skillsBinaryProbeBody!),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: model.loadingModelsCatalog
                  ? null
                  : callbacks.onCallModelsCatalog,
              child: Text(
                model.loadingModelsCatalog
                    ? l10n.authRequestInProgress
                    : l10n.authModelsCatalogProbe,
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingTextModelDefault
                  ? null
                  : callbacks.onCallTextModelDefault,
              child: Text(
                model.loadingTextModelDefault
                    ? l10n.authRequestInProgress
                    : l10n.authTextModelDefaultProbe,
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingModelDetail
                  ? null
                  : callbacks.onCallModelDetail,
              child: Text(
                model.loadingModelDetail
                    ? l10n.authRequestInProgress
                    : l10n.authModelDetailProbe,
              ),
            ),
          ],
        ),
        if (model.modelsCatalogBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authModelsResponse(model.modelsCatalogBody!)),
        ],
        if (model.textModelDefaultBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.authTextDefaultResponse(model.textModelDefaultBody!),
          ),
        ],
        if (model.modelDetailBody != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.authModelDetailResponse(model.modelDetailBody!)),
        ],
      ],
    );
  }
}
