part of 'section.dart';

/// Auth section view shell. Keeps the section file focused on wiring inputs and callbacks.
extension _AuthSectionView on AuthSection {
  Widget _buildAuthSectionView(BuildContext context) {
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
            controller: emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: onSignIn, child: const Text('登录')),
              OutlinedButton(onPressed: onSignUp, child: const Text('注册')),
              if (signedIn)
                TextButton(onPressed: onSignOut, child: const Text('退出')),
            ],
          ),
          if (signedIn) ...[
            const SizedBox(height: 12),
            Text('已登录 user: ${session?.user.id ?? ''}'),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingMe ? null : onCallMe,
              child: Text(loadingMe ? '请求中…' : 'GET /api/v1/me (Bearer)'),
            ),
            if (meBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('/me: $meBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingDevSwitchProbe ? null : onCallDevSwitchProbe,
              child: Text(
                loadingDevSwitchProbe
                    ? '请求中…'
                    : 'GET+PUT /api/v1/settings/dev/switch-ai-tool',
              ),
            ),
            if (devSwitchProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('dev switch: $devSwitchProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingMemoryConfigProbe
                  ? null
                  : onCallMemoryConfigProbe,
              child: Text(
                loadingMemoryConfigProbe
                    ? '请求中…'
                    : 'memory-config GET+POST + clear-agent-memories',
              ),
            ),
            if (memoryConfigProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('memory-config: $memoryConfigProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingAboutProbe ? null : onCallAboutProbe,
              child: Text(
                loadingAboutProbe
                    ? '请求中…'
                    : 'POST …/settings/about/check-update + download-app',
              ),
            ),
            if (aboutProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('about: $aboutProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingUsageSummary ? null : onCallUsageSummary,
              child: Text(
                loadingUsageSummary ? '请求中…' : 'GET /api/v1/usage/summary',
              ),
            ),
            if (usageSummaryBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('usage: $usageSummaryBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingPromptsProbe ? null : onCallPromptsProbe,
              child: Text(
                loadingPromptsProbe
                    ? '请求中…'
                    : 'GET /api/v1/prompts + GET/1 + PATCH/1',
              ),
            ),
            if (promptsProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('prompts: $promptsProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingVisualManualProbe
                  ? null
                  : onCallVisualManualProbe,
              child: Text(
                loadingVisualManualProbe
                    ? '请求中…'
                    : 'GET+POST /api/v1/visual-manual',
              ),
            ),
            if (visualManualProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('visual-manual: $visualManualProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingDirectorManualProbe
                  ? null
                  : onCallDirectorManualProbe,
              child: Text(
                loadingDirectorManualProbe
                    ? '请求中…'
                    : 'POST …/project/query-director-manual',
              ),
            ),
            if (directorManualProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('director-manual: $directorManualProbeBody'),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loadingSkillsBinaryProbe
                  ? null
                  : onCallSkillsBinaryProbe,
              child: Text(
                loadingSkillsBinaryProbe
                    ? '请求中…'
                    : 'GET /api/v1/skills/binary (_smoke PNG)',
              ),
            ),
            if (skillsBinaryProbeBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('skills/binary: $skillsBinaryProbeBody'),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: loadingModelsCatalog ? null : onCallModelsCatalog,
                  child: Text(
                    loadingModelsCatalog
                        ? '请求中…'
                        : 'models + vendors + vendor-add + danger + production + agent-deploy + model-test + script-agent + assets-gen',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: loadingTextModelDefault
                      ? null
                      : onCallTextModelDefault,
                  child: Text(
                    loadingTextModelDefault
                        ? '请求中…'
                        : 'GET+PATCH /api/v1/models/text-default',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: loadingModelDetail ? null : onCallModelDetail,
                  child: Text(
                    loadingModelDetail
                        ? '请求中…'
                        : 'GET /api/v1/models/detail (1:gpt-4o-mini)',
                  ),
                ),
              ],
            ),
            if (modelsCatalogBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('models: $modelsCatalogBody'),
            ],
            if (textModelDefaultBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('text-default: $textModelDefaultBody'),
            ],
            if (modelDetailBody != null) ...[
              const SizedBox(height: 8),
              SelectableText('model detail: $modelDetailBody'),
            ],
          ],
        ],
      ],
    );
  }
}
