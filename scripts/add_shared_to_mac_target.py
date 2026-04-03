#!/usr/bin/env python3
"""Add an existing shared Sources/ file to the FocusBloxMac target.

Usage:
    python3 scripts/add_shared_to_mac_target.py COACH001FILEREF01 CoachView.swift COACH001MACBLD01

This handles the case where a file is already in the iOS target but needs
to be added to the macOS target as well.
"""
import re
import sys

def main():
    if len(sys.argv) != 4:
        print("Usage: add_shared_to_mac_target.py <existing_fileref_id> <filename> <new_buildfile_id>")
        sys.exit(1)

    fileref_id = sys.argv[1]
    filename = sys.argv[2]
    new_bf_id = sys.argv[3]

    pbxproj = "FocusBlox.xcodeproj/project.pbxproj"
    with open(pbxproj, "r") as f:
        content = f.read()

    # Check if already added
    if new_bf_id in content:
        print(f"SKIP: {new_bf_id} already exists in project")
        return

    # 1. Add PBXBuildFile entry after Begin PBXBuildFile section
    bf_line = f"\t\t{new_bf_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref_id} /* {filename} */; }};\n"
    content = content.replace(
        "/* Begin PBXBuildFile section */\n",
        f"/* Begin PBXBuildFile section */\n{bf_line}",
    )

    # 2. Insert into FocusBloxMac Sources build phase (B7DFC0692F2E8C60009C2881)
    mac_sources_pattern = r"(B7DFC0692F2E8C60009C2881 /\* Sources \*/ = \{\s*\n\s*isa = PBXSourcesBuildPhase;\s*\n\s*buildActionMask = \d+;\s*\n\s*files = \(\n)"
    match = re.search(mac_sources_pattern, content)
    if match:
        insert_pos = match.end()
        ref_line = f"\t\t\t\t{new_bf_id} /* {filename} in Sources */,\n"
        content = content[:insert_pos] + ref_line + content[insert_pos:]
        print(f"Added {filename} to FocusBloxMac Sources phase")
    else:
        print("ERROR: Could not find FocusBloxMac Sources build phase")
        sys.exit(1)

    with open(pbxproj, "w") as f:
        f.write(content)
    print("Saved.")

if __name__ == "__main__":
    main()
