#!/usr/bin/env python3
"""
批量 i18n：扫描 Text / SelectableText 中带 `${}` 的字符串（单行或三引号多行）→ 生成 ARB 草案与
**对照表**（Markdown + CSV）→（审阅后）merge-arb → replace-dart。

推荐流程::

  python3 scripts/l10n_batch_pipeline.py prepare --root frontend/lib [--subtree shell]
  # 审阅 frontend/.l10n_batch/prepare_mapping_table.md（主对照表）
  #      frontend/.l10n_batch/prepare_report.md
  #      frontend/.l10n_batch/prepare_manifest.json

  python3 scripts/l10n_batch_pipeline.py merge-arb
  cd frontend && flutter gen-l10n

  python3 scripts/l10n_batch_pipeline.py replace-dart

一键::

  python3 scripts/l10n_batch_pipeline.py apply-all --confirm [--no-translate]

可选机翻：pip install -r scripts/requirements_l10n_batch.txt 后 prepare 勿加 --no-translate。
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import sys
from collections import OrderedDict, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

_STR_RE = re.compile(
    r"(?P<widget>Text|SelectableText)\s*\(\s*(?P<q>['\"])(?P<body>.*?)(?P=q)"
)
_WIDGET_OPEN = re.compile(r"\b(Text|SelectableText)\s*\(")

MANIFEST_NAME = "prepare_manifest.json"
REPORT_NAME = "prepare_report.md"
TABLE_MD_NAME = "prepare_mapping_table.md"
TABLE_CSV_NAME = "prepare_mapping_table.csv"


def _manifest_path(repo: Path, p: Path | None) -> Path:
    if p is None:
        return repo / "frontend" / ".l10n_batch" / MANIFEST_NAME
    return p if p.is_absolute() else repo / p


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _line_at(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def _skip_ws(s: str, i: int) -> int:
    while i < len(s) and s[i] in " \t\n\r":
        i += 1
    return i


def _parse_triple_quoted(s: str, i: int) -> tuple[str | None, int]:
    """i 指向开引号第一个字符。成功返回 (body, 闭合后下标)；失败 (None, i)。"""
    if i + 3 > len(s):
        return None, i
    delim = s[i : i + 3]
    if delim not in ("'''", '"""'):
        return None, i
    i += 3
    start = i
    while i < len(s):
        if s.startswith(delim, i):
            return s[start:i], i + 3
        if s[i] == "\\" and i + 1 < len(s):
            i += 2
            continue
        i += 1
    return None, start - 3


def _translate_zh(text: str) -> str:
    try:
        from deep_translator import GoogleTranslator  # type: ignore

        out = GoogleTranslator(source="en", target="zh-CN").translate(text)
        return out if out else text
    except Exception:
        return text


def _infer_placeholder_type(expr: str) -> str:
    e = expr.strip()
    if re.search(
        r"(^|\.)(numericId|numericTaskId|day|sortIndex|activeFilterCount|length)$",
        e,
    ):
        return "int"
    return "String"


def _parse_interpolation_body(body: str) -> tuple[list[str], list[str]] | None:
    if "${" not in body:
        return None
    literals: list[str] = []
    exprs: list[str] = []
    pos = 0
    for m in re.finditer(r"\$\{([^}]+)\}", body):
        literals.append(body[pos : m.start()])
        exprs.append(m.group(1).strip())
        pos = m.end()
    literals.append(body[pos:])
    if not exprs:
        return None
    return literals, exprs


def _normalize_template(literals: list[str], n_expr: int) -> str:
    return repr(literals) + "|" + str(n_expr)


def _stable_key(norm: str) -> str:
    h = hashlib.sha256(norm.encode("utf-8")).hexdigest()[:10]
    return f"l10nBatch_{h}"


