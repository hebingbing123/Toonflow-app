import 'package:flutter/foundation.dart';

/// Rust HTTP + WS base (no trailing slash), e.g. `http://127.0.0.1:8666`.
/// Override: `flutter run --dart-define=API_BASE_URL=...`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8666',
);

/// Local: `supabase status` → API URL. Empty = auth UI hidden (except debug fallbacks).
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

/// Project anon (public) key. Empty = auth UI hidden (except debug fallbacks).
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

/// Default local Supabase CLI (`supabase start`) — same as [dart_defines.dev.json].
const String kDevSupabaseUrl = 'http://127.0.0.1:64421';

/// Public anon key for local Supabase demo stack only.
const String kDevSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

/// Seeded via `supabase/seed.sql` / `scripts/seed_local_dev_admin.sh`.
const String kDevAdminEmail = 'admin@openflow.local';
const String kDevAdminPassword = 'admin123';

/// Resolved Supabase URL (dart-define, else local CLI defaults in debug).
String get effectiveSupabaseUrl => kSupabaseUrl.isNotEmpty
    ? kSupabaseUrl
    : (kDebugMode ? kDevSupabaseUrl : '');

/// Resolved anon key (dart-define, else local CLI defaults in debug).
String get effectiveSupabaseAnonKey => kSupabaseAnonKey.isNotEmpty
    ? kSupabaseAnonKey
    : (kDebugMode ? kDevSupabaseAnonKey : '');

bool get kSupabaseConfigured =>
    effectiveSupabaseUrl.isNotEmpty && effectiveSupabaseAnonKey.isNotEmpty;

/// Matches backend **`OPENFLOW_INTERNAL_OPS_TOKEN`** for **`GET /api/v1/jobs/queue/stats`** (Q2 B).
/// Override: `flutter run --dart-define=OPENFLOW_INTERNAL_OPS_TOKEN=...` — empty = hide ops UI.
const String kInternalOpsToken = String.fromEnvironment(
  'OPENFLOW_INTERNAL_OPS_TOKEN',
  defaultValue: '',
);

/// Feature flag for workspace-scope billing (Task 6.3).
/// Override: `flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true`
/// Default: false (user-scope billing)
const bool kEnableWorkspaceBilling = bool.fromEnvironment(
  'ENABLE_WORKSPACE_BILLING',
  defaultValue: false,
);

/// End-user studio shell. Default entry is Studio ([main.dart]); Harness: `-t lib/main_harness.dart`.
/// Legacy: `--dart-define=PRODUCT_SHELL=false` with harness entry if needed.
const bool kProductShell = bool.fromEnvironment(
  'PRODUCT_SHELL',
  defaultValue: true,
);

/// Optional proxy base for Google Fonts runtime fetching.
///
/// Leave empty to fetch directly from Google-hosted font endpoints.
/// When set, requests to `fonts.gstatic.com` / `fonts.googleapis.com`
/// are rewritten onto this base while preserving the original path/query.
///
/// Example:
/// `--dart-define=GOOGLE_FONTS_PROXY_BASE_URL=https://your-font-mirror.example`
const String kGoogleFontsProxyBaseUrl = String.fromEnvironment(
  'GOOGLE_FONTS_PROXY_BASE_URL',
  defaultValue: '',
);

/// Optional directory containing the desktop Rust bridge dynamic library.
const String kOpenflowNativeLibDir = String.fromEnvironment(
  'OPENFLOW_NATIVE_LIB_DIR',
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
