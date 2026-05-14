#!/usr/bin/env python3
"""
批量 i18n：扫描 Text/SelectableText 的「整段 ${} 插值字符串」→ 生成 ARB 草案与替换清单 →（审阅后）再合并 ARB / 再改 Dart。

只处理：单行、首个参数为带 `${expr}` 的引号字符串（无嵌套引号）。`${l10n.x}$suffix` 等非 `${}` 的 `$` 会跳过。

推荐流程（先审阅、后落库）::

  python3 scripts/l10n_batch_pipeline.py prepare --root frontend/lib [--subtree shell]
  # 查看 frontend/.l10n_batch/prepare_manifest.json 与 prepare_report.md

  python3 scripts/l10n_batch_pipeline.py merge-arb
  cd frontend && flutter gen-l10n

  python3 scripts/l10n_batch_pipeline.py replace-dart

一键（不推荐，易跳过审阅）::

  python3 scripts/l10n_batch_pipeline.py apply-all --confirm --no-translate

可选机翻：pip install -r scripts/requirements_l10n_batch.txt 后 prepare 时勿加 --no-translate。
"""

from __future__ import annotations

import argparse
import hashlib
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

MANIFEST_NAME = "prepare_manifest.json"
REPORT_NAME = "prepare_report.md"


def _manifest_path(repo: Path, p: Path | None) -> Path:
    if p is None:
        return repo / "frontend" / ".l10n_batch" / MANIFEST_NAME
    return p if p.is_absolute() else repo / p


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


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


@dataclass
class Occurrence:
    path: Path
    line_no: int
    line: str
    match_start: int
    match_end: int
    widget: str
    body: str
    literals: list[str]
    exprs: list[str]
    norm: str
    l10n_key: str
    ph_types: list[str]


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
            line_list = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            continue
        for i, line in enumerate(line_list, 1):
            if "Text(" not in line and "SelectableText(" not in line:
                continue
            for m in _STR_RE.finditer(line):
                body = m.group("body")
                if _should_skip_body(body):
                    continue
                parsed = _parse_interpolation_body(body)
                if parsed is None:
                    continue
                literals, exprs = parsed
                if m.group("q") in literals or any(
                    m.group("q") in lit for lit in literals
                ):
                    continue
                norm = _normalize_template(literals, len(exprs))
                key = _stable_key(norm)
                types = [_infer_placeholder_type(e) for e in exprs]
                out.append(
                    Occurrence(
                        path=path,
                        line_no=i,
                        line=line,
                        match_start=m.start(),
                        match_end=m.end(),
                        widget=m.group("widget"),
                        body=body,
                        literals=literals,
                        exprs=exprs,
                        norm=norm,
                        l10n_key=key,
                        ph_types=types,
                    )
                )
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
    """返回新写入的键数量。"""
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


def _replacement_snippet(o: Occurrence) -> str:
    args = ", ".join(o.exprs)
    inner = f"l10n.{o.l10n_key}({args})" if args else f"l10n.{o.l10n_key}()"
    return f"{o.widget}({inner}"


def _build_plan(
    occ: list[Occurrence],
    *,
    no_translate: bool,
    translate_tokens: bool,
) -> tuple[
    OrderedDict[str, str],
    OrderedDict[str, str],
    OrderedDict[str, dict],
    dict[tuple[Path, int], tuple[str, str]],
]:
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

    line_edits: dict[tuple[Path, int], tuple[str, str]] = {}
    by_line: dict[tuple[Path, int], list[Occurrence]] = defaultdict(list)
    for o in occ:
        by_line[(o.path, o.line_no)].append(o)
    for key, items in by_line.items():
        old_line = items[0].line
        new_line = old_line
        for o in sorted(items, key=lambda x: x.match_start, reverse=True):
            new_line = (
                new_line[: o.match_start]
                + _replacement_snippet(o)
                + new_line[o.match_end :]
            )
        line_edits[key] = (old_line, new_line)

    return additions_en, additions_zh, meta, line_edits