def _arb_message_and_meta(
    literals: list[str], exprs: list[str], types: list[str]
) -> tuple[str, dict]:
    if len(literals) != len(exprs) + 1:
        raise ValueError("literals/exprs mismatch")
    msg_parts: list[str] = []
    ph: dict[str, dict] = {}
    for i, lit in enumerate(literals):
        msg_parts.append(lit.replace("{", "'{'").replace("}", "'}'"))
        if i < len(exprs):
            name = f"p{i}"
            msg_parts.append("{" + name + "}")
            ph[name] = {"type": types[i]}
    message = "".join(msg_parts)
    meta = {"placeholders": ph}
    return message, meta


def _should_skip_body(body: str) -> bool:
    if len(body) < 2:
        return True
    if re.fullmatch(r"[\d.]+", body.strip()):
        return True
    if re.search(r"\$(?!\{)", body):
        return True
    return False


def _replacement_snippet(widget: str, key: str, exprs: list[str]) -> str:
    args = ", ".join(exprs)
    inner = f"l10n.{key}({args})" if args else f"l10n.{key}()"
    return f"{widget}({inner}"


@dataclass
class Occurrence:
    path: Path
    kind: str  # single_line | triple_quote
    span_start: int
    span_end: int
    line_start: int
    line_end: int
    widget: str
    body: str
    literals: list[str]
    exprs: list[str]
    norm: str
    l10n_key: str
    ph_types: list[str]
    old_span: str


def _dedupe_occurrences(occ: list[Occurrence]) -> list[Occurrence]:
    by_path: dict[Path, list[Occurrence]] = defaultdict(list)
    for o in occ:
        by_path[o.path].append(o)
    out: list[Occurrence] = []

    def overlaps(a: Occurrence, b: Occurrence) -> bool:
        return not (a.span_end <= b.span_start or a.span_start >= b.span_end)

    for path in sorted(by_path):
        lst = by_path[path]
        triples = [o for o in lst if o.kind == "triple_quote"]
        singles = [o for o in lst if o.kind == "single_line"]
        cur: list[Occurrence] = []
        for o in sorted(triples, key=lambda x: x.span_start) + sorted(
            singles, key=lambda x: x.span_start
        ):
            if any(overlaps(o, p) for p in cur):
                continue
            cur.append(o)
        out.extend(cur)
    return out


def scan_file(path: Path, text: str) -> list[Occurrence]:
    out: list[Occurrence] = []

    # 1) 单行 Text('...${}...')
    off = 0
    for line in text.splitlines(keepends=True):
        if "Text(" not in line and "SelectableText(" not in line:
            off += len(line)
            continue
        for m in _STR_RE.finditer(line):
            body = m.group("body")
            if _should_skip_body(body):
                continue
            parsed = _parse_interpolation_body(body)
            if parsed is None:
                continue
            literals, exprs = parsed
            if m.group("q") in literals or any(m.group("q") in lit for lit in literals):
                continue
            norm = _normalize_template(literals, len(exprs))
            key = _stable_key(norm)
            types = [_infer_placeholder_type(e) for e in exprs]
            ws = m.group("widget")
            s0 = off + m.start()
            s1 = off + m.end()
            out.append(
                Occurrence(
                    path=path,
                    kind="single_line",
                    span_start=s0,
                    span_end=s1,
                    line_start=_line_at(text, s0),
                    line_end=_line_at(text, s0),
                    widget=ws,
                    body=body,
                    literals=literals,
                    exprs=exprs,
                    norm=norm,
                    l10n_key=key,
                    ph_types=types,
                    old_span=text[s0:s1],
                )
            )
        off += len(line)

    # 2) 三引号多行 Text(\n  ''' ... ${} ... ''')
    for m in _WIDGET_OPEN.finditer(text):
        ws = m.group(1)
        j = _skip_ws(text, m.end())
        body, end = _parse_triple_quoted(text, j)
        if body is None:
            continue
        if _should_skip_body(body):
            continue
        parsed = _parse_interpolation_body(body)
        if parsed is None:
            continue
        literals, exprs = parsed
        norm = _normalize_template(literals, len(exprs))
        key = _stable_key(norm)
        types = [_infer_placeholder_type(e) for e in exprs]
        s0 = m.start()
        s1 = end
        out.append(
            Occurrence(
                path=path,
                kind="triple_quote",
                span_start=s0,
                span_end=s1,
                line_start=_line_at(text, s0),
                line_end=_line_at(text, s1 - 1),
                widget=ws,
                body=body,
                literals=literals,
                exprs=exprs,
                norm=norm,
                l10n_key=key,
                ph_types=types,
                old_span=text[s0:s1],
            )
        )

    return out


