#!/usr/bin/env python3
"""Add Swift files to Xcode project targets via python-pbxproj.

Usage:
    python3 scripts/add_file_to_project.py Sources/Views/NewView.swift
    python3 scripts/add_file_to_project.py Sources/A.swift Sources/B.swift --target FocusBloxTests
    python3 scripts/add_file_to_project.py Sources/Mac/View.swift --target FocusBloxMac

WARNING (Bug #182): python-pbxproj erzeugt Quoted IDs statt Hex-IDs.
Nach jedem Aufruf: ./scripts/sim.sh build ausführen und auf
"Skipping duplicate build file"-Warnings prüfen!
"""
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Add files to Xcode project")
    parser.add_argument("files", nargs="+", help="Swift files to add")
    parser.add_argument("--target", default="FocusBlox", help="Target name (default: FocusBlox)")
    parser.add_argument("--project", default="FocusBlox.xcodeproj/project.pbxproj",
                        help="Path to project.pbxproj")
    args = parser.parse_args()

    try:
        from pbxproj import XcodeProject
    except ImportError:
        print("ERROR: python-pbxproj not installed. Run: pip3 install pbxproj", file=sys.stderr)
        sys.exit(1)

    proj = XcodeProject.load(args.project)
    for f in args.files:
        proj.add_file(f, target_name=args.target)
        print(f"Added: {f} -> {args.target}")
    proj.save()
    print(f"\nSaved. Run './scripts/sim.sh build' to verify (check for duplicate warnings).")

if __name__ == "__main__":
    main()