def _write_report(
    path: Path,
    occ: list[Occurrence],
    additions_en: OrderedDict[str, str],
    line_edits: dict[tuple[Path, int], tuple[str, str]],
) -> None:
    lines = [
        "# l10n batch prepare 报告",
        "",
        f"- 扫描命中: **{len(occ)}** 处",
        f"- 去重后 ARB 模板: **{len(additions_en)}** 条",
        f"- 将修改行数: **{len(line_edits)}**",
        "",
        "## 新增 EN 键（摘要）",
        "",
    ]
    for k, v in list(additions_en.items())[:40]:
        lines.append(f"- `{k}` → `{v}`")
    if len(additions_en) > 40:
        lines.append(f"- … 共 {len(additions_en)} 条，详见 manifest")
    lines += ["", "## 逐行替换预览", ""]
    for (p, ln), (old, new) in sorted(
        line_edits.items(), key=lambda x: (str(x[0][0]), x[0][1])
    ):
        rel = p.relative_to(_repo_root())
        lines.append(f"### `{rel}`:{ln}")
        lines.append("")
        lines.append("```dart")
        lines.append(old)
        lines.append("```")
        lines.append("")
        lines.append("→")
        lines.append("")
        lines.append("```dart")
        lines.append(new)
        lines.append("```")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def cmd_scan(args: argparse.Namespace) -> int:
    root = _repo_root() / args.root
    occ = scan_lib(root, args.subtree)
    out_path = _repo_root() / "frontend" / ".l10n_batch" / "scan.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    payload = [
        {
            "file": str(o.path.relative_to(_repo_root())),
            "line": o.line_no,
            "key": o.l10n_key,
            "body": o.body,
            "exprs": o.exprs,
            "types": o.ph_types,
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
    additions_en, additions_zh, meta, line_edits = _build_plan(
        occ,
        no_translate=args.no_translate,
        translate_tokens=args.translate_tokens,
    )

    out_dir = repo / "frontend" / ".l10n_batch"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / MANIFEST_NAME

    line_edits_json = [
        {
            "file": str(p.relative_to(repo)).replace("\\", "/"),
            "line": ln,
            "old_line": old,
            "new_line": new,
        }
        for (p, ln), (old, new) in sorted(
            line_edits.items(), key=lambda x: (str(x[0][0]), x[0][1])
        )
    ]

    manifest = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "root": str(args.root).replace("\\", "/"),
        "subtree": args.subtree,
        "no_translate": args.no_translate,
        "translate_tokens": args.translate_tokens,
        "arb_additions_en": dict(additions_en),
        "arb_additions_zh": dict(additions_zh),
        "arb_meta": dict(meta),
        "line_edits": line_edits_json,
        "occurrences": [
            {
                "file": str(o.path.relative_to(repo)).replace("\\", "/"),
                "line": o.line_no,
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
    report_path = out_dir / REPORT_NAME
    _write_report(report_path, occ, additions_en, line_edits)

    print(
        f"prepare: {len(occ)} hits, {len(additions_en)} ARB templates, "
        f"{len(line_edits)} lines to edit"
    )
    print(f"  manifest -> {manifest_path.relative_to(repo)}")
    print(f"  report    -> {report_path.relative_to(repo)}")
    print("审阅后执行: merge-arb → flutter gen-l10n → replace-dart")
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
    edits = data.get("line_edits", [])
    if not edits:
        print("manifest 中无 line_edits，跳过")
        return 0

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
            print(
                f"SKIP 行已变化（请重新 prepare）{rel}:{line_no}\n"
                f"  期望: {old_line[:120]!r}…\n"
                f"  实际: {cur.rstrip()[:120]!r}…",
                file=sys.stderr,
            )
            continue
        nl = "\r\n" if cur.endswith("\r\n") else ("\n" if cur.endswith("\n") else "")
        lines[idx] = new_line + nl
        path.write_text("".join(lines), encoding="utf-8")
        touched += 1
    print(f"replace-dart: 已更新 {touched} 行（共 {len(edits)} 条计划）")
    return 0


def cmd_apply_all(args: argparse.Namespace) -> int:
    if not args.confirm:
        print("拒绝：apply-all 必须带 --confirm（请先 prepare 并审阅 manifest）", file=sys.stderr)
        return 2
    repo = _repo_root()
    mp = _manifest_path(repo, args.manifest)
    if not mp.is_file():
        print(f"找不到 manifest，请先运行 prepare: {mp}", file=sys.stderr)
        return 2

    class _A:
        manifest = mp

    args_m = _A()
    cmd_merge_arb(args_m)
    cmd_replace_dart(args_m)
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
    p_merge.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="prepare 生成的 manifest（默认 frontend/.l10n_batch/prepare_manifest.json）",
    )
    p_merge.set_defaults(func=cmd_merge_arb)

    p_rep = sub.add_parser("replace-dart")
    p_rep.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="与 merge-arb 使用的同一份 manifest",
    )
    p_rep.set_defaults(func=cmd_replace_dart)

    p_all = sub.add_parser("apply-all")
    p_all.add_argument("--manifest", type=Path, default=None)
    p_all.add_argument(
        "--confirm",
        action="store_true",
        help="确认已审阅 manifest 后再执行 merge-arb + replace-dart",
    )
    p_all.set_defaults(func=cmd_apply_all)

    args = ap.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