def scan_lib(lib_root: Path, subtree: str | None = None) -> list[Occurrence]:
    skip = {"l10n", "generated", ".dart_tool"}
    out: list[Occurrence] = []
    lib_root = lib_root.resolve()
    sub = (
        subtree.strip().replace("\\", "/").rstrip("/")
        if (subtree and subtree.strip())
        else None
    )
    for path in sorted(lib_root.rglob("*.dart")):
        if any(p in path.parts for p in skip):
            continue
        if sub is not None:
            rel = path.relative_to(lib_root).as_posix()
            if rel != sub and not rel.startswith(sub + "/"):
                continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        out.extend(_dedupe_occurrences(scan_file(path, text)))
    return out


def _load_arb(path: Path) -> OrderedDict:
    raw = path.read_text(encoding="utf-8")
    lines = [ln for ln in raw.splitlines() if not ln.strip().startswith("//")]
    return json.loads("\n".join(lines), object_pairs_hook=OrderedDict)


def _save_arb(path: Path, data: OrderedDict) -> None:
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _merge_arb(
    arb_path: Path,
    additions: OrderedDict[str, str],
    meta: OrderedDict[str, dict],
) -> int:
    data = _load_arb(arb_path)
    n = 0
    for k, v in additions.items():
        if k in data:
            continue
        data[k] = v
        mk = f"@{k}"
        if mk in meta and meta[mk]:
            data[mk] = dict(meta[mk])
        n += 1
    _save_arb(arb_path, data)
    return n


def _build_plan(
    occ: list[Occurrence],
    repo: Path,
    *,
    no_translate: bool,
    translate_tokens: bool,
) -> tuple[
    OrderedDict[str, str],
    OrderedDict[str, str],
    OrderedDict[str, dict],
    list[dict],
    list[tuple[Occurrence, str]],
]:
    """返回 (en, zh, meta, char_edits, occ_with_new_span)。"""
    by_norm: dict[str, tuple[list[str], list[str], str, list[str]]] = {}
    for o in occ:
        if o.norm not in by_norm:
            by_norm[o.norm] = (o.literals, o.exprs, o.l10n_key, o.ph_types)

    additions_en: OrderedDict[str, str] = OrderedDict()
    additions_zh: OrderedDict[str, str] = OrderedDict()
    meta: OrderedDict[str, dict] = OrderedDict()

    for _norm, (literals, exprs, key, types) in by_norm.items():
        msg_en, mmeta = _arb_message_and_meta(literals, exprs, types)
        additions_en[key] = msg_en
        meta[f"@{key}"] = mmeta
        sample = "".join(literals)
        if no_translate:
            zh_msg = msg_en
        elif re.search(r"[A-Za-z]{4,}", sample) or translate_tokens:
            zh_msg = _translate_zh(msg_en)
        else:
            zh_msg = msg_en
        additions_zh[key] = zh_msg

    occ_new: list[tuple[Occurrence, str]] = []
    char_edits: list[dict] = []
    for o in occ:
        new_span = _replacement_snippet(o.widget, o.l10n_key, o.exprs)
        occ_new.append((o, new_span))
        char_edits.append(
            {
                "file": o.path.relative_to(repo).as_posix(),
                "start": o.span_start,
                "end": o.span_end,
                "old": o.old_span,
                "new": new_span,
                "line_start": o.line_start,
                "line_end": o.line_end,
                "kind": o.kind,
                "key": o.l10n_key,
            }
        )

    return additions_en, additions_zh, meta, char_edits, occ_new


