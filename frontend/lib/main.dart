import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Rust API base URL. Override at build time, e.g.:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8666',
);

void main() {
  runApp(const ToonflowApp());
}

class ToonflowApp extends StatelessWidget {
  const ToonflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toonflow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _healthBody;
  String? _error;
  bool _loading = false;

  Future<void> _pingBackend() async {
    setState(() {
      _loading = true;
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
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'HTTP ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toonflow'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('API: $kApiBaseUrl', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _pingBackend,
              child: Text(_loading ? '请求中…' : 'GET /api/v1/health'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text('错误: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_healthBody != null) Text('响应: $_healthBody'),
          ],
        ),
      ),
    );
  }
}
