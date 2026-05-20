#!/usr/bin/env bash
set -euo pipefail

# One-shot uninstaller for gstack skills on Codex, Cursor, and Kiro.
# Usage:
#   scripts/uninstall-gstack-all.sh
#   scripts/uninstall-gstack-all.sh --hosts codex,cursor
#   scripts/uninstall-gstack-all.sh --dry-run
#   scripts/uninstall-gstack-all.sh --remove-repo

GSTACK_DIR="${GSTACK_DIR:-$HOME/.gstack/repos/gstack}"
HOSTS="codex,cursor,kiro"
DRY_RUN=0
REMOVE_REPO=0

usage() {
  cat <<'EOF'
卸载 gstack skills（Codex / Cursor / Kiro）

参数：
  --hosts <list>       逗号分隔：codex,cursor,kiro（默认全部）
  --dry-run            仅打印将要删除的路径，不真正删除
  --remove-repo        同时删除本地 gstack 仓库（默认不删）
  --gstack-dir <path>  gstack 本地路径（默认：$HOME/.gstack/repos/gstack）
  -h, --help           显示帮助
EOF
}

log() {
  printf '[gstack-uninstall] %s\n' "$*"
}

run_rm() {
  local path="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would remove: $path"
  else
    rm -rf "$path"
    log "removed: $path"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts)
      [[ $# -lt 2 ]] && { echo "Missing value for --hosts" >&2; exit 1; }
      HOSTS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --remove-repo)
      REMOVE_REPO=1
      shift
      ;;
    --gstack-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --gstack-dir" >&2; exit 1; }
      GSTACK_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

remove_host() {
  local root="$1"
  local host="$2"
  [[ ! -d "$root" ]] && { log "$host root not found: $root (skip)"; return 0; }

  while IFS= read -r entry; do
    run_rm "$root/$entry"
  done < <(ls -1 "$root" 2>/dev/null | rg '^gstack')
}

IFS=',' read -r -a HOST_ARR <<< "$HOSTS"
for host in "${HOST_ARR[@]}"; do
  case "$host" in
    codex)
      remove_host "$HOME/.codex/skills" "codex"
      ;;
    cursor)
      remove_host "$HOME/.cursor/skills" "cursor"
      ;;
    kiro)
      remove_host "$HOME/.kiro/skills" "kiro"
      ;;
    "")
      ;;
    *)
      echo "Unsupported host: $host (allowed: codex,cursor,kiro)" >&2
      exit 1
      ;;
  esac
done

if [[ "$REMOVE_REPO" -eq 1 ]]; then
  run_rm "$GSTACK_DIR"
fi

log "done"
