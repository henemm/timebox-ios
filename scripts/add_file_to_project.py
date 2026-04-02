#!/usr/bin/env python3
"""Add Swift files to Xcode project targets via direct string manipulation.

Usage:
    python3 scripts/add_file_to_project.py Sources/Views/NewView.swift
    python3 scripts/add_file_to_project.py Sources/A.swift Sources/B.swift --target FocusBloxTests
    python3 scripts/add_file_to_project.py Sources/Mac/View.swift --target FocusBloxMac

This script does NOT use python-pbxproj (which corrupts quoted IDs on save).
Instead it inserts entries directly into the pbxproj text file.
"""
import argparse
import hashlib
import os
import re
import sys

# Map target names to their PBXSourcesBuildPhase IDs
TARGET_BUILD_PHASE_IDS = {
    "FocusBlox": "2F0E2791A1F8F8F4C7109EED",
    "FocusBloxTests": "A1737C952E1F43597069B507",
    "FocusBloxUITests": "8FA0CF4C10B9AFD1392EB1C2",
    "FocusBloxMac": "B7DFC0692F2E8C60009C2881",
    "FocusBloxMacTests": "B7DFC0752F2E8C62009C2881",
    "FocusBloxMacUITests": "B7DFC07F2F2E8C62009C2881",
    "FocusBloxWatch Watch App": "B7DFC02F2F2E73EC009C2881",
}

# Map directory paths to their PBXGroup IDs
GROUP_IDS = {
    "Sources/Models": "73F58232703F62346B160001",
    "Sources/Views": "7613DF2BEF00711C6BDA68E3",
    "Sources/Services": "E8F581D4C161751425D7F776",
    "Sources/Helpers": "33F9E5347869F6F66DB9DD76",
    "Sources/Protocols": "72FD978B8372B20FAF9E6C5C",
    "Sources/Extensions": "CLRHEX01GROUP00001",
    "Sources/Intents": "INTENT00GROUP00001",
    "Sources/Layouts": "LAYOUTS01GROUP0001",
    "Sources/Views/Components": "SETCMP01GROUP00001",
    "Sources/Views/TaskCreation": "2B26CA0F59E37BB96B2D50E3",
    "Sources/Testing": "2FB93EDD424437965784E8F2",
    "Sources/ViewModels": "C39B415EA314A8CBCB3038F5",
    "Sources": "A4C4EBF78590D9165A0AA710",
    "FocusBloxUITests": "05D90FB2A2CE48689EC309B4",
    "FocusBloxTests": "A6B3805EF19D1B131D346DDD",
    "FocusBloxMac": "B7DFC0602F2E8C60009C2881",
}


def generate_id(filepath, suffix):
    """Generate a deterministic 24-char hex ID from filepath + suffix."""
    h = hashlib.md5(f"{filepath}:{suffix}".encode()).hexdigest().upper()
    return h[:24]


def find_group_id(filepath):
    """Find the PBXGroup ID for a file's directory."""
    dirpath = os.path.dirname(filepath)
    # Try exact match first, then parent directories
    while dirpath:
        if dirpath in GROUP_IDS:
            return GROUP_IDS[dirpath]
        dirpath = os.path.dirname(dirpath)
    return None


