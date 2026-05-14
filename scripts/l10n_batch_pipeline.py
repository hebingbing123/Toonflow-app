#!/usr/bin/env python3
"""
批量 i18n：扫描 Text/SelectableText 的「整段插值字符串」→ 合并 app_en/app_zh.arb → 回写 Dart。

只处理：单行、首个参数为带 `${expr}` 的引号字符串（无嵌套引号）。相同「字面量片段序列 + 占位符个数」共用一条 ARB。

用法::

  python3 scripts/l10n_batch_pipeline.py scan --root frontend/lib
  python3 scripts/l10n_batch_pipeline.py apply --root frontend/lib --dry-run
  python3 scripts/l10n_batch_pipeline.py apply --root frontend/lib

可选：pip install -r scripts/requirements_l10n_batch.txt 后自动中译（否则结构类模板 zh 与 en 相同）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import OrderedDict, defaultdict
from dataclasses import dataclass
from pathlib import Path

# 只匹配到闭合引号为止，不吞 style: 等后续参数
_STR_RE = re.compile(
    r"(?P<widget>Text|SelectableText)\s*\(\s*(?P<q>['\"])(?P<body>.*?)(?P=q)"
)


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
    if "l10n." in body:
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


def scan_lib(lib_root: Path) -> list[Occurrence]:
    skip = {"l10n", "generated", ".dart_tool"}
    out: list[Occurrence] = []
    for path in sorted(lib_root.rglob("*.dart")):
        if any(p in path.parts for p in skip):
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
                # 字符串内转义引号暂不支持
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
) -> None:
    data = _load_arb(arb_path)
    for k, v in additions.items():
        if k in data:
            continue
        data[k] = v
        mk = f"@{k}"
        if mk in meta and meta[mk]:
            data[mk] = dict(meta[mk])
    _save_arb(arb_path, data)


def _replacement_snippet(o: Occurrence) -> str:
    # 匹配结束在闭合引号处，原行在引号后仍有 `)` 关闭 Text( —— 此处不再输出最外层 `)`
    args = ", ".join(o.exprs)
    inner = f"l10n.{o.l10n_key}({args})" if args else f"l10n.{o.l10n_key}()"
    return f"{o.widget}({inner}"


def cmd_scan(args: argparse.Namespace) -> int:
    root = _repo_root() / args.root
    occ = scan_lib(root)
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


def cmd_apply(args: argparse.Namespace) -> int:
    import sys

    root = _repo_root() / args.root
    occ = scan_lib(root)
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
        if args.no_translate:
            zh_msg = msg_en
        elif re.search(r"[A-Za-z]{4,}", sample) or args.translate_tokens:
            zh_msg = _translate_zh(msg_en)
        else:
            zh_msg = msg_en
        additions_zh[key] = zh_msg

    by_line: dict[tuple[Path, int], list[Occurrence]] = defaultdict(list)
    for o in occ:
        by_line[(o.path, o.line_no)].append(o)

    repo = _repo_root()
    en_path = repo / "frontend/lib/l10n/app_en.arb"
    zh_path = repo / "frontend/lib/l10n/app_zh.arb"

    print(f"New ARB templates: {len(by_norm)}; occurrences: {len(occ)}")
    if args.dry_run:
        for k, v in list(additions_en.items())[:12]:
            print(f"  {k}: {v!r}")
        return 0

    _merge_arb(en_path, additions_en, meta)
    _merge_arb(zh_path, additions_zh, meta)

    changed_files: set[Path] = set()
    for (path, line_no), items in sorted(by_line.items()):
        items.sort(key=lambda x: x.match_start, reverse=True)
        base_line = items[0].line
        new_line = base_line
        for o in sorted(items, key=lambda x: x.match_start, reverse=True):
            new_line = (
                new_line[: o.match_start]
                + _replacement_snippet(o)
                + new_line[o.match_end :]
            )

        all_lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
        idx = line_no - 1
        cur = all_lines[idx]
        if cur.rstrip("\n\r") != base_line.rstrip("\n\r"):
            print(f"SKIP stale {path}:{line_no}", file=sys.stderr)
            continue
        nl = "\n" if cur.endswith("\n") else ""
        if cur.endswith("\r\n"):
            nl = "\r\n"
        all_lines[idx] = new_line + nl
        path.write_text("".join(all_lines), encoding="utf-8")
        changed_files.add(path)

    print(f"Updated ARB; touched {len(changed_files)} dart files")
    return 0


def main() -> int:
    import sys

    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_scan = sub.add_parser("scan")
    p_scan.add_argument("--root", default="frontend/lib")
    p_scan.set_defaults(func=cmd_scan)

    p_apply = sub.add_parser("apply")
    p_apply.add_argument("--root", default="frontend/lib")
    p_apply.add_argument("--dry-run", action="store_true")
    p_apply.add_argument(
        "--no-translate",
        action="store_true",
        help="zh 与 en 使用同一模板字符串",
    )
    p_apply.add_argument(
        "--translate-tokens",
        action="store_true",
        help="对无长英文的模板也调用在线翻译",
    )
    p_apply.set_defaults(func=cmd_apply)

    args = ap.parse_args()
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