def _write_mapping_table_md(
    path: Path,
    rows: list[tuple[Occurrence, str, str, str]],
    repo: Path,
) -> None:
    """rows: (occ, en_msg, zh_msg, new_dart_snippet)"""
    lines = [
        "# l10n 对照表（prepare 输出，供人工确认）",
        "",
        "| 序号 | ARB 键 | 类型 | 位置 | EN 模板 | ZH 模板 | 源码片段（旧） | 建议替换（新） |",
        "| ---: | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for i, (o, en_m, zh_m, new_s) in enumerate(rows, 1):
        rel = o.path.relative_to(repo).as_posix()
        loc = f"`{rel}` L{o.line_start}" + (
            f"–L{o.line_end}" if o.line_end != o.line_start else ""
        )
        old_short = o.old_span.replace("\n", "↵ ").replace("|", "\\|")
        if len(old_short) > 120:
            old_short = old_short[:117] + "..."
        new_short = new_s.replace("|", "\\|")
        if len(new_short) > 100:
            new_short = new_short[:97] + "..."
        en_cell = en_m.replace("|", "\\|").replace("\n", "↵ ")
        zh_cell = zh_m.replace("|", "\\|").replace("\n", "↵ ")
        lines.append(
            f"| {i} | `{o.l10n_key}` | {o.kind} | {loc} | {en_cell} | {zh_cell} | `{old_short}` | `{new_short}` |"
        )
    if not rows:
        lines.append(
            "| — | — | — | *无命中：当前规则下无单行/三引号且含 `${}` 的 Text/SelectableText；"
            "可换 `--subtree` 或扩展脚本规则。* | — | — | — | — |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_mapping_table_csv(
    path: Path,
    rows: list[tuple[Occurrence, str, str, str]],
    repo: Path,
) -> None:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(
        [
            "index",
            "arb_key",
            "kind",
            "file",
            "line_start",
            "line_end",
            "en_template",
            "zh_template",
            "old_dart",
            "new_dart",
        ]
    )
    for i, (o, en_m, zh_m, new_s) in enumerate(rows, 1):
        w.writerow(
            [
                i,
                o.l10n_key,
                o.kind,
                o.path.relative_to(repo).as_posix(),
                o.line_start,
                o.line_end,
                en_m,
                zh_m,
                o.old_span,
                new_s,
            ]
        )
    path.write_text(buf.getvalue(), encoding="utf-8")


def _write_report(
    path: Path,
    occ: list[Occurrence],
    additions_en: OrderedDict[str, str],
    char_edits: list[dict],
) -> None:
    lines = [
        "# l10n batch prepare 报告",
        "",
        f"- 扫描命中: **{len(occ)}** 处",
        f"- 去重后 ARB 模板: **{len(additions_en)}** 条",
        f"- 字符级替换块: **{len(char_edits)}** 处",
        "",
        "主对照表请打开 **`prepare_mapping_table.md`**（及同名 `.csv`）。",
        "",
        "## 新增 EN 键（摘要）",
        "",
    ]
    for k, v in list(additions_en.items())[:50]:
        lines.append(f"- `{k}` → `{v!r}`")
    if len(additions_en) > 50:
        lines.append(f"- … 共 {len(additions_en)} 条，见 manifest / 对照表")
    lines += ["", "## 替换块预览（前 15 条）", ""]
    for ed in char_edits[:15]:
        lines.append(f"### `{ed['file']}` L{ed['line_start']} `{ed['key']}`")
        lines.append("")
        lines.append("```dart")
        lines.append(ed["old"][:800] + ("…" if len(ed["old"]) > 800 else ""))
        lines.append("```")
        lines.append("→")
        lines.append("```dart")
        lines.append(ed["new"])
        lines.append("```")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def cmd_scan(args: argparse.Namespace) -> int:
    root = _repo_root() / args.root
    occ = scan_lib(root, args.subtree)
    out_path = _repo_root() / "frontend" / ".l10n_batch" / "scan.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    repo = _repo_root()
    payload = [
        {
            "file": str(o.path.relative_to(repo)),
            "line": o.line_start,
            "kind": o.kind,
            "key": o.l10n_key,
            "body": o.body,
            "exprs": o.exprs,
        }
        for o in occ
    ]
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(payload)} occurrences -> {out_path}")
    return 0


