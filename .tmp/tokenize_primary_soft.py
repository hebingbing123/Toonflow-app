#!/usr/bin/env python3
"""Replace M3 container colors with StudioTokens in product UI."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "frontend" / "lib"
SKIP_SUBSTR = {
    "design_system/theme.dart",
    "shell/pipeline_step_chip.dart",
    "status_page.dart",
    "short_video_space/desktop_capability.dart",
    "settings/model_pricing/value_tier_badge.dart",
    "design_system/components/studio_cost_estimate_chip.dart",
    "team_workspaces/section_helpers.dart",
    "quality_reviews/",
}

FILES = [
    "short_video_space/components/preview_player.dart",
    "short_video_space/components/version_comparison.dart",
    "short_video_space/view_publish_drafts.dart",
    "settings/model_vendors/model_vendors_section.dart",
    "short_video_space/dialogs/export_settings_dialog.dart",
    "short_video_space/section_production_assembly.dart",
    "api_keys/section.dart",
    "global_search/search_result_card.dart",
    "global_search/advanced_filter_panel.dart",
    "short_video_space/components/version_manager.dart",
    "short_video_space/dialogs/export_history_dialog.dart",
    "notifications/section.dart",
    "short_video_space/components/batch_operation_toolbar.dart",
    "project_studio/novel_crawl_platform_hint.dart",
    "short_video_space/view_project_selector.dart",
    "short_video_space/view.dart",
    "short_video_space/view_production_panel.dart",
]


def sub_pc(text: str) -> str:
    pairs = [
        (r"Theme\.of\(context\)\.colorScheme\.primaryContainer", "StudioTokens.of(context).primarySoft"),
        (r"Theme\.of\(ctx\)\.colorScheme\.primaryContainer", "StudioTokens.of(ctx).primarySoft"),
        (r"theme\.colorScheme\.primaryContainer", "StudioTokens.of(context).primarySoft"),
        (r"\)\.colorScheme\.primaryContainer", ").primarySoft"),  # rare: Theme.of(ctx) already partial
        (r"Theme\.of\(context\)\.colorScheme\.secondaryContainer", "StudioTokens.of(context).accentSoft"),
        (r"theme\.colorScheme\.secondaryContainer", "StudioTokens.of(context).accentSoft"),
    ]
    for pat, repl in pairs:
        text = re.sub(pat, repl, text)
    return text


def ensure_import(text: str, path: Path) -> str:
    if "StudioTokens" not in text or "tokens.dart" in text:
        return text
    depth = len(path.relative_to(ROOT).parts) - 1
    imp = f"import {'../' * depth}design_system/tokens.dart';\n"
    lines = text.splitlines(keepends=True)
    for i, line in enumerate(lines):
        if line.startswith("import "):
            lines.insert(i + 1, imp)
            break
    return "".join(lines)


def main() -> None:
    for rel in FILES:
        path = ROOT / rel
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        new = sub_pc(text)
        if new != text:
            new = ensure_import(new, path)
            path.write_text(new, encoding="utf-8")
            print(rel)


if __name__ == "__main__":
    main()
