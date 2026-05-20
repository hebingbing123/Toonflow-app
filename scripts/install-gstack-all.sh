#!/usr/bin/env bash
set -euo pipefail

# One-shot installer for gstack skills on Codex, Cursor, and Kiro.
# Usage:
#   scripts/install-gstack-all.sh
#   scripts/install-gstack-all.sh --hosts codex,cursor
#   scripts/install-gstack-all.sh --gstack-dir /tmp/gstack
#   scripts/install-gstack-all.sh --no-update

REPO_URL="https://github.com/garrytan/gstack"
GSTACK_DIR="${GSTACK_DIR:-$HOME/.gstack/repos/gstack}"
HOSTS="codex,cursor,kiro"
UPDATE_REPO=1

usage() {
  cat <<'EOF'
安装 gstack skills（Codex / Cursor / Kiro）

参数：
  --hosts <list>       逗号分隔：codex,cursor,kiro（默认全部）
  --gstack-dir <path>  本地 gstack 路径（默认：$HOME/.gstack/repos/gstack）
  --no-update          不执行 git pull（仅复用本地仓库）
  -h, --help           显示帮助
EOF
}

log() {
  printf '[gstack-install] %s\n' "$*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts)
      [[ $# -lt 2 ]] && { echo "Missing value for --hosts" >&2; exit 1; }
      HOSTS="$2"
      shift 2
      ;;
    --gstack-dir)
      [[ $# -lt 2 ]] && { echo "Missing value for --gstack-dir" >&2; exit 1; }
      GSTACK_DIR="$2"
      shift 2
      ;;
    --no-update)
      UPDATE_REPO=0
      shift
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

if ! command -v git >/dev/null 2>&1; then
  echo "git not found" >&2
  exit 1
fi

if ! command -v bun >/dev/null 2>&1; then
  echo "bun not found (gstack setup requires bun)" >&2
  exit 1
fi

mkdir -p "$(dirname "$GSTACK_DIR")"

if [[ ! -d "$GSTACK_DIR/.git" ]]; then
  log "cloning gstack to $GSTACK_DIR"
  git clone --single-branch --depth 1 "$REPO_URL" "$GSTACK_DIR"
elif [[ "$UPDATE_REPO" -eq 1 ]]; then
  log "updating gstack in $GSTACK_DIR"
  git -C "$GSTACK_DIR" pull --ff-only
else
  log "skip update, reuse existing $GSTACK_DIR"
fi

IFS=',' read -r -a HOST_ARR <<< "$HOSTS"

install_codex() {
  log "installing codex host"
  (cd "$GSTACK_DIR" && GSTACK_SKIP_COREUTILS=1 ./setup --host codex)
}

install_kiro() {
  log "installing kiro host"
  (cd "$GSTACK_DIR" && GSTACK_SKIP_COREUTILS=1 ./setup --host kiro)
}

install_cursor() {
  log "installing cursor host (manual path)"
  (
    cd "$GSTACK_DIR"
    bun run gen:skill-docs --host cursor

    mkdir -p "$HOME/.cursor/skills/gstack" \
      "$HOME/.cursor/skills/gstack/browse" \
      "$HOME/.cursor/skills/gstack/gstack-upgrade" \
      "$HOME/.cursor/skills/gstack/review"

    ln -snf "$GSTACK_DIR/bin" "$HOME/.cursor/skills/gstack/bin"
    ln -snf "$GSTACK_DIR/browse/dist" "$HOME/.cursor/skills/gstack/browse/dist"
    ln -snf "$GSTACK_DIR/browse/bin" "$HOME/.cursor/skills/gstack/browse/bin"
    ln -snf "$GSTACK_DIR/.cursor/skills/gstack-upgrade/SKILL.md" "$HOME/.cursor/skills/gstack/gstack-upgrade/SKILL.md"
    ln -snf "$GSTACK_DIR/ETHOS.md" "$HOME/.cursor/skills/gstack/ETHOS.md"
    ln -snf "$GSTACK_DIR/review/checklist.md" "$HOME/.cursor/skills/gstack/review/checklist.md"
    ln -snf "$GSTACK_DIR/review/TODOS-format.md" "$HOME/.cursor/skills/gstack/review/TODOS-format.md"
    ln -snf "$GSTACK_DIR/.cursor/skills/gstack/SKILL.md" "$HOME/.cursor/skills/gstack/SKILL.md"

    for d in "$GSTACK_DIR"/.cursor/skills/gstack-*; do
      n="$(basename "$d")"
      [[ "$n" == "gstack" ]] && continue
      ln -snf "$d" "$HOME/.cursor/skills/$n"
    done
  )
}

for host in "${HOST_ARR[@]}"; do
  case "$host" in
    codex) install_codex ;;
    cursor) install_cursor ;;
    kiro) install_kiro ;;
    "")
      ;;
    *)
      echo "Unsupported host: $host (allowed: codex,cursor,kiro)" >&2
      exit 1
      ;;
  esac
done

log "verifying install counts"
codex_count="$(ls -1 "$HOME/.codex/skills" 2>/dev/null | rg '^gstack' | wc -l | tr -d ' ')"
cursor_count="$(ls -1 "$HOME/.cursor/skills" 2>/dev/null | rg '^gstack' | wc -l | tr -d ' ')"
kiro_count="$(ls -1 "$HOME/.kiro/skills" 2>/dev/null | rg '^gstack' | wc -l | tr -d ' ')"

log "done: codex=$codex_count cursor=$cursor_count kiro=$kiro_count"
