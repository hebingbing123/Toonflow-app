import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

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
    setState(() => _wsLog.clear());
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
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _loadingWs ? null : _testWebSocket,
                child: const Text('WebSocket: attach + chat.stub'),
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
