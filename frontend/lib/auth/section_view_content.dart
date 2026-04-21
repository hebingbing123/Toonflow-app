part of 'section_view.dart';

class _AuthSectionContent extends StatelessWidget {
  const _AuthSectionContent({required this.model, required this.callbacks});

  final AuthSectionViewModel model;
  final AuthSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Text('Supabase Auth', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (!kSupabaseConfigured)
          Text(
            '未配置：运行示例\n'
            'flutter run --dart-define=SUPABASE_URL=... '
            '--dart-define=SUPABASE_ANON_KEY=...',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else ...[
          TextField(
            controller: model.emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: model.passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: callbacks.onSignIn, child: const Text('登录')),
              OutlinedButton(onPressed: callbacks.onSignUp, child: const Text('注册')),
              if (model.signedIn)
                TextButton(onPressed: callbacks.onSignOut, child: const Text('退出')),
            ],
          ),
          if (model.signedIn) _AuthSignedInPanel(model: model, callbacks: callbacks),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('已登录 user: ${model.session?.user.id ?? ''}'),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingMe ? null : callbacks.onCallMe,
          child: Text(model.loadingMe ? '请求中…' : 'GET /api/v1/me (Bearer)'),
        ),
        if (model.meBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('/me: ${model.meBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingDevSwitchProbe ? null : callbacks.onCallDevSwitchProbe,
          child: Text(
            model.loadingDevSwitchProbe
                ? '请求中…'
                : 'GET+PUT /api/v1/settings/dev/switch-ai-tool',
          ),
        ),
        if (model.devSwitchProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('dev switch: ${model.devSwitchProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              model.loadingMemoryConfigProbe ? null : callbacks.onCallMemoryConfigProbe,
          child: Text(
            model.loadingMemoryConfigProbe
                ? '请求中…'
                : 'memory-config GET+POST + clear-agent-memories',
          ),
        ),
        if (model.memoryConfigProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('memory-config: ${model.memoryConfigProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingAboutProbe ? null : callbacks.onCallAboutProbe,
          child: Text(
            model.loadingAboutProbe
                ? '请求中…'
                : 'POST …/settings/about/check-update + download-app',
          ),
        ),
        if (model.aboutProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('about: ${model.aboutProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingUsageSummary ? null : callbacks.onCallUsageSummary,
          child: Text(
            model.loadingUsageSummary ? '请求中…' : 'GET /api/v1/usage/summary',
          ),
        ),
        if (model.usageSummaryBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('usage: ${model.usageSummaryBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: model.loadingPromptsProbe ? null : callbacks.onCallPromptsProbe,
          child: Text(
            model.loadingPromptsProbe ? '请求中…' : 'GET /api/v1/prompts + GET/1 + PATCH/1',
          ),
        ),
        if (model.promptsProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('prompts: ${model.promptsProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              model.loadingVisualManualProbe ? null : callbacks.onCallVisualManualProbe,
          child: Text(
            model.loadingVisualManualProbe ? '请求中…' : 'GET+POST /api/v1/visual-manual',
          ),
        ),
        if (model.visualManualProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('visual-manual: ${model.visualManualProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              model.loadingDirectorManualProbe ? null : callbacks.onCallDirectorManualProbe,
          child: Text(
            model.loadingDirectorManualProbe
                ? '请求中…'
                : 'POST …/project/query-director-manual',
          ),
        ),
        if (model.directorManualProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('director-manual: ${model.directorManualProbeBody}'),
        ],
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              model.loadingSkillsBinaryProbe ? null : callbacks.onCallSkillsBinaryProbe,
          child: Text(
            model.loadingSkillsBinaryProbe
                ? '请求中…'
                : 'GET /api/v1/skills/binary (_smoke PNG)',
          ),
        ),
        if (model.skillsBinaryProbeBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('skills/binary: ${model.skillsBinaryProbeBody}'),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: model.loadingModelsCatalog ? null : callbacks.onCallModelsCatalog,
              child: Text(
                model.loadingModelsCatalog
                    ? '请求中…'
                    : 'models + vendors + vendor-add + danger + production + agent-deploy + model-test + script-agent + assets-gen',
              ),
            ),
            FilledButton.tonal(
              onPressed:
                  model.loadingTextModelDefault ? null : callbacks.onCallTextModelDefault,
              child: Text(
                model.loadingTextModelDefault
                    ? '请求中…'
                    : 'GET+PATCH /api/v1/models/text-default',
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingModelDetail ? null : callbacks.onCallModelDetail,
              child: Text(
                model.loadingModelDetail
                    ? '请求中…'
                    : 'GET /api/v1/models/detail (1:gpt-4o-mini)',
              ),
            ),
          ],
        ),
        if (model.modelsCatalogBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('models: ${model.modelsCatalogBody}'),
        ],
        if (model.textModelDefaultBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('text-default: ${model.textModelDefaultBody}'),
        ],
        if (model.modelDetailBody != null) ...[
          const SizedBox(height: 8),
          SelectableText('model detail: ${model.modelDetailBody}'),
        ],
      ],
    );
  }
}