def cmd_prepare(args: argparse.Namespace) -> int:
    repo = _repo_root()
    root = repo / args.root
    occ = scan_lib(root, args.subtree)
    additions_en, additions_zh, meta, char_edits, occ_new = _build_plan(
        occ,
        repo,
        no_translate=args.no_translate,
        translate_tokens=args.translate_tokens,
    )

    out_dir = repo / "frontend" / ".l10n_batch"
    out_dir.mkdir(parents=True, exist_ok=True)

    table_rows: list[tuple[Occurrence, str, str, str]] = []
    for o, new_s in occ_new:
        table_rows.append((o, additions_en[o.l10n_key], additions_zh[o.l10n_key], new_s))

    manifest_path = out_dir / MANIFEST_NAME
    manifest = {
        "version": 2,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "root": str(args.root).replace("\\", "/"),
        "subtree": args.subtree,
        "no_translate": args.no_translate,
        "translate_tokens": args.translate_tokens,
        "arb_additions_en": dict(additions_en),
        "arb_additions_zh": dict(additions_zh),
        "arb_meta": dict(meta),
        "char_edits": char_edits,
        "occurrences": [
            {
                "file": str(o.path.relative_to(repo)).replace("\\", "/"),
                "line_start": o.line_start,
                "line_end": o.line_end,
                "kind": o.kind,
                "key": o.l10n_key,
                "body": o.body,
                "exprs": o.exprs,
            }
            for o in occ
        ],
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    _write_report(out_dir / REPORT_NAME, occ, additions_en, char_edits)
    _write_mapping_table_md(out_dir / TABLE_MD_NAME, table_rows, repo)
    _write_mapping_table_csv(out_dir / TABLE_CSV_NAME, table_rows, repo)

    print(
        f"prepare: {len(occ)} hits, {len(additions_en)} ARB templates, "
        f"{len(char_edits)} char edits"
    )
    print(f"  manifest -> {manifest_path.relative_to(repo)}")
    print(f"  对照表 MD -> {(out_dir / TABLE_MD_NAME).relative_to(repo)}")
    print(f"  对照表 CSV -> {(out_dir / TABLE_CSV_NAME).relative_to(repo)}")
    print(f"  report    -> {(out_dir / REPORT_NAME).relative_to(repo)}")
    print("审阅后: merge-arb → flutter gen-l10n → replace-dart")
    return 0


def _load_manifest(path: Path) -> dict:
    if not path.is_file():
        print(f"找不到 manifest: {path}", file=sys.stderr)
        raise SystemExit(2)
    return json.loads(path.read_text(encoding="utf-8"))


def cmd_merge_arb(args: argparse.Namespace) -> int:
    repo = _repo_root()
    mp = _manifest_path(repo, args.manifest)
    data = _load_manifest(mp)
    additions_en = OrderedDict(data.get("arb_additions_en", {}))
    additions_zh = OrderedDict(data.get("arb_additions_zh", {}))
    meta = OrderedDict(data.get("arb_meta", {}))

    en_path = repo / "frontend/lib/l10n/app_en.arb"
    zh_path = repo / "frontend/lib/l10n/app_zh.arb"
    n1 = _merge_arb(en_path, additions_en, meta)
    n2 = _merge_arb(zh_path, additions_zh, meta)
    print(f"merge-arb: app_en 新增 {n1} 键, app_zh 新增 {n2} 键（已存在则跳过）")
    print("下一步: cd frontend && flutter gen-l10n")
    return 0


def cmd_replace_dart(args: argparse.Namespace) -> int:
    repo = _repo_root()
    mp = _manifest_path(repo, args.manifest)
    data = _load_manifest(mp)
    char_edits = data.get("char_edits") or []

    # v1 兼容：仅 line_edits
    if not char_edits and data.get("line_edits"):
        edits = data["line_edits"]
        touched = 0
        for ed in edits:
            rel = ed["file"]
            line_no = int(ed["line"])
            old_line = ed["old_line"]
            new_line = ed["new_line"]
            path = repo / rel
            if not path.is_file():
                print(f"SKIP 无文件: {rel}", file=sys.stderr)
                continue
            lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
            idx = line_no - 1
            if idx < 0 or idx >= len(lines):
                print(f"SKIP 行号越界 {rel}:{line_no}", file=sys.stderr)
                continue
            cur = lines[idx]
            if cur.rstrip("\n\r") != old_line.rstrip("\n\r"):
                print(f"SKIP 行已变化 {rel}:{line_no}", file=sys.stderr)
                continue
            nl = "\r\n" if cur.endswith("\r\n") else ("\n" if cur.endswith("\n") else "")
            lines[idx] = new_line + nl
            path.write_text("".join(lines), encoding="utf-8")
            touched += 1
        print(f"replace-dart (v1 line): 已更新 {touched} 行")
        return 0

    if not char_edits:
        print("manifest 中无 char_edits，跳过")
        return 0

    by_file: dict[str, list[dict]] = defaultdict(list)
    for ed in char_edits:
        by_file[ed["file"]].append(ed)

    touched_files = 0
    for rel, eds in sorted(by_file.items()):
        path = repo / rel
        if not path.is_file():
            print(f"SKIP 无文件: {rel}", file=sys.stderr)
            continue
        text = path.read_text(encoding="utf-8")
        for ed in sorted(eds, key=lambda e: e["start"], reverse=True):
            start, end = int(ed["start"]), int(ed["end"])
            old = ed["old"]
            new = ed["new"]
            if text[start:end] != old:
                print(
                    f"SKIP 内容不匹配（请重新 prepare）{rel} @{start}\n"
                    f"  期望前 80 字: {old[:80]!r}\n"
                    f"  实际前 80 字: {text[start:start+80]!r}",
                    file=sys.stderr,
                )
                continue
            text = text[:start] + new + text[end:]
        path.write_text(text, encoding="utf-8")
        touched_files += 1

    print(f"replace-dart: 已写回 {touched_files} 个文件（共 {len(char_edits)} 条替换）")
    return 0


def cmd_apply_all(args: argparse.Namespace) -> int:
    if not args.confirm:
        print("拒绝：apply-all 必须带 --confirm", file=sys.stderr)
        return 2
    repo = _repo_root()
    mp = _manifest_path(repo, args.manifest)
    if not mp.is_file():
        print(f"找不到 manifest: {mp}", file=sys.stderr)
        return 2

    class _A:
        manifest = mp

    cmd_merge_arb(_A())
    cmd_replace_dart(_A())
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_scan = sub.add_parser("scan")
    p_scan.add_argument("--root", default="frontend/lib")
    p_scan.add_argument("--subtree", default=None)
    p_scan.set_defaults(func=cmd_scan)

    p_prep = sub.add_parser("prepare")
    p_prep.add_argument("--root", default="frontend/lib")
    p_prep.add_argument("--subtree", default=None)
    p_prep.add_argument("--no-translate", action="store_true")
    p_prep.add_argument("--translate-tokens", action="store_true")
    p_prep.set_defaults(func=cmd_prepare)

    p_merge = sub.add_parser("merge-arb")
    p_merge.add_argument("--manifest", type=Path, default=None)
    p_merge.set_defaults(func=cmd_merge_arb)

    p_rep = sub.add_parser("replace-dart")
    p_rep.add_argument("--manifest", type=Path, default=None)
    p_rep.set_defaults(func=cmd_replace_dart)

    p_all = sub.add_parser("apply-all")
    p_all.add_argument("--manifest", type=Path, default=None)
    p_all.add_argument("--confirm", action="store_true")
    p_all.set_defaults(func=cmd_apply_all)

    args = ap.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
