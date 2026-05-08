/// Rust HTTP + WS base (no trailing slash), e.g. `http://127.0.0.1:8666`.
/// Override: `flutter run --dart-define=API_BASE_URL=...`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8666',
);

/// Local: `supabase status` → API URL. Empty = auth UI hidden.
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

/// Project anon (public) key. Empty = auth UI hidden.
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

bool get kSupabaseConfigured =>
    kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

/// Matches backend **`TOONFLOW_INTERNAL_OPS_TOKEN`** for **`GET /api/v1/jobs/queue/stats`** (Q2 B).
/// Override: `flutter run --dart-define=INTERNAL_OPS_TOKEN=...` — empty = hide ops UI.
const String kInternalOpsToken = String.fromEnvironment(
  'INTERNAL_OPS_TOKEN',
  defaultValue: '',
);

String resolveRustApiUrl(String pathOrUrl) {
  final raw = pathOrUrl.trim();
  if (raw.isEmpty) {
    return raw;
  }
  final parsed = Uri.tryParse(raw);
  if (parsed != null && parsed.hasScheme) {
    return parsed.toString();
  }
  final base = Uri.parse(kApiBaseUrl);
  return base.resolve(raw).toString();
}

/// `GET /api/v1/ws` with optional `access_token` query (browser-friendly).
Uri rustWebSocketUri(String apiBase, {String? accessToken}) {
  final base = Uri.parse(apiBase);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/api/v1/ws',
    queryParameters: (accessToken != null && accessToken.isNotEmpty)
        ? {'access_token': accessToken}
        : null,
  );
}