def add_file_to_project(pbxproj_content, filepath, target_name):
    """Add a single file to the pbxproj content. Returns modified content."""
    filename = os.path.basename(filepath)

    # Check if file is already referenced
    if filepath in pbxproj_content:
        print(f"  SKIP: {filepath} already in project")
        return pbxproj_content

    # Generate IDs
    file_ref_id = generate_id(filepath, "fileref")
    build_file_id = generate_id(filepath, "buildfile")

    # 1. Add PBXBuildFile entry (after "/* Begin PBXBuildFile section */")
    build_file_line = f'\t\t{build_file_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};\n'
    pbxproj_content = pbxproj_content.replace(
        "/* Begin PBXBuildFile section */\n",
        f"/* Begin PBXBuildFile section */\n{build_file_line}",
    )

    # 2. Add PBXFileReference entry (after "/* Begin PBXFileReference section */")
    file_ref_line = f'\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {filename}; path = {filepath}; sourceTree = SOURCE_ROOT; }};\n'
    pbxproj_content = pbxproj_content.replace(
        "/* Begin PBXFileReference section */\n",
        f"/* Begin PBXFileReference section */\n{file_ref_line}",
    )

    # 3. Add to PBXSourcesBuildPhase files list
    build_phase_id = TARGET_BUILD_PHASE_IDS.get(target_name)
    if not build_phase_id:
        print(f"  ERROR: Unknown target '{target_name}'", file=sys.stderr)
        print(f"  Known targets: {', '.join(TARGET_BUILD_PHASE_IDS.keys())}", file=sys.stderr)
        sys.exit(1)

    # Find "BUILD_PHASE_ID /* Sources */ = {" and insert into its files list
    pattern = f"{build_phase_id} /\\* Sources \\*/ = {{\\s*\n\\s*isa = PBXSourcesBuildPhase;\\s*\n\\s*buildActionMask = \\d+;\\s*\n\\s*files = \\(\n"
    match = re.search(pattern, pbxproj_content)
    if match:
        insert_pos = match.end()
        build_ref_line = f"\t\t\t\t{build_file_id} /* {filename} in Sources */,\n"
        pbxproj_content = pbxproj_content[:insert_pos] + build_ref_line + pbxproj_content[insert_pos:]
    else:
        print(f"  ERROR: Could not find PBXSourcesBuildPhase for {target_name} ({build_phase_id})", file=sys.stderr)
        sys.exit(1)

    # 4. Add to PBXGroup children list
    group_id = find_group_id(filepath)
    if group_id:
        # Match the group DEFINITION (with "= {" and "isa = PBXGroup"), not references
        group_pattern = f"{re.escape(group_id)}[^=]*= {{\\s*\n\\s*isa = PBXGroup;\\s*\n\\s*children = \\(\n"
        match = re.search(group_pattern, pbxproj_content)
        if match:
            insert_pos = match.end()
            group_ref_line = f"\t\t\t\t{file_ref_id} /* {filename} */,\n"
            pbxproj_content = pbxproj_content[:insert_pos] + group_ref_line + pbxproj_content[insert_pos:]
        else:
            print(f"  WARNING: Could not find PBXGroup {group_id} for {filepath}")
    else:
        print(f"  WARNING: No PBXGroup mapping for directory of {filepath}")

    print(f"  Added: {filepath} -> {target_name}")
    print(f"    FileRef: {file_ref_id}")
    print(f"    BuildFile: {build_file_id}")
    return pbxproj_content


def main():
    parser = argparse.ArgumentParser(description="Add files to Xcode project")
    parser.add_argument("files", nargs="+", help="Swift files to add")
    parser.add_argument("--target", default="FocusBlox", help="Target name (default: FocusBlox)")
    parser.add_argument("--project", default="FocusBlox.xcodeproj/project.pbxproj",
                        help="Path to project.pbxproj")
    parser.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    args = parser.parse_args()

    if not os.path.exists(args.project):
        print(f"ERROR: {args.project} not found", file=sys.stderr)
        sys.exit(1)

    with open(args.project, "r") as f:
        content = f.read()

    original = content
    for filepath in args.files:
        if not os.path.exists(filepath):
            print(f"WARNING: {filepath} does not exist on disk (adding anyway)")
        content = add_file_to_project(content, filepath, args.target)

    if content == original:
        print("\nNo changes needed.")
        return

    if args.dry_run:
        print("\n[DRY RUN] Would save changes. Run without --dry-run to apply.")
        return

    with open(args.project, "w") as f:
        f.write(content)

    print(f"\nSaved. Run './scripts/sim.sh build' to verify.")


if __name__ == "__main__":
    main()
