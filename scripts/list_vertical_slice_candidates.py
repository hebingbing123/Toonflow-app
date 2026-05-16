#!/usr/bin/env python3
"""List backend/src/*.rs modules that look like single-file vertical-slice candidates.

Heuristic: >= min_lines, not mod.rs/lib.rs/main.rs, no sibling directory with same stem,
exclude generated paths and *contract* test trees.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--root", type=Path, default=Path("backend/src"))
    p.add_argument("--min-lines", type=int, default=180)
    args = p.parse_args()
    root: Path = args.root
    skip = (
        "openapi_spec/generated",
        "pg_contract_tests",
        "contract_smoke_tests",
        "/tests/",
    )
    out: list[tuple[int, Path]] = []
    for f in root.rglob("*.rs"):
        s = str(f)
        if any(x in s for x in skip):
            continue
        if f.name in ("mod.rs", "lib.rs", "main.rs"):
            continue
        if (f.parent / f.stem).is_dir():
            continue
        try:
            n = sum(1 for _ in f.open("rb"))
        except OSError:
            continue
        if n >= args.min_lines:
            out.append((n, f))
    out.sort(reverse=True)
    for n, f in out:
        print(f"{n:4d}  {f}")


if __name__ == "__main__":
    main()
