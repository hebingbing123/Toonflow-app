#!/usr/bin/env bash
# Project health check — read-only artifact collection for project-health-check skill.
#
# Usage (repo root):
#   bash scripts/run-project-health-check.sh
#
# Writes:
#   .codex/skills/project-health-check/output/run-manifest.json
#   .codex/skills/project-health-check/output/raw/*
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/.codex/skills/project-health-check/output"
RAW="$OUT/raw"
mkdir -p "$RAW"

log() { printf '[project-health-check] %s\n' "$*"; }

COMMIT="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
STARTED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TOOLS_MISSING=()
STEPS=()

record_step() {
  local name="$1"
  local status="$2"
  local artifact="${3:-}"
  STEPS+=("{\"name\":\"$name\",\"status\":\"$status\",\"artifact\":\"$artifact\"}")
}

# --- 1. Rust: cargo audit ---
if command -v cargo-audit >/dev/null 2>&1; then
  log "cargo audit..."
  set +e
  (cd "$ROOT/backend" && cargo audit --json 2>/dev/null) >"$RAW/cargo-audit.json"
  AUDIT_RC=$?
  set -e
  if [[ $AUDIT_RC -eq 0 ]]; then
    record_step "cargo_audit" "ok" "raw/cargo-audit.json"
  else
    record_step "cargo_audit" "findings" "raw/cargo-audit.json"
  fi
else
  log "WARN: cargo-audit not installed (cargo install cargo-audit)"
  echo '{"error":"cargo-audit not installed","hint":"cargo install cargo-audit"}' >"$RAW/cargo-audit.json"
  TOOLS_MISSING+=("cargo-audit")
  record_step "cargo_audit" "skipped" "raw/cargo-audit.json"
fi

# --- 1b. Flutter deps ---
log "flutter pub outdated..."
set +e
(cd "$ROOT/frontend" && flutter pub outdated --json 2>/dev/null) >"$RAW/flutter-outdated.json"
OUTDATED_RC=$?
set -e
if [[ $OUTDATED_RC -eq 0 ]]; then
  record_step "flutter_pub_outdated" "ok" "raw/flutter-outdated.json"
else
  echo '{"error":"flutter pub outdated failed"}' >"$RAW/flutter-outdated.json"
  record_step "flutter_pub_outdated" "failed" "raw/flutter-outdated.json"
fi

log "flutter pub deps..."
(cd "$ROOT/frontend" && flutter pub deps --style=compact 2>&1) | tee "$RAW/flutter-deps.txt" >/dev/null
record_step "flutter_pub_deps" "ok" "raw/flutter-deps.txt"

# --- 2. OpenAPI contract ---
OPENAPI_SPEC="/tmp/openflow_health_openapi_$$.yaml"
log "export-openapi..."
set +e
(cd "$ROOT/backend" && cargo run --quiet --bin export-openapi) >"$OPENAPI_SPEC" 2>"$RAW/export-openapi.stderr"
EXPORT_RC=$?
set -e
if [[ $EXPORT_RC -eq 0 ]]; then
  cp "$OPENAPI_SPEC" "$RAW/openapi-export.yaml"
  record_step "export_openapi" "ok" "raw/openapi-export.yaml"
  export OPENFLOW_OPENAPI_SPEC="$OPENAPI_SPEC"
  log "check_openapi_drift..."
  set +e
  bash "$ROOT/scripts/check_openapi_drift.sh" 2>&1 | tee "$RAW/openapi-drift.txt"
  DRIFT_RC=${PIPESTATUS[0]}
  set -e
  record_step "openapi_drift" "$([[ $DRIFT_RC -eq 0 ]] && echo ok || echo drift)" "raw/openapi-drift.txt"
  log "check_rust_api_consistency..."
  set +e
  bash "$ROOT/scripts/check_rust_api_consistency.sh" 2>&1 | tee "$RAW/rust-api-consistency.txt"
  CONSIST_RC=${PIPESTATUS[0]}
  set -e
  record_step "rust_api_consistency" "$([[ $CONSIST_RC -eq 0 ]] && echo ok || echo mismatch)" "raw/rust-api-consistency.txt"
else
  record_step "export_openapi" "failed" "raw/export-openapi.stderr"
  record_step "openapi_drift" "blocked" ""
  record_step "rust_api_consistency" "blocked" ""
fi
rm -f "$OPENAPI_SPEC"

# --- 3. Config / secrets scan (no .env contents) ---
log "secrets scan (tracked files)..."
{
  echo "# git grep secret patterns — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  git -C "$ROOT" grep -nE '(sk-[a-zA-Z0-9]{20,}|SUPABASE_SERVICE_ROLE|service_role\.eyJ)' \
    -- ':!*.md' ':!package-lock.json' ':!yarn.lock' ':!pubspec.lock' 2>/dev/null || echo "(no matches)"
} >"$RAW/secrets-scan.txt"
record_step "secrets_scan" "ok" "raw/secrets-scan.txt"

