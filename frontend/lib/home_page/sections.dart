import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../rust_api.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({
    super.key,
    required this.apiBaseUrl,
    required this.loadingHealth,
    required this.loadingHealthRoot,
    required this.loadingPing,
    required this.loadingVersion,
    required this.loadingReady,
    required this.healthBody,
    required this.healthRootBody,
    required this.pingBody,
    required this.versionBody,
    required this.readyBody,
    required this.onPingHealth,
    required this.onPingHealthRoot,
    required this.onPingPing,
    required this.onPingVersion,
    required this.onPingReady,
  });

  final String apiBaseUrl;
  final bool loadingHealth;
  final bool loadingHealthRoot;
  final bool loadingPing;
  final bool loadingVersion;
  final bool loadingReady;
  final String? healthBody;
  final String? healthRootBody;
  final String? pingBody;
  final String? versionBody;
  final String? readyBody;
  final VoidCallback onPingHealth;
  final VoidCallback onPingHealthRoot;
  final VoidCallback onPingPing;
  final VoidCallback onPingVersion;
  final VoidCallback onPingReady;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('API: $apiBaseUrl', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: loadingHealth ? null : onPingHealth,
              child: Text(loadingHealth ? '请求中…' : 'GET /api/v1/health'),
            ),
            FilledButton.tonal(
              onPressed: loadingHealthRoot ? null : onPingHealthRoot,
              child: Text(loadingHealthRoot ? '请求中…' : 'GET /health'),
            ),
            FilledButton.tonal(
              onPressed: loadingPing ? null : onPingPing,
              child: Text(loadingPing ? '请求中…' : 'GET /api/v1/ping'),
            ),
          ],
        ),
        if (healthBody != null) ...[
          const SizedBox(height: 8),
          Text('health (v1): $healthBody'),
        ],
        if (healthRootBody != null) ...[
          const SizedBox(height: 8),
          Text('health (root): $healthRootBody'),
        ],
        if (pingBody != null) ...[
          const SizedBox(height: 8),
          Text('ping: $pingBody'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: loadingVersion ? null : onPingVersion,
          child: Text(loadingVersion ? '请求中…' : 'GET /api/v1/version'),
        ),
        if (versionBody != null) ...[
          const SizedBox(height: 8),
          Text('version: $versionBody'),
        ],
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: loadingReady ? null : onPingReady,
          child: Text(loadingReady ? '请求中…' : 'GET /api/v1/ready'),
        ),
        if (readyBody != null) ...[
          const SizedBox(height: 8),
          Text('ready: $readyBody'),
        ],
      ],
    );
  }
}

class AuthSection extends StatelessWidget {
  const AuthSection({
    super.key,
    required this.signedIn,
    required this.session,
    required this.emailController,
    required this.passwordController,
    required this.loadingMe,
    required this.loadingDevSwitchProbe,
    required this.loadingMemoryConfigProbe,
    required this.loadingAboutProbe,
    required this.loadingUsageSummary,
    required this.loadingPromptsProbe,
    required this.loadingVisualManualProbe,
    required this.loadingDirectorManualProbe,
    required this.loadingSkillsBinaryProbe,
    required this.loadingModelsCatalog,
    required this.loadingTextModelDefault,
    required this.loadingModelDetail,
    required this.meBody,
    required this.devSwitchProbeBody,
    required this.memoryConfigProbeBody,
    required this.aboutProbeBody,
    required this.usageSummaryBody,
    required this.promptsProbeBody,
    required this.visualManualProbeBody,
    required this.directorManualProbeBody,
    required this.skillsBinaryProbeBody,
    required this.modelsCatalogBody,
    required this.textModelDefaultBody,
    required this.modelDetailBody,
    required this.onSignIn,
    required this.onSignUp,
    required this.onSignOut,
    required this.onCallMe,
    required this.onCallDevSwitchProbe,
    required this.onCallMemoryConfigProbe,
    required this.onCallAboutProbe,
    required this.onCallUsageSummary,
    required this.onCallPromptsProbe,
    required this.onCallVisualManualProbe,
    required this.onCallDirectorManualProbe,
    required this.onCallSkillsBinaryProbe,
    required this.onCallModelsCatalog,
    required this.onCallTextModelDefault,
    required this.onCallModelDetail,
  });

