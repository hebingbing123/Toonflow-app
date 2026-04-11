#!/usr/bin/env python3
"""
Replace Rust identifiers *legacy_id / project_legacy_id / … with numeric_* equivalents
outside strings and // /* comments. Preserves SQL column names like `s.legacy_id` inside r#"..."#.
"""
from __future__ import annotations

import sys
from pathlib import Path


def is_ident_char(c: str) -> bool:
    return c.isalnum() or c == "_"


def replace_identifiers(text: str, old: str, new: str) -> str:
    olen = len(old)
    i = 0
    n = len(text)
    out: list[str] = []

    def at_raw_string(start: int) -> tuple[int, int] | None:
        """If text[start] begins a raw string, return (start, end_exclusive)."""
        if start >= n or text[start] != "r":
            return None
        j = start + 1
        hashes = 0
        while j < n and text[j] == "#":
            hashes += 1
            j += 1
        if j >= n or text[j] != '"':
            return None
        closing = '"' + ("#" * hashes)
        k = text.find(closing, j + 1)
        if k < 0:
            return None
        return (start, k + len(closing))

    while i < n:
        # Line comment
        if text.startswith("//", i):
            eol = text.find("\n", i)
            if eol < 0:
                out.append(text[i:])
                break
            out.append(text[i : eol + 1])
            i = eol + 1
            continue

        # Block comment
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                out.append(text[i:])
                break
            out.append(text[i : j + 2])
            i = j + 2
            continue

        raw = at_raw_string(i)
        if raw is not None:
            _, end = raw
            out.append(text[i:end])
            i = end
            continue

        # Byte raw string br###"…"###
        if text.startswith("br", i) and i + 2 < n and text[i + 2] == "#":
            j = i + 2
            hashes = 0
            while j < n and text[j] == "#":
                hashes += 1
                j += 1
            if j < n and text[j] == '"':
                closing = '"' + ("#" * hashes)
                k = text.find(closing, j + 1)
                if k >= 0:
                    out.append(text[i : k + len(closing)])
                    i = k + len(closing)
                    continue

        if text.startswith('b"', i) or text.startswith('br"', i):
            # Skip b"..." / br"..." (minimal — handles escapes)
            j = i + (2 if text.startswith('br"', i) else 1)
            if text.startswith('br"', i):
                j = i + 2
            else:
                j = i + 1
            j += 1  # past opening "
            while j < n:
                if text[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                j += 1
            out.append(text[i:j])
            i = j
            continue

        # Normal " string
        if text[i] == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                j += 1
            out.append(text[i:j])
            i = j
            continue

        # Identifier replace at i
        if i + olen <= n and text[i : i + olen] == old:
            before = text[i - 1] if i > 0 else "\x00"
            after = text[i + olen] if i + olen < n else "\x00"
            if not is_ident_char(before) and not is_ident_char(after):
                out.append(new)
                i += olen
                continue

        out.append(text[i])
        i += 1

    return "".join(out)


def main() -> int:
    root = Path(__file__).resolve().parents[1] / "backend" / "src"
    pairs: list[tuple[str, str]] = [
        ("cover_legacy_image_id", "cover_numeric_image_id"),
        ("project_legacy_id", "project_numeric_id"),
        ("script_legacy_id", "script_numeric_id"),
        ("storyboard_legacy_id", "storyboard_numeric_id"),
        ("asset_legacy_id", "asset_numeric_id"),
        ("novel_legacy_id", "novel_numeric_id"),
        ("event_legacy_id", "event_numeric_id"),
        ("clip_legacy_id", "clip_numeric_id"),
        ("image_legacy_id", "image_numeric_id"),
        ("ready_asset_legacy_id", "ready_asset_numeric_id"),
        ("running_asset_legacy_id", "running_asset_numeric_id"),
        ("asset_a_legacy_id", "asset_a_numeric_id"),
        ("asset_b_legacy_id", "asset_b_numeric_id"),
        ("asset_c_legacy_id", "asset_c_numeric_id"),
        ("asset_d_legacy_id", "asset_d_numeric_id"),
        ("ensure_owned_project_legacy_id", "ensure_owned_project_numeric_id"),
        ("project_legacy_from_ctx", "project_numeric_from_ctx"),
        ("script_legacy_id_from_args_or_ctx", "script_numeric_id_from_args_or_ctx"),
        ("get_by_legacy_for_project", "get_by_numeric_id_for_project"),
        ("patch_by_legacy_for_project", "patch_by_numeric_id_for_project"),
        ("delete_by_legacy_for_project", "delete_by_numeric_id_for_project"),
        ("normalize_legacy_id_list", "normalize_numeric_id_list"),
        ("slot_by_legacy_id", "slot_by_numeric_id"),
        ("next_legacy_id", "next_numeric_id"),
        ("legacy_image_id", "numeric_image_id"),
        ("legacy_task_id", "numeric_task_id"),
        ("legacy_id", "numeric_id"),
    ]

    changed = 0
    for path in sorted(root.rglob("*.rs")):
        s = path.read_text(encoding="utf-8")
        orig = s
        for old, new in pairs:
            s = replace_identifiers(s, old, new)
        if s != orig:
            path.write_text(s, encoding="utf-8")
            print(path.relative_to(root.parent.parent))
            changed += 1
    print(f"updated {changed} files", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
