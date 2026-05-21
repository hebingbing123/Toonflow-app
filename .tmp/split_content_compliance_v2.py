#!/usr/bin/env python3
"""
Split content_compliance/section.dart into multiple files.

Strategy:
1. Main file: Keep State class complete with lifecycle methods AND build method
2. Helpers extension: Only helper methods (from _syncFilterStateFromController to before build)
"""

def main():
    input_file = 'frontend/lib/content_compliance/section.dart'
    
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find key line numbers
    build_method_start = None
    sync_filter_method_start = None
    
    for i, line in enumerate(lines):
        if '  void _syncFilterStateFromController() {' in line:
            sync_filter_method_start = i
        elif '  Widget build(BuildContext context) {' in line and '@override' in lines[i-1]:
            build_method_start = i - 1  # Include @override
    
    print(f"sync_filter_method_start: {sync_filter_method_start}")
    print(f"build_method_start: {build_method_start}")
    
    # Extract sections
    # Main file: everything except the helper methods
    main_before = lines[:sync_filter_method_start]
    helpers_content = lines[sync_filter_method_start:build_method_start]
    main_after = lines[build_method_start:]
    
    # Write main file
    with open(input_file, 'w', encoding='utf-8') as f:
        # Write imports and class definition up to _onChanged
        for line in main_before:
            if line.strip() == 'class _ContentComplianceSectionState extends State<ContentComplianceSection> {':
                f.write('\n// Split into multiple files for maintainability\n')
                f.write("part 'section_helpers.dart';\n\n")
            f.write(line)
        
        # Write build method and rest of class
        f.writelines(main_after)
    
    # Write helpers file
    with open('frontend/lib/content_compliance/section_helpers.dart', 'w', encoding='utf-8') as f:
        f.write("part of 'section.dart';\n\n")
        f.write("/// Helper methods for ContentComplianceSection\n")
        f.write("extension _ContentComplianceSectionHelpers on _ContentComplianceSectionState {\n")
        f.writelines(helpers_content)
        f.write('}\n')
    
    print(f"\nSplit complete!")
    print(f"Main file: {len(main_before) + len(main_after) + 2} lines")
    print(f"Helpers file: {len(helpers_content) + 4} lines")

if __name__ == '__main__':
    main()
