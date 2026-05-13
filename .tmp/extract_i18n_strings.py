#!/usr/bin/env python3
"""
Extract Chinese strings from Dart files and generate ARB entries.
"""
import re
import json
import sys
from pathlib import Path
from collections import defaultdict

def is_chinese(text):
    """Check if text contains Chinese characters."""
    return bool(re.search(r'[\u4e00-\u9fff]', text))

def extract_strings_from_file(filepath):
    """Extract Chinese strings from a Dart file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)
        return []
    
    strings = []
    
    # Match single-quoted strings
    for match in re.finditer(r"'([^'\\]*(\\.[^'\\]*)*)'", content):
        text = match.group(1)
        if is_chinese(text):
            strings.append(text)
    
    # Match double-quoted strings  
    for match in re.finditer(r'"([^"\\]*(\\.[^"\\]*)*)"', content):
        text = match.group(1)
        if is_chinese(text):
            strings.append(text)
    
    # Match triple-quoted strings
    for match in re.finditer(r"'''(.*?)'''", content, re.DOTALL):
        text = match.group(1)
        if is_chinese(text):
            strings.append(text)
    
    for match in re.finditer(r'"""(.*?)"""', content, re.DOTALL):
        text = match.group(1)
        if is_chinese(text):
            strings.append(text)
    
    return strings

def generate_key(text, prefix, existing_keys):
    """Generate a unique ARB key for a Chinese string."""
    # Clean the text for key generation
    clean = re.sub(r'[^\u4e00-\u9fff\w]', '', text)[:30]
    
    # Try to create a meaningful key
    base_key = f"{prefix}{clean}"
    
    # Ensure uniqueness
    key = base_key
    counter = 1
    while key in existing_keys:
        key = f"{base_key}{counter}"
        counter += 1
    
    return key

def main():
    root = Path("/Users/clive/Documents/source/cousor/Toonflow-app/frontend")
    
    # Directories to scan
    dirs = [
        ("short_video_space", "shortVideoSpace"),
        ("script_editor", "scriptEditor"),
        ("content_compliance", "contentCompliance"),
        ("skills_harness", "skillsHarness"),
    ]
    
    all_strings = defaultdict(list)
    
    for dir_name, prefix in dirs:
        dir_path = root / "lib" / dir_name
        if not dir_path.exists():
            print(f"Directory not found: {dir_path}", file=sys.stderr)
            continue
        
        for dart_file in dir_path.rglob("*.dart"):
            strings = extract_strings_from_file(dart_file)
            if strings:
                rel_path = dart_file.relative_to(root)
                all_strings[prefix].extend([(str(rel_path), s) for s in strings])
                print(f"Found {len(strings)} Chinese strings in {rel_path}")
    
    # Generate summary
    print("\n=== Summary ===")
    for prefix, items in all_strings.items():
        print(f"{prefix}: {len(items)} strings")
    
    # Save to JSON for further processing
    output = {}
    for prefix, items in all_strings.items():
        output[prefix] = [{"file": f, "text": t} for f, t in items]
    
    output_path = Path("/Users/clive/Documents/source/cousor/Toonflow-app/.tmp/i18n_strings.json")
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    
    print(f"\nSaved to {output_path}")

if __name__ == "__main__":
    main()