  final bool signedIn;
  final Session? session;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loadingMe;
  final bool loadingDevSwitchProbe;
  final bool loadingMemoryConfigProbe;
  final bool loadingAboutProbe;
  final bool loadingUsageSummary;
  final bool loadingPromptsProbe;
  final bool loadingVisualManualProbe;
  final bool loadingDirectorManualProbe;
  final bool loadingSkillsBinaryProbe;
  final bool loadingModelsCatalog;
  final bool loadingTextModelDefault;
  final bool loadingModelDetail;
  final String? meBody;
  final String? devSwitchProbeBody;
  final String? memoryConfigProbeBody;
  final String? aboutProbeBody;
  final String? usageSummaryBody;
  final String? promptsProbeBody;
  final String? visualManualProbeBody;
  final String? directorManualProbeBody;
  final String? skillsBinaryProbeBody;
  final String? modelsCatalogBody;
  final String? textModelDefaultBody;
  final String? modelDetailBody;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;
  final VoidCallback onSignOut;
  final VoidCallback onCallMe;
  final VoidCallback onCallDevSwitchProbe;
  final VoidCallback onCallMemoryConfigProbe;
  final VoidCallback onCallAboutProbe;
  final VoidCallback onCallUsageSummary;
  final VoidCallback onCallPromptsProbe;
  final VoidCallback onCallVisualManualProbe;
  final VoidCallback onCallDirectorManualProbe;
  final VoidCallback onCallSkillsBinaryProbe;
  final VoidCallback onCallModelsCatalog;
  final VoidCallback onCallTextModelDefault;
  final VoidCallback onCallModelDetail;

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
                        : 'GET /api/v1/models/text-default',
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

class ProjectsSection extends StatelessWidget {
  const ProjectsSection({
    super.key,
    required this.loadingProjects,
    required this.loadingProjectsSummary,
    required this.loadingArtStyles,
    required this.creatingProject,
    required this.loadingAgentMemory,
    required this.projects,
    required this.projectsSummaryLine,
    required this.artStylesLine,
    required this.agentMemoryBody,
    required this.onLoadProjects,
    required this.onLoadProjectsSummary,
    required this.onLoadArtStyles,
    required this.onCreateEmptyProject,
    required this.onOpenProjectDetail,
    required this.onProbeAgentMemory,
  });

  final bool loadingProjects;
  final bool loadingProjectsSummary;
  final bool loadingArtStyles;
  final bool creatingProject;
  final bool loadingAgentMemory;
  final List<ProjectRow>? projects;
  final String? projectsSummaryLine;
  final String? artStylesLine;
  final String? agentMemoryBody;
  final VoidCallback onLoadProjects;
  final VoidCallback onLoadProjectsSummary;
  final VoidCallback onLoadArtStyles;
  final VoidCallback onCreateEmptyProject;
  final ValueChanged<ProjectRow> onOpenProjectDetail;
  final VoidCallback onProbeAgentMemory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Projects (RLS + Postgres)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onLoadProjects,
              child: Text(loadingProjects ? '加载中…' : 'GET /api/v1/projects'),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjectsSummary || creatingProject)
                  ? null
                  : onLoadProjectsSummary,
              child: Text(
                loadingProjectsSummary ? '加载中…' : 'GET …/projects/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: (loadingArtStyles || creatingProject)
                  ? null
                  : onLoadArtStyles,
              child: Text(
                loadingArtStyles ? '加载中…' : 'GET …/art-styles + CRUD 探针',
              ),
            ),
            FilledButton.tonal(
              onPressed: (loadingProjects || creatingProject)
                  ? null
                  : onCreateEmptyProject,
              child: Text(creatingProject ? '创建中…' : 'POST /api/v1/projects'),
            ),
          ],
        ),
        if (projectsSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('summary: $projectsSummaryLine'),
        ],
        if (artStylesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('art-styles: $artStylesLine'),
        ],
        if (projects != null) ...[
          const SizedBox(height: 12),
          Text(
            '${projects!.length} project(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...projects!.map(
            (project) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(project.name ?? 'legacy #${project.legacyId}'),
              subtitle: Text('legacy_id=${project.legacyId} · ${project.id}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenProjectDetail(project),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: loadingAgentMemory ? null : onProbeAgentMemory,
            child: Text(
              loadingAgentMemory
                  ? '请求中…'
                  : 'POST /api/v1/agents/memory/query (first project)',
            ),
          ),
          if (agentMemoryBody != null) ...[
            const SizedBox(height: 8),
            SelectableText('agent memory: $agentMemoryBody'),
          ],
        ],
      ],
    );
  }
}

