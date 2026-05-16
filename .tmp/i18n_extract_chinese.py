#!/usr/bin/env python3
"""
Extract Chinese strings from Dart files for i18n migration.
Generates a report of files with Chinese strings, prioritized by category.
"""

import re
import os
import json
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Tuple

# Priority categories based on user-facing impact
PRIORITY_CATEGORIES = {
    'auth': {'priority': 1, 'patterns': ['auth', 'login', 'register', 'password']},
    'navigation': {'priority': 1, 'patterns': ['navigation', 'nav', 'menu', 'tab', 'drawer']},
    'error': {'priority': 1, 'patterns': ['error', 'exception', 'snackbar', 'toast']},
    'dialog': {'priority': 1, 'patterns': ['dialog', 'alert', 'confirm']},
    'overview': {'priority': 2, 'patterns': ['overview', 'dashboard', 'home']},
    'workspace': {'priority': 2, 'patterns': ['workspace', 'team', 'member']},
    'project': {'priority': 2, 'patterns': ['project', 'projects_section']},
    'settings': {'priority': 3, 'patterns': ['settings', 'preferences', 'config']},
    'task_center': {'priority': 3, 'patterns': ['task_center', 'jobs']},
    'short_video': {'priority': 2, 'patterns': ['short_video_space']},
    'other': {'priority': 4, 'patterns': []},
}

def categorize_file(filepath: str) -> Tuple[str, int]:
    """Categorize a file based on its path."""
    filepath_lower = filepath.lower()
    
    for category, info in PRIORITY_CATEGORIES.items():
        if category == 'other':
            continue
        for pattern in info['patterns']:
            if pattern in filepath_lower:
                return category, info['priority']
    
    return 'other', PRIORITY_CATEGORIES['other']['priority']

def extract_chinese_strings(content: str) -> List[Dict]:
    """Extract Chinese strings from Dart code."""
    strings = []
    
    # Pattern for string literals containing Chinese characters
    # Matches both single and double quoted strings
    patterns = [
        r"'([^']*[\u4e00-\u9fff][^']*)'",  # Single quotes
        r'"([^"]*[\u4e00-\u9fff][^"]*)"',  # Double quotes
    ]
    
    for pattern in patterns:
        for match in re.finditer(pattern, content):
            chinese_text = match.group(1)
            # Get line number
            line_num = content[:match.start()].count('\n') + 1
            strings.append({
                'text': chinese_text,
                'line': line_num,
                'quote': match.group(0)[0]  # ' or "
            })
    
    return strings

def scan_directory(base_path: str) -> Dict:
    """Scan directory for Dart files with Chinese strings."""
    results = defaultdict(lambda: {
        'files': [],
        'total_strings': 0,
        'priority': 4
    })
    
    frontend_lib = Path(base_path) / 'frontend' / 'lib'
    
    for dart_file in frontend_lib.rglob('*.dart'):
        # Skip generated files
        if '.g.dart' in str(dart_file) or 'app_localizations' in str(dart_file):
            continue
            
        try:
            content = dart_file.read_text(encoding='utf-8')
            chinese_strings = extract_chinese_strings(content)
            
            if chinese_strings:
                rel_path = str(dart_file.relative_to(frontend_lib))
                category, priority = categorize_file(rel_path)
                
                results[category]['files'].append({
                    'path': rel_path,
                    'strings': chinese_strings,
                    'count': len(chinese_strings)
                })
                results[category]['total_strings'] += len(chinese_strings)
                results[category]['priority'] = priority
                
        except Exception as e:
            print(f"Error processing {dart_file}: {e}")
    
    return dict(results)

def generate_report(results: Dict, output_path: str):
    """Generate a detailed report."""
    # Sort categories by priority
    sorted_categories = sorted(
        results.items(),
        key=lambda x: (x[1]['priority'], -x[1]['total_strings'])
    )
    
    report_lines = [
        "# i18n Migration Status Report",
        "",
        "## Summary",
        ""
    ]
    
    total_files = sum(len(cat['files']) for cat in results.values())
    total_strings = sum(cat['total_strings'] for cat in results.values())
    
    report_lines.extend([
        f"- **Total files with Chinese strings**: {total_files}",
        f"- **Total Chinese strings**: {total_strings}",
        "",
        "## By Category (Priority Order)",
        ""
    ])
    
    for category, data in sorted_categories:
        report_lines.extend([
            f"### {category.upper()} (Priority {data['priority']})",
            f"- Files: {len(data['files'])}",
            f"- Strings: {data['total_strings']}",
            ""
        ])
        
        # Sort files by string count (descending)
        sorted_files = sorted(data['files'], key=lambda x: x['count'], reverse=True)
        
        for file_info in sorted_files[:10]:  # Top 10 files per category
            report_lines.append(f"  - `{file_info['path']}`: {file_info['count']} strings")
        
        if len(sorted_files) > 10:
            report_lines.append(f"  - ... and {len(sorted_files) - 10} more files")
        
        report_lines.append("")
    
    # Write report
    Path(output_path).write_text('\n'.join(report_lines), encoding='utf-8')
    
    # Also write detailed JSON
    json_path = output_path.replace('.md', '.json')
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    
    print(f"Report written to: {output_path}")
    print(f"Detailed data written to: {json_path}")

def main():
    base_path = os.getcwd()
    results = scan_directory(base_path)
    
    output_path = os.path.join(base_path, '.tmp', 'i18n_migration_analysis.md')
    generate_report(results, output_path)
    
    # Print summary
    print("\n=== Summary ===")
    total_files = sum(len(cat['files']) for cat in results.values())
    total_strings = sum(cat['total_strings'] for cat in results.values())
    print(f"Total files: {total_files}")
    print(f"Total strings: {total_strings}")
    print("\nPriority 1 (Critical):")
    for cat, data in results.items():
        if data['priority'] == 1:
            print(f"  {cat}: {len(data['files'])} files, {data['total_strings']} strings")

if __name__ == '__main__':
    main()
