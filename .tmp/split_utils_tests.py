#!/usr/bin/env python3
"""
Split utils.rs into utils.rs (utility functions) and tests.rs (test module)
"""

from pathlib import Path

def read_lines(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.readlines()

def write_lines(path, lines):
    with open(path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

def main():
    utils_path = Path('backend/src/production/workbench/video/generate/utils.rs')
    tests_path = Path('backend/src/production/workbench/video/generate/tests.rs')
    
    lines = read_lines(utils_path)
    
    # Find where #[cfg(test)] starts
    test_start = None
    for i, line in enumerate(lines):
        if '#[cfg(test)]' in line:
            test_start = i
            break
    
    if test_start is None:
        print("No #[cfg(test)] found!")
        return
    
    print(f"Tests start at line {test_start + 1}")
    
    # Split into utils and tests
    utils_lines = lines[:test_start]
    test_lines = lines[test_start:]
    
    # Write utils.rs (without tests)
    write_lines(utils_path, utils_lines)
    print(f"utils.rs: {len(utils_lines)} lines")
    
    # Write tests.rs
    write_lines(tests_path, test_lines)
    print(f"tests.rs: {len(test_lines)} lines")
    
    print("\nDone! Now update mod.rs to include tests module.")

if __name__ == '__main__':
    main()
