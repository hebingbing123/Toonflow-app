#!/usr/bin/env python3
"""
Split content_compliance/section.dart into multiple files.

Strategy:
1. Main file: Keep State class with lifecycle methods only (initState, didUpdateWidget, dispose, _onChanged)
2. Helpers extension: All helper methods from _syncFilterStateFromController to before build
3. UI extension: Build method
"""

def main():
    input_file = 'frontend/lib/content_compliance/section.dart'
    
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find key line numbers
    build_method_start = None
    sync_filter_method_start = None
    class_end = None
    
    for i, line in enumerate(lines):
        if '  void _syncFilterStateFromController() {' in line:
            sync_filter_method_start = i
        elif '  Widget build(BuildContext context) {' in line and '@override' in lines[i-1]:
            build_method_start = i - 1  # Include @override
        elif line.strip() == '}' and i == len(lines) - 1:
            class_end = i
    
    print(f"sync_filter_method_start: {sync_filter_method_start}")
    print(f"build_method_start: {build_method_start}")
    print(f"class_end: {class_end}")
    
    # Extract sections
    # Main file: from start to _onChanged (before _syncFilterStateFromController)
    main_content = lines[:sync_filter_method_start]
    
    # Helpers: from _syncFilterStateFromController to before build
    helpers_content = lines[sync_filter_method_start:build_method_start]
    
    # UI: from build to end of class
    ui_content = lines[build_method_start:class_end]
    
    # Write main file
    with open(input_file, 'w', encoding='utf-8') as f:
        f.writelines(main_content)
        f.write('}\n')  # Close the State class
        f.write('\n')
        f.write('// Split into multiple files for maintainability\n')
        f.write("part 'section_helpers.dart';\n")
        f.write("part 'section_ui.dart';\n")
    
    # Write helpers file
    with open('frontend/lib/content_compliance/section_helpers.dart', 'w', encoding='utf-8') as f:
        f.write("part of 'section.dart';\n\n")
        f.write("/// Helper methods for ContentComplianceSection\n")
        f.write("extension _ContentComplianceSectionHelpers on _ContentComplianceSectionState {\n")
        f.writelines(helpers_content)
        f.write('}\n')
    
    # Write UI file
    with open('frontend/lib/content_compliance/section_ui.dart', 'w', encoding='utf-8') as f:
        f.write("part of 'section.dart';\n\n")
        f.write("/// UI building for ContentComplianceSection\n")
        f.write("extension _ContentComplianceSectionUI on _ContentComplianceSectionState {\n")
        f.writelines(ui_content)
        f.write('}\n')
    
    print(f"\nSplit complete!")
    print(f"Main file: {len(main_content) + 4} lines")
    print(f"Helpers file: {len(helpers_content) + 4} lines")
    print(f"UI file: {len(ui_content) + 4} lines")

if __name__ == '__main__':
    main()
