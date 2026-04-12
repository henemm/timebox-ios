#!/usr/bin/env python3
"""Remove Swift files from Xcode project by filtering out their references.

Usage:
    python3 scripts/remove_file_from_project.py EmotionalNudgeService.swift SmartNudgeTests.swift

Removes all PBXBuildFile, PBXFileReference, and PBXGroup entries that reference
the given filenames (matched by basename, not full path).
"""
import argparse
import os
import sys


def main():
    parser = argparse.ArgumentParser(description="Remove files from Xcode project")
    parser.add_argument("filenames", nargs="+", help="Filenames to remove (basename only)")
    parser.add_argument("--project", default=None, help="Path to .xcodeproj directory")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be removed")
    args = parser.parse_args()

    # Find project file
    if args.project:
        pbxproj = os.path.join(args.project, "project.pbxproj")
    else:
        # Auto-detect
        for name in os.listdir("."):
            if name.endswith(".xcodeproj"):
                pbxproj = os.path.join(name, "project.pbxproj")
                break
        else:
            print("ERROR: No .xcodeproj found", file=sys.stderr)
            sys.exit(1)

    with open(pbxproj, "r") as f:
        lines = f.readlines()

    # Build set of basenames to remove
    basenames = set(args.filenames)

    filtered = []
    removed = 0
    for line in lines:
        skip = False
        for bn in basenames:
            if bn in line:
                skip = True
                removed += 1
                if args.dry_run:
                    print(f"  REMOVE: {line.rstrip()}")
                break
        if not skip:
            filtered.append(line)

    if args.dry_run:
        print(f"\nWould remove {removed} lines from {pbxproj}")
        return

    with open(pbxproj, "w") as f:
        f.writelines(filtered)

    print(f"Removed {removed} lines referencing {', '.join(sorted(basenames))} from {pbxproj}")


if __name__ == "__main__":
    main()
