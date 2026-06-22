#!/usr/bin/env python3
"""
Migrate remaining test files from Testing (@Test) to XCTest (XCTestCase).
Handles: @Test removal, Issue.record -> XCTFail, wrapping in XCTestCase,
function renaming to testXxx format.
"""
import re
import os

BASE = "/Users/yoming/RenJistroly"

FILES = [
    # SecurityTests - already processed by previous run, kept for reference
    "Tests/SecurityTests/DataExfilTests.swift",
    "Tests/SecurityTests/RedTeamPlan.swift",
    "Tests/SecurityTests/SessionHijackTests.swift",
    "Tests/SecurityTests/ToolInjectionTests.swift",
    "Tests/LongRunningTests/LongevityPlan.swift",
    "Tests/LongRunningTests/StateMachineStressTests.swift",
    # Remaining files with @Test but no import Testing (text was removed, @Test not)
    "Tests/RenJistrolyIntelligenceTests/ProviderStabilityTests.swift",
    "Tests/RenJistrolyIntelligenceTests/VoiceInputStabilityTests.swift",
    "Tests/RenJistrolyCapabilityTests/ScreenUnderstandingTests.swift",
    "Tests/RenJistrolyConversationTests/ResponseExperienceTests.swift",
    # Suite-based @Test that needs structural XCTestCase migration
    "Tests/RenJistrolyModelsTests/BusinessScenarioModelsTests.swift",
    # Files with Issue.record remaining
    "Tests/RenJistrolyIntelligenceTests/PlanGeneratorTests.swift",
    "Tests/RenJistrolyIntelligenceTests/CommandParserTests.swift",
    "Tests/RenJistrolySystemBridgeTests/ActionPolicyTests.swift",
]

def class_name(filepath):
    """Derive class name from filename."""
    return os.path.basename(filepath).replace(".swift", "")

def first_func_test_line(lines):
    """Find the index of the first func test... line."""
    for i, line in enumerate(lines):
        if re.match(r'^\s*func\s+test', line):
            return i
    return -1

def last_func_test_line(lines):
    """Find the index of the last func test... line."""
    idx = -1
    for i, line in enumerate(lines):
        if re.match(r'^\s*func\s+test', line):
            idx = i
    return idx

def find_class_close(lines, last_func_idx):
    """
    Find where to close the XCTestCase class.
    Returns the index BEFORE which to insert the closing brace.
    """
    # Default: close at end of file
    close_idx = len(lines)

    # Look for top-level code after the last test function
    # (mock implementations, extensions, etc.)
    # Condition: starts at column 0, not blank, not comment, not import
    for i in range(last_func_idx + 1, len(lines)):
        line = lines[i]
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*'):
            continue
        if stripped.startswith('#') or stripped.startswith('import') or stripped.startswith('@testable'):
            continue
        # If this line starts at column 0 and isn't an empty/comment, it's top-level code
        if not line.startswith(' ') and not line.startswith('\t'):
            close_idx = i
            break

    return close_idx

def preprocess_suite(text):
    """Preprocess @Suite-based files to remove @Suite, struct wrappers, and orphaned braces."""
    # Remove @Suite lines
    text = re.sub(r'^[ \t]*@Suite[^\n]*\n', '', text, flags=re.MULTILINE)
    # Remove struct wrapper lines (e.g., "struct FooTests {")
    text = re.sub(r'^[ \t]*struct \w+Tests \{\n', '', text, flags=re.MULTILINE)
    # Remove orphaned top-level closing braces (struct closers that remain)
    text = re.sub(r'^\}\n', '', text, flags=re.MULTILINE)
    return text


def process_file(filepath):
    """Process a single file."""
    cn = class_name(filepath)
    full_path = os.path.join(BASE, filepath)

    with open(full_path, 'r') as f:
        text = f.read()

    original_len = len(text)

    # Step 0: Preprocess @Suite-based files
    text = preprocess_suite(text)

    # Step 1: Remove @Test lines (handles @Test("..."), @Test(.tags(...)), @Test @MainActor etc.)
    text = re.sub(r'^[ \t]*@Test[^\n]*\n?', '', text, flags=re.MULTILINE)

    # Step 2a: Remove @MainActor @Test combined on same line before func
    text = re.sub(r'^[ \t]*@MainActor\s+@Test\s+', '', text, flags=re.MULTILINE)

    # Step 2b: Remove @MainActor lines that appear alone before a func
    text = re.sub(r'^[ \t]*@MainActor\n(?=[ \t]*func\s)', '', text, flags=re.MULTILINE)

    # Step 3: Replace Issue.record with XCTFail
    text = text.replace('Issue.record(', 'XCTFail(')

    # Step 4: Replace #require with try XCTUnwrap
    text = text.replace('#require(', 'try XCTUnwrap(')

    # Step 5: Prepend "test" to top-level function names (if not already)
    # Capitalize the first letter: func foo() -> func testFoo()
    text = re.sub(
        r'^(\s*func\s+)(?!test)([a-z])(\w*)',
        lambda m: m.group(1) + 'test' + m.group(2).upper() + m.group(3),
        text,
        flags=re.MULTILINE
    )

    # Step 6: Wrap in class
    lines = text.split('\n')

    first_func = first_func_test_line(lines)
    last_func = last_func_test_line(lines)

    if first_func == -1:
        print(f"  SKIP: no test functions found in {filepath}")
        with open(full_path, 'w') as f:
            f.write(text)
        return

    close_idx = find_class_close(lines, last_func)

    # Build the result
    result = []

    # Lines before first test function (imports, types, comments) - unchanged
    for i in range(0, first_func):
        result.append(lines[i])

    # Class opening
    if result and result[-1] != '':
        result.append('')
    result.append(f'final class {cn}: XCTestCase {{')

    # Test functions (with +4 indent)
    for i in range(first_func, close_idx):
        stripped = lines[i]
        if stripped.strip():
            result.append('    ' + stripped)
        else:
            result.append('')

    # Class closing
    result.append('}')

    # Content after class (e.g., mock implementations) - unchanged
    if close_idx < len(lines):
        result.append('')
        for i in range(close_idx, len(lines)):
            result.append(lines[i])

    new_text = '\n'.join(result)

    with open(full_path, 'w') as f:
        f.write(new_text)

    removed_tests = original_len - len(text)  # approximate
    func_count = last_func - first_func + 1
    print(f"  {cn}: wrapped {func_count} funcs, close at line {close_idx}")

def main():
    for fp in FILES:
        full = os.path.join(BASE, fp)
        if not os.path.exists(full):
            print(f"  MISSING: {fp}")
            continue
        print(f"Processing: {fp}")
        process_file(fp)
    print("Done.")

if __name__ == "__main__":
    main()
