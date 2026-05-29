#!/usr/bin/env bash
# Flutter line-coverage report helper (22.1 KPI baseline — target 80% is roadmap).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/frontend"
BASELINE="$ROOT/docs/metrics/flutter-coverage-baseline.json"
WRITE_BASELINE=0
GATE_MIN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write-baseline) WRITE_BASELINE=1; shift ;;
    --gate-min) GATE_MIN="${2:?}"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

echo "== flutter test --coverage =="
flutter test --coverage --reporter compact

LCOV="coverage/lcov.info"
if [[ ! -f "$LCOV" ]]; then
  echo "Missing $LCOV"
  exit 1
fi

export WRITE_BASELINE BASELINE GATE_MIN
python3 - <<'PY'
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

text = Path("coverage/lcov.info").read_text()
lf = sum(int(m.group(1)) for m in re.finditer(r"^LF:(\d+)", text, re.M))
lh = sum(int(m.group(1)) for m in re.finditer(r"^LH:(\d+)", text, re.M))
pct = (100.0 * lh / lf) if lf else 0.0
print(f"Line coverage: {lh}/{lf} = {pct:.1f}%")
print("KPI target 80% — use --gate-min N for optional fail; --write-baseline to refresh JSON.")

gate = os.environ.get("GATE_MIN", "").strip()
if gate:
    need = float(gate)
    if pct + 1e-9 < need:
        raise SystemExit(f"Coverage {pct:.1f}% < gate {need:.1f}%")

if os.environ.get("WRITE_BASELINE") == "1":
    baseline_path = Path(os.environ["BASELINE"])
    baseline_path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "kpiTargetPercent": 80,
        "linePercent": round(pct, 2),
        "linesHit": lh,
        "linesFound": lf,
        "updatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "note": "Refreshed by scripts/flutter_coverage_report.sh --write-baseline",
    }
    baseline_path.write_text(json.dumps(payload, indent=2) + "\n")
    print(f"Wrote {baseline_path}")
PY
