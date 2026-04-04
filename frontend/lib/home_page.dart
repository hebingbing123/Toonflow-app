import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';
import 'rust_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  StreamSubscription<AuthState>? _authSub;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;

  String? _healthBody;
  String? _meBody;
  String? _error;
  bool _loadingHealth = false;
  bool _loadingMe = false;
  bool _loadingWs = false;
  final List<String> _wsLog = [];

  bool _loadingProjects = false;
  List<ProjectRow>? _projects;

  bool _loadingJobs = false;
  bool _creatingJob = false;
  String? _cancellingJobId;
  String? _retryingJobId;
  List<JobRow>? _jobs;

  final _skillPathCtrl =
      TextEditingController(text: 'script_execution_script.md');

  bool _loadingHarnessTools = false;
  bool _loadingSkillList = false;
  bool _loadingSkillPreview = false;
  String? _harnessToolsLine;
  String? _skillsListSummary;

  @override
  void initState() {
    super.initState();
    if (kSupabaseConfigured) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _email.dispose();
    _password.dispose();
    _skillPathCtrl.dispose();
    super.dispose();
  }

  Session? get _session =>
      kSupabaseConfigured ? Supabase.instance.client.auth.currentSession : null;

  Future<void> _pingHealth() async {
    setState(() {
      _loadingHealth = true;
      _error = null;
      _healthBody = null;
    });
    final uri = Uri.parse('$kApiBaseUrl/api/v1/health');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _healthBody = map.toString();
          _loadingHealth = false;
        });
      } else {
        setState(() {
          _error = 'health HTTP ${res.statusCode}';
          _loadingHealth = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingHealth = false;
      });
    }
  }

  Future<void> _callMe() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingMe = true;
      _error = null;
      _meBody = null;
    });
    final uri = Uri.parse('$kApiBaseUrl/api/v1/me');
    try {
      final res = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        setState(() {
          _meBody = res.body;
          _loadingMe = false;
        });
      } else {
        setState(() {
          _error = '/me HTTP ${res.statusCode}: ${res.body}';
          _loadingMe = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingMe = false;
      });
    }
  }

  Future<void> _signIn() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signUp() async {
    setState(() => _error = null);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    _wsSub?.cancel();
    _ws?.sink.close();
    _ws = null;
    _wsSub = null;
    setState(() {
      _wsLog.clear();
      _projects = null;
      _jobs = null;
      _harnessToolsLine = null;
      _skillsListSummary = null;
    });
  }

  Future<void> _loadHarnessTools() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingHarnessTools = true;
      _error = null;
      _harnessToolsLine = null;
    });
    try {
      final r = await fetchHarnessTools(token);
      if (!mounted) return;
      setState(() {
        _harnessToolsLine = r.tools
            .map((t) => '${t.name}: ${t.description}')
            .join('\n');
        _loadingHarnessTools = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingHarnessTools = false;
      });
    }
  }

  Future<void> _loadSkillList() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingSkillList = true;
      _error = null;
      _skillsListSummary = null;
    });
    try {
      final list = await fetchSkills(token);
      if (!mounted) return;
      final sample = list.take(5).map((m) => m.path).join(', ');
      setState(() {
        _skillsListSummary =
            '${list.length} files; sample: ${sample.isEmpty ? '—' : sample}';
        _loadingSkillList = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillList = false;
      });
    }
  }

  Future<void> _previewSkillFile() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final path = _skillPathCtrl.text.trim();
    if (path.isEmpty) return;
    setState(() {
      _loadingSkillPreview = true;
      _error = null;
    });
    try {
      final r = await fetchSkillContent(token, path);
      if (!mounted) return;
      setState(() => _loadingSkillPreview = false);
      final text = r.content.length > 12000
          ? '${r.content.substring(0, 12000)}…\n\n(truncated)'
          : r.content;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(r.path),
          content: SingleChildScrollView(
            child: SelectableText(text, style: Theme.of(ctx).textTheme.bodySmall),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingSkillPreview = false;
      });
    }
  }

  Future<void> _loadJobs() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingJobs = true;
      _error = null;
      _jobs = null;
    });
    try {
      final list = await fetchJobs(token);
      if (!mounted) return;
      setState(() {
        _jobs = list;
        _loadingJobs = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingJobs = false;
      });
    }
  }

  Future<void> _cancelQueuedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || (j.status != 'queued' && j.status != 'running')) {
      return;
    }
    setState(() {
      _cancellingJobId = j.id;
      _error = null;
    });
    try {
      await cancelJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _cancellingJobId = null);
      }
    }
  }

  Future<void> _retryFailedJob(JobRow j) async {
    final token = _session?.accessToken;
    if (token == null || j.status != 'failed') return;
    setState(() {
      _retryingJobId = j.id;
      _error = null;
    });
    try {
      await retryJob(token, j.id);
      if (!mounted) return;
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _retryingJobId = null);
      }
    }
  }

  Future<void> _createProbeJob() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _creatingJob = true;
      _error = null;
    });
    try {
      await createJob(token, 'flutter.probe');
      if (!mounted) return;
      setState(() => _creatingJob = false);
      await _loadJobs();
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _creatingJob = false;
      });
    }
  }

  Future<void> _loadProjects() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingProjects = true;
      _error = null;
      _projects = null;
    });
    try {
      final list = await fetchProjects(token);
      if (!mounted) return;
      setState(() {
        _projects = list;
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingProjects = false;
      });
    }
  }

  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    try {
      final detail = await fetchProjectByLegacyId(token, p.legacyId);
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text(
                  detail.project.name ?? 'legacy #${detail.project.legacyId}',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: introCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Intro (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('${detail.scripts.length} script(s)'),
                      const SizedBox(height: 8),
                      ...detail.scripts.map(
                        (s) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '#${s.legacyId} ${s.name ?? ""}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: saving[0]
                              ? null
                              : () => _openScriptEditor(token, s.legacyId),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            try {
                              await updateProjectByLegacyId(token, p.legacyId, {
                                'name': nameCtrl.text.isEmpty
                                    ? null
                                    : nameCtrl.text,
                                'intro': introCtrl.text.isEmpty
                                    ? null
                                    : introCtrl.text,
                              });
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              await _loadProjects();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      nameCtrl.dispose();
      introCtrl.dispose();
    }
  }

  Future<void> _openScriptEditor(String token, int scriptLegacyId) async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    try {
      final script = await fetchScriptByLegacyId(token, scriptLegacyId);
      if (!mounted) return;
      nameCtrl.text = script.name ?? '';
      contentCtrl.text = script.content ?? '';
      stateCtrl.text = script.extractState?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Script #${script.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: contentCtrl,
                        minLines: 4,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          labelText: 'Content (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: stateCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'extract_state (empty = clear)',
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: saving[0]
                              ? null
                              : () async {
                                  try {
                                    final boards =
                                        await fetchStoryboardsForScript(
                                      token,
                                      scriptLegacyId,
                                    );
                                    if (!mounted) return;
                                    await showDialog<void>(
                                      context: context,
                                      builder: (ctx2) => AlertDialog(
                                        title: Text('分镜 (${boards.length})'),
                                        content: SizedBox(
                                          width: double.maxFinite,
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: boards.length,
                                            itemBuilder: (_, i) {
                                              final b = boards[i];
                                              return ListTile(
                                                title: Text(
                                                  '#${b.legacyId} ${b.state ?? ""}',
                                                ),
                                                subtitle: Text(
                                                  b.prompt ?? '',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onTap: () {
                                                  Navigator.of(ctx2).pop();
                                                  _openStoryboardEditor(
                                                    token,
                                                    b.legacyId,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx2).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } on RustApiException catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text(e.toString())),
                                      );
                                    }
                                  }
                                },
                          child: const Text('分镜列表…'),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? extractParsed;
                            final st = stateCtrl.text.trim();
                            if (st.isNotEmpty) {
                              extractParsed = int.tryParse(st);
                              if (extractParsed == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('extract_state 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateScriptByLegacyId(
                                token,
                                scriptLegacyId,
                                {
                                  'name': nameCtrl.text.isEmpty
                                      ? null
                                      : nameCtrl.text,
                                  'content': contentCtrl.text.isEmpty
                                      ? null
                                      : contentCtrl.text,
                                  'extract_state': st.isEmpty
                                      ? null
                                      : extractParsed,
                                },
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      nameCtrl.dispose();
      contentCtrl.dispose();
      stateCtrl.dispose();
    }
  }

  Future<void> _openStoryboardEditor(String token, int storyLegacyId) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByLegacyId(token, storyLegacyId);
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Storyboard #${row.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: promptCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'prompt (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'state (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: videoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'video_desc (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sbIdxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'sb_index (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sgiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'should_generate_image (empty = clear)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? sbIdx;
                            final sbs = sbIdxCtrl.text.trim();
                            if (sbs.isNotEmpty) {
                              sbIdx = int.tryParse(sbs);
                              if (sbIdx == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('sb_index 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            int? sgi;
                            final sgis = sgiCtrl.text.trim();
                            if (sgis.isNotEmpty) {
                              sgi = int.tryParse(sgis);
                              if (sgi == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'should_generate_image 须为整数',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                                {
                                  'prompt': promptCtrl.text.isEmpty
                                      ? null
                                      : promptCtrl.text,
                                  'state': stateCtrl.text.isEmpty
                                      ? null
                                      : stateCtrl.text,
                                  'video_desc': videoCtrl.text.isEmpty
                                      ? null
                                      : videoCtrl.text,
                                  'sb_index': sbs.isEmpty ? null : sbIdx,
                                  'should_generate_image':
                                      sgis.isEmpty ? null : sgi,
                                },
                              );
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      promptCtrl.dispose();
      stateCtrl.dispose();
      videoCtrl.dispose();
      sbIdxCtrl.dispose();
      sgiCtrl.dispose();
    }
  }

  Future<void> _testWebSocket() async {
    final token = _session?.accessToken;
    if (token == null) return;

    _wsSub?.cancel();
    await _ws?.sink.close();

    setState(() {
      _loadingWs = true;
      _wsLog.clear();
      _error = null;
    });

    try {
      final uri = rustWebSocketUri(kApiBaseUrl, accessToken: token);
      final channel = WebSocketChannel.connect(uri);
      _ws = channel;

      _wsSub = channel.stream.listen(
        (message) {
          if (!mounted) return;
          setState(() {
            _wsLog.insert(0, message.toString());
            if (_wsLog.length > 12) _wsLog.removeLast();
          });
        },
        onError: (Object e) {
          if (mounted) setState(() => _error = 'ws: $e');
        },
        onDone: () {
          if (mounted) setState(() => _loadingWs = false);
        },
      );

      channel.sink.add(
        jsonEncode({
          'type': 'agent.script.attach',
          'schema_version': 1,
          'payload': {
            'isolation_key': 'flutter-dev',
            'project_id': 1,
          },
        }),
      );

      channel.sink.add(
        jsonEncode({
          'type': 'agent.chat.send',
          'schema_version': 1,
          'payload': {'content': 'hello from Flutter'},
        }),
      );

      if (mounted) setState(() => _loadingWs = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingWs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final signedIn = session != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Toonflow'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('API: $kApiBaseUrl', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadingHealth ? null : _pingHealth,
            child: Text(_loadingHealth ? '请求中…' : 'GET /api/v1/health'),
          ),
          if (_healthBody != null) ...[
            const SizedBox(height: 8),
            Text('health: $_healthBody'),
          ],
          const Divider(height: 32),
          Text(
            'Supabase Auth',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _signIn, child: const Text('登录')),
                OutlinedButton(onPressed: _signUp, child: const Text('注册')),
                if (signedIn)
                  TextButton(onPressed: _signOut, child: const Text('退出')),
              ],
            ),
            if (signedIn) ...[
              const SizedBox(height: 12),
              Text('已登录 user: ${session.user.id}'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingMe ? null : _callMe,
                child: Text(_loadingMe ? '请求中…' : 'GET /api/v1/me (Bearer)'),
              ),
              if (_meBody != null) ...[
                const SizedBox(height: 8),
                SelectableText('/me: $_meBody'),
              ],
              const SizedBox(height: 16),
              Text(
                'Projects (RLS + Postgres)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingProjects ? null : _loadProjects,
                child: Text(
                  _loadingProjects ? '加载中…' : 'GET /api/v1/projects',
                ),
              ),
              if (_projects != null) ...[
                const SizedBox(height: 12),
                Text(
                  '${_projects!.length} project(s)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._projects!.map(
                  (p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.name ?? 'legacy #${p.legacyId}'),
                    subtitle: Text('legacy_id=${p.legacyId} · ${p.id}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openProjectDetail(p),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Generation jobs',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingJobs ? null : _loadJobs,
                    child: Text(
                      _loadingJobs ? '…' : 'GET /api/v1/jobs',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _creatingJob ? null : _createProbeJob,
                    child: Text(
                      _creatingJob ? '…' : 'POST job (flutter.probe)',
                    ),
                  ),
                ],
              ),
              if (_jobs != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_jobs!.length} job(s)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._jobs!.take(8).map(
                      (j) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${j.kind} · ${j.status}'),
                        subtitle: Text(j.id),
                        trailing: (j.status == 'failed' ||
                                j.status == 'queued' ||
                                j.status == 'running')
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  if (j.status == 'failed')
                                    TextButton(
                                      onPressed: _retryingJobId == j.id
                                          ? null
                                          : () => _retryFailedJob(j),
                                      child: Text(
                                        _retryingJobId == j.id ? '…' : '重试',
                                      ),
                                    ),
                                  if (j.status == 'queued' ||
                                      j.status == 'running')
                                    TextButton(
                                      onPressed: _cancellingJobId == j.id
                                          ? null
                                          : () => _cancelQueuedJob(j),
                                      child: Text(
                                        _cancellingJobId == j.id ? '…' : '取消',
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
              ],
              const SizedBox(height: 16),
              Text(
                'Harness / skills (read-only)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingHarnessTools ? null : _loadHarnessTools,
                    child: Text(
                      _loadingHarnessTools ? '…' : 'GET /api/v1/harness/tools',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingSkillList ? null : _loadSkillList,
                    child: Text(
                      _loadingSkillList ? '…' : 'GET /api/v1/skills',
                    ),
                  ),
                ],
              ),
              if (_harnessToolsLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  'tools: $_harnessToolsLine',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_skillsListSummary != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  _skillsListSummary!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _skillPathCtrl,
                decoration: const InputDecoration(
                  labelText: 'Skill relative path',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingSkillPreview ? null : _previewSkillFile,
                child: Text(
                  _loadingSkillPreview ? '加载中…' : 'GET /api/v1/skills/content',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingWs ? null : _testWebSocket,
                child: const Text('WebSocket: attach + LLM stream'),
              ),
              if (_wsLog.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('WS 最近消息:', style: Theme.of(context).textTheme.labelLarge),
                ..._wsLog.map((l) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SelectableText(l, style: Theme.of(context).textTheme.bodySmall),
                    )),
              ],
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              '错误: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