class JobsSection extends StatelessWidget {
  const JobsSection({
    super.key,
    required this.loadingJobs,
    required this.loadingJobKinds,
    required this.loadingJobKindSummary,
    required this.loadingJobStatusSummary,
    required this.creatingJob,
    required this.loadingJobById,
    required this.jobIdController,
    required this.jobs,
    required this.jobByIdLine,
    required this.jobKindsLine,
    required this.jobKindSummaryLine,
    required this.jobStatusSummaryLine,
    required this.cancellingJobId,
    required this.retryingJobId,
    required this.onJobIdChanged,
    required this.onLoadJobs,
    required this.onLoadJobsKindFlutterProbe,
    required this.onLoadJobsStatusFailed,
    required this.onLoadJobsKindProbeStatusQueued,
    required this.onLoadJobKinds,
    required this.onLoadJobKindSummary,
    required this.onLoadJobStatusSummary,
    required this.onCreateProbeJob,
    required this.onFetchJobById,
    required this.onSelectJob,
    required this.onRetryFailedJob,
    required this.onCancelQueuedJob,
  });

  final bool loadingJobs;
  final bool loadingJobKinds;
  final bool loadingJobKindSummary;
  final bool loadingJobStatusSummary;
  final bool creatingJob;
  final bool loadingJobById;
  final TextEditingController jobIdController;
  final List<JobRow>? jobs;
  final String? jobByIdLine;
  final String? jobKindsLine;
  final String? jobKindSummaryLine;
  final String? jobStatusSummaryLine;
  final String? cancellingJobId;
  final String? retryingJobId;
  final ValueChanged<String> onJobIdChanged;
  final VoidCallback onLoadJobs;
  final VoidCallback onLoadJobsKindFlutterProbe;
  final VoidCallback onLoadJobsStatusFailed;
  final VoidCallback onLoadJobsKindProbeStatusQueued;
  final VoidCallback onLoadJobKinds;
  final VoidCallback onLoadJobKindSummary;
  final VoidCallback onLoadJobStatusSummary;
  final VoidCallback onCreateProbeJob;
  final VoidCallback onFetchJobById;
  final ValueChanged<JobRow> onSelectJob;
  final ValueChanged<JobRow> onRetryFailedJob;
  final ValueChanged<JobRow> onCancelQueuedJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Generation jobs', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobs,
              child: Text(loadingJobs ? '…' : 'GET /api/v1/jobs'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsKindFlutterProbe,
              child: const Text('GET jobs?kind=flutter.probe'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsStatusFailed,
              child: const Text('GET jobs?status=failed'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsKindProbeStatusQueued,
              child: const Text('GET jobs?kind=flutter.probe&status=queued'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKinds ? null : onLoadJobKinds,
              child: Text(loadingJobKinds ? '…' : 'GET /api/v1/jobs/kinds'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKindSummary ? null : onLoadJobKindSummary,
              child: Text(
                loadingJobKindSummary ? '…' : 'GET …/jobs/kinds/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingJobStatusSummary
                  ? null
                  : onLoadJobStatusSummary,
              child: Text(
                loadingJobStatusSummary ? '…' : 'GET …/jobs/status/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: creatingJob ? null : onCreateProbeJob,
              child: Text(creatingJob ? '…' : 'POST job (flutter.probe)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: jobIdController,
          onChanged: onJobIdChanged,
          decoration: const InputDecoration(
            labelText: 'Job id (tap a row below to paste)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: (loadingJobById || jobIdController.text.trim().isEmpty)
              ? null
              : onFetchJobById,
          child: Text(loadingJobById ? '…' : 'GET /api/v1/jobs/{id}'),
        ),
        if (jobByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'job by id: $jobByIdLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (jobKindsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job kinds: $jobKindsLine'),
        ],
        if (jobKindSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job kinds/summary: $jobKindSummaryLine'),
        ],
        if (jobStatusSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job status/summary: $jobStatusSummaryLine'),
        ],
        if (jobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${jobs!.length} job(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...jobs!
              .take(8)
              .map(
                (job) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${job.kind} · ${job.status}'),
                  subtitle: Text(
                    [
                      job.id,
                      if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
                        'claimed_by=${job.claimedBy}',
                    ].join(' · '),
                  ),
                  onTap: () => onSelectJob(job),
                  trailing:
                      (job.status == 'failed' ||
                          job.status == 'queued' ||
                          job.status == 'running')
                      ? Wrap(
                          spacing: 4,
                          children: [
                            if (job.status == 'failed')
                              TextButton(
                                onPressed: retryingJobId == job.id
                                    ? null
                                    : () => onRetryFailedJob(job),
                                child: Text(
                                  retryingJobId == job.id ? '…' : '重试',
                                ),
                              ),
                            if (job.status == 'queued' ||
                                job.status == 'running')
                              TextButton(
                                onPressed: cancellingJobId == job.id
                                    ? null
                                    : () => onCancelQueuedJob(job),
                                child: Text(
                                  cancellingJobId == job.id ? '…' : '取消',
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
              ),
        ],
      ],
    );
  }
}

class HarnessSection extends StatelessWidget {
  const HarnessSection({
    super.key,
    required this.loadingHarnessTools,
    required this.loadingSkillsSummary,
    required this.loadingSkillList,
    required this.loadingSkillPreview,
    required this.loadingSkillPut,
    required this.loadingSkillPost,
    required this.loadingSkillDelete,
    required this.wsProbesBusy,
    required this.loadingWs,
    required this.loadingWsHarness,
    required this.loadingWsIsolatedEcho,
    required this.loadingWsSkillsRead,
    required this.loadingWsHarnessAgent,
    required this.harnessToolsLine,
    required this.skillsAggregateLine,
    required this.skillsListSummary,
    required this.skillMutationLine,
    required this.skillPathController,
    required this.skillContentController,
    required this.wsLog,
    required this.onLoadHarnessTools,
    required this.onLoadSkillsAggregate,
    required this.onLoadSkillList,
    required this.onPreviewSkillFile,
    required this.onPutSkillProbe,
    required this.onPostSkillProbe,
    required this.onDeleteSkillProbe,
    required this.onTestWebSocket,
    required this.onTestHarnessToolWebSocket,
    required this.onTestHarnessIsolatedEchoWebSocket,
    required this.onTestHarnessSkillsReadWebSocket,
    required this.onTestHarnessAgentRunWebSocket,
  });

  final bool loadingHarnessTools;
  final bool loadingSkillsSummary;
  final bool loadingSkillList;
  final bool loadingSkillPreview;
  final bool loadingSkillPut;
  final bool loadingSkillPost;
  final bool loadingSkillDelete;
  final bool wsProbesBusy;
  final bool loadingWs;
  final bool loadingWsHarness;
  final bool loadingWsIsolatedEcho;
  final bool loadingWsSkillsRead;
  final bool loadingWsHarnessAgent;
  final String? harnessToolsLine;
  final String? skillsAggregateLine;
  final String? skillsListSummary;
  final String? skillMutationLine;
  final TextEditingController skillPathController;
  final TextEditingController skillContentController;
  final List<String> wsLog;
  final VoidCallback onLoadHarnessTools;
  final VoidCallback onLoadSkillsAggregate;
  final VoidCallback onLoadSkillList;
  final VoidCallback onPreviewSkillFile;
  final VoidCallback onPutSkillProbe;
  final VoidCallback onPostSkillProbe;
  final VoidCallback onDeleteSkillProbe;
  final VoidCallback onTestWebSocket;
  final VoidCallback onTestHarnessToolWebSocket;
  final VoidCallback onTestHarnessIsolatedEchoWebSocket;
  final VoidCallback onTestHarnessSkillsReadWebSocket;
  final VoidCallback onTestHarnessAgentRunWebSocket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Harness / skills', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingHarnessTools ? null : onLoadHarnessTools,
              child: Text(
                loadingHarnessTools ? '…' : 'GET /api/v1/harness/tools',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillsSummary ? null : onLoadSkillsAggregate,
              child: Text(
                loadingSkillsSummary ? '…' : 'GET /api/v1/skills/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillList ? null : onLoadSkillList,
              child: Text(loadingSkillList ? '…' : 'GET /api/v1/skills'),
            ),
          ],
        ),
        if (harnessToolsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'tools: $harnessToolsLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsAggregateLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'summary: $skillsAggregateLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (skillsListSummary != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            skillsListSummary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: skillPathController,
          decoration: const InputDecoration(
            labelText: 'Skill relative path',
            helperText:
                'POST needs a path that does not exist yet under data/skills',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: skillContentController,
          decoration: const InputDecoration(labelText: 'Body for PUT / POST'),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingSkillPreview ? null : onPreviewSkillFile,
              child: Text(
                loadingSkillPreview ? '…' : 'GET /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillPut ? null : onPutSkillProbe,
              child: Text(loadingSkillPut ? '…' : 'PUT /api/v1/skills/content'),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillPost ? null : onPostSkillProbe,
              child: Text(
                loadingSkillPost ? '…' : 'POST /api/v1/skills/content',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingSkillDelete ? null : onDeleteSkillProbe,
              child: Text(
                loadingSkillDelete ? '…' : 'DELETE /api/v1/skills/content',
              ),
            ),
          ],
        ),
        if (skillMutationLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            skillMutationLine!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestWebSocket,
              child: Text(loadingWs ? '…' : 'WebSocket: attach + LLM stream'),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessToolWebSocket,
              child: Text(
                loadingWsHarness ? '…' : 'WS: harness.tool.invoke (echo)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy
                  ? null
                  : onTestHarnessIsolatedEchoWebSocket,
              child: Text(
                loadingWsIsolatedEcho ? '…' : 'WS: isolated.echo (subprocess)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessSkillsReadWebSocket,
              child: Text(
                loadingWsSkillsRead ? '…' : 'WS: skills.read (path field)',
              ),
            ),
            FilledButton.tonal(
              onPressed: wsProbesBusy ? null : onTestHarnessAgentRunWebSocket,
              child: Text(
                loadingWsHarnessAgent
                    ? '…'
                    : 'WS: harness.agent.run (needs LLM key)',
              ),
            ),
          ],
        ),
        if (wsLog.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('WS 最近消息:', style: Theme.of(context).textTheme.labelLarge),
          ...wsLog.map(
            (line) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                line,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
