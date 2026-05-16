#!/usr/bin/env python3
"""
i18n Migration Phase 2 Batch 1: Extract and migrate strings from short_video_space module
Target files:
1. support_publish_api.dart (125 strings)
2. section_production_assembly.dart (110 strings)
3. support_production_api.dart (89 strings)
"""

import re
import json
from pathlib import Path
from typing import Dict, List, Tuple

# Base paths
FRONTEND_DIR = Path(__file__).parent.parent / "frontend"
LIB_DIR = FRONTEND_DIR / "lib"
L10N_DIR = LIB_DIR / "l10n"
SHORT_VIDEO_DIR = LIB_DIR / "short_video_space"

# Target files
TARGET_FILES = [
    "support_publish_api.dart",
    "section_production_assembly.dart",
    "support_production_api.dart",
]

# ARB files
ARB_EN = L10N_DIR / "app_en.arb"
ARB_ZH = L10N_DIR / "app_zh.arb"


def extract_chinese_strings(file_path: Path) -> List[Tuple[str, int, str]]:
    """Extract Chinese strings from a Dart file.
    Returns list of (string, line_number, context)
    """
    content = file_path.read_text(encoding='utf-8')
    lines = content.split('\n')
    
    chinese_strings = []
    chinese_pattern = re.compile(r'[\u4e00-\u9fff]+')
    
    for line_num, line in enumerate(lines, 1):
        # Skip comments
        if line.strip().startswith('//'):
            continue
            
        # Find string literals containing Chinese
        string_matches = re.finditer(r"'([^']*)'|\"([^\"]*)\"", line)
        for match in string_matches:
            string_content = match.group(1) or match.group(2)
            if string_content and chinese_pattern.search(string_content):
                chinese_strings.append((string_content, line_num, line.strip()))
    
    return chinese_strings


def generate_arb_key(base_prefix: str, chinese_text: str, index: int) -> str:
    """Generate a camelCase ARB key from Chinese text."""
    # Simple heuristic: use first few meaningful characters
    # For production, this would need manual review
    key = f"{base_prefix}{index:03d}"
    return key


def main():
    print("=== i18n Phase 2 Batch 1 Migration ===\n")
    
    all_strings = {}
    
    for filename in TARGET_FILES:
        file_path = SHORT_VIDEO_DIR / filename
        if not file_path.exists():
            print(f"❌ File not found: {file_path}")
            continue
            
        print(f"📄 Processing {filename}...")
        strings = extract_chinese_strings(file_path)
        all_strings[filename] = strings
        print(f"   Found {len(strings)} Chinese strings")
    
    print(f"\n📊 Total strings found: {sum(len(s) for s in all_strings.values())}")
    
    # Generate report
    report_path = Path(__file__).parent / "i18n_phase2_batch1_report.txt"
    with open(report_path, 'w', encoding='utf-8') as f:
        f.write("i18n Phase 2 Batch 1 - String Extraction Report\n")
        f.write("=" * 60 + "\n\n")
        
        for filename, strings in all_strings.items():
            f.write(f"\n{filename} ({len(strings)} strings)\n")
            f.write("-" * 60 + "\n")
            for string, line_num, context in strings[:20]:  # First 20 for preview
                f.write(f"Line {line_num}: {string}\n")
                f.write(f"  Context: {context[:80]}...\n\n")
            if len(strings) > 20:
                f.write(f"  ... and {len(strings) - 20} more strings\n")
    
    print(f"\n✅ Report saved to: {report_path}")
    print("\nNext steps:")
    print("1. Review the report to understand string patterns")
    print("2. Manually create ARB entries with meaningful keys")
    print("3. Replace hardcoded strings with AppLocalizations calls")
    print("4. Run flutter gen-l10n to regenerate localization files")
    print("5. Run flutter analyze to verify changes")


if __name__ == "__main__":
    main()
