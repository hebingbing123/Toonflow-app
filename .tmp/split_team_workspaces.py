#!/usr/bin/env python3
"""
Split team_workspaces/section.dart into multiple files.

Strategy:
1. Main file: Keep State class complete with lifecycle methods AND build method
2. Helpers extension: Only helper methods (from after lifecycle methods to before build)
"""

def main():
    input_file = 'frontend/lib/team_workspaces/section.dart'
    
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find key line numbers
    build_method_start = None
    state_class_start = None
    first_helper_method_start = None
    
    for i, line in enumerate(lines):
        if 'class _TeamWorkspacesSectionState extends State<TeamWorkspacesSection> {' in line:
            state_class_start = i
        elif '  Widget build(BuildContext context) {' in line and '@override' in lines[i-1]:
            build_method_start = i - 1  # Include @override
    
    # Find the first helper method after lifecycle methods
    # Look for the first method after dispose()
    found_dispose = False
    for i in range(state_class_start, build_method_start):
        if '  void dispose() {' in lines[i]:
            found_dispose = True
        elif found_dispose and lines[i].strip().startswith('Future<void> ') or \
             (found_dispose and lines[i].strip().startswith('void ') and '_' in lines[i]) or \
             (found_dispose and lines[i].strip().startswith('String ') and '_' in lines[i]):
            first_helper_method_start = i
            break
    
    print(f"state_class_start: {state_class_start}")
    print(f"first_helper_method_start: {first_helper_method_start}")
    print(f"build_method_start: {build_method_start}")
    
    # Extract sections
    # Main file: everything except the helper methods
    main_before = lines[:first_helper_method_start]
    helpers_content = lines[first_helper_method_start:build_method_start]
    main_after = lines[build_method_start:]
    
    # Write main file
    with open(input_file, 'w', encoding='utf-8') as f:
        # Write everything up to the helper methods
        for i, line in enumerate(main_before):
            # Add part declaration after imports
            if i == state_class_start - 1:
                f.write('\n// Split into multiple files for maintainability\n')
                f.write("part 'section_helpers.dart';\n")
            f.write(line)
        
        # Write build method and rest of class
        f.writelines(main_after)
    
    # Write helpers file
    with open('frontend/lib/team_workspaces/section_helpers.dart', 'w', encoding='utf-8') as f:
        f.write("// ignore_for_file: invalid_use_of_protected_member\n")
        f.write("// ignore_for_file: unqualified_reference_to_static_member_of_extended_type\n\n")
        f.write("part of 'section.dart';\n\n")
        f.write("/// Helper methods for TeamWorkspacesSection\n")
        f.write("extension _TeamWorkspacesSectionHelpers on _TeamWorkspacesSectionState {\n")
        f.writelines(helpers_content)
        f.write('}\n')
    
    print(f"\nSplit complete!")
    print(f"Main file: {len(main_before) + len(main_after) + 2} lines")
    print(f"Helpers file: {len(helpers_content) + 5} lines")

if __name__ == '__main__':
    main()