{
  echo "backend/.env.example: $([[ -f $ROOT/backend/.env.example ]] && echo present || echo missing)"
  echo "backend/.env: $([[ -f $ROOT/backend/.env ]] && echo present || echo missing)"
  echo "frontend/dart_defines.dev.json: $([[ -f $ROOT/frontend/dart_defines.dev.json ]] && echo present || echo missing)"
} >"$RAW/config-inventory.txt"
record_step "config_inventory" "ok" "raw/config-inventory.txt"

# --- 4. Supabase static audits ---
log "supabase migrations / RLS audit..."
{
  echo "# CREATE EXTENSION"
  grep -hE 'CREATE EXTENSION' "$ROOT"/supabase/migrations/*.sql 2>/dev/null | sort -u || true
} >"$RAW/supabase-extensions.txt"
record_step "supabase_extensions" "ok" "raw/supabase-extensions.txt"

ruby - "$ROOT" >"$RAW/supabase-rls-audit.json" <<'RUBY'
require 'json'
require 'time'
root = ARGV[0]
mig_dir = File.join(root, 'supabase', 'migrations')
sql = Dir.glob(File.join(mig_dir, '*.sql')).sort.map { |f| File.read(f) }.join("\n")

tables = sql.scan(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:public\.)?("?)([a-zA-Z0-9_]+)\1/i).map { |_q, name| name }.uniq
tables.select! { |t| t.start_with?('app_') || t == 'legacy_staging' || t == 'import_staging' }

rls_enabled = sql.scan(/ALTER\s+TABLE\s+(?:ONLY\s+)?(?:public\.)?("?)([a-zA-Z0-9_]+)\1\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY/i).map { |_q, name| name }.uniq
policies = sql.scan(/CREATE\s+POLICY\s+"?([^"\s]+)"?\s+ON\s+(?:public\.)?("?)([a-zA-Z0-9_]+)\2/i)

tables_with_policy = policies.map { |_pname, _q, table| table }.uniq
service_role_broad = sql.scan(/TO\s+service_role\s+USING\s*\(\s*true\s*\)/i).length

without_rls = tables - rls_enabled
without_policies = tables - tables_with_policy

puts JSON.pretty_generate({
  'auditedAt' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
  'tablesAppLike' => tables.sort,
  'tablesWithoutRls' => without_rls.sort,
  'tablesWithoutPolicies' => without_policies.sort,
  'rlsEnabledCount' => rls_enabled.length,
  'policyCount' => policies.length,
  'serviceRoleBroadUsingTrue' => service_role_broad,
  'edgeFunctionsDir' => (Dir.exist?(File.join(root, 'supabase', 'functions')) ? Dir.children(File.join(root, 'supabase', 'functions')).reject { |e| e.start_with?('.') } : [])
})
RUBY
record_step "supabase_rls_audit" "ok" "raw/supabase-rls-audit.json"

if command -v supabase >/dev/null 2>&1; then
  supabase -C "$ROOT" status 2>/dev/null | tee "$RAW/supabase-status.txt" >/dev/null || echo "supabase not running" >"$RAW/supabase-status.txt"
  record_step "supabase_status" "ok" "raw/supabase-status.txt"
else
  echo "supabase CLI not installed" >"$RAW/supabase-status.txt"
  TOOLS_MISSING+=("supabase-cli")
  record_step "supabase_status" "skipped" "raw/supabase-status.txt"
fi

# --- 5. Observability inventory ---
{
  echo "rust telemetry: backend/src/telemetry.rs"
  test -f "$ROOT/backend/src/telemetry.rs" && echo "  present" || echo "  missing"
  echo "flutter main entrypoints:"
  ls "$ROOT"/frontend/lib/main*.dart 2>/dev/null || true
} >"$RAW/observability-inventory.txt"
record_step "observability_inventory" "ok" "raw/observability-inventory.txt"

# --- Manifest ---
FINISHED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf '%s\n' "${STEPS[@]}" >"$RAW/steps.ndjson"
printf '%s\n' "${TOOLS_MISSING[@]:-}" >"$RAW/tools-missing.txt"
ruby - "$OUT/run-manifest.json" "$STARTED_AT" "$FINISHED_AT" "$COMMIT" "$RAW" <<'RUBY'
require 'json'
out, started, finished, commit, raw = ARGV
steps = File.readlines(File.join(raw, 'steps.ndjson'), chomp: true).reject(&:empty?).map { |line| JSON.parse(line) }
tools = File.readlines(File.join(raw, 'tools-missing.txt'), chomp: true).reject(&:empty?)
doc = {
  'schemaVersion' => '1.0.0',
  'startedAt' => started,
  'finishedAt' => finished,
  'commit' => commit,
  'repository' => 'Toonflow-app',
  'outputDir' => '.codex/skills/project-health-check/output',
  'toolsMissing' => tools,
  'steps' => steps,
  'next' => 'Agent reads raw/* and writes output/issues.json per project-health-check skill'
}
File.write(out, JSON.pretty_generate(doc))
RUBY

log "Done → $OUT/run-manifest.json"
log "Next: agent writes $OUT/issues.json (report-only)"
