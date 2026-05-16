#!/usr/bin/env bash
# Shared helpers for local DB-backed backend tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_local_env_file() {
  if [[ -f "$ROOT/env/.env.dev" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$ROOT/env/.env.dev"
    set +a
  fi
}

load_database_url_from_supabase_status() {
  if ! command -v supabase >/dev/null 2>&1; then
    return 1
  fi

  local status_output
  if ! status_output="$(cd "$ROOT" && supabase status -o env 2>/dev/null)"; then
    return 1
  fi

  local db_url
  db_url="$(printf '%s\n' "$status_output" | sed -n 's/^DB_URL="\([^"]*\)"$/\1/p' | head -n 1)"
  if [[ -z "$db_url" ]]; then
    return 1
  fi

  export DATABASE_URL="$db_url"
  DATABASE_URL_SOURCE="supabase status -o env"
  return 0
}

ensure_database_url() {
  if [[ -z "${DATABASE_URL:-}" ]]; then
    load_database_url_from_supabase_status || true
  fi

  if [[ -n "${DATABASE_URL:-}" ]] && [[ -z "${DATABASE_URL_SOURCE:-}" ]]; then
    if [[ -f "$ROOT/env/.env.dev" ]]; then
      DATABASE_URL_SOURCE="env/.env.dev or current shell"
    else
      DATABASE_URL_SOURCE="current shell"
    fi
  fi

  [[ -n "${DATABASE_URL:-}" ]]
}

ensure_test_database_url() {
  if [[ -z "${TEST_DATABASE_URL:-}" ]]; then
    ensure_database_url || return 1
    export TEST_DATABASE_URL="$DATABASE_URL"
    TEST_DATABASE_URL_SOURCE="${DATABASE_URL_SOURCE:-DATABASE_URL}"
  fi

  if [[ -z "${TEST_DATABASE_URL_SOURCE:-}" ]]; then
    if [[ -f "$ROOT/env/.env.dev" ]]; then
      TEST_DATABASE_URL_SOURCE="env/.env.dev or current shell"
    else
      TEST_DATABASE_URL_SOURCE="current shell"
    fi
  fi

  [[ -n "${TEST_DATABASE_URL:-}" ]]
}

