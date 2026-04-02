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


def _patch_pbxproj_for_quoted_ids():
    """Monkey-patch python-pbxproj to handle non-standard (quoted) build phase IDs.

    Some build phase IDs in this project use non-hex names like 'RESRC001BUILDPHASE001'
    which are stored with single-quotes in the pbxproj file. The library fails to
    resolve these IDs, returning None and then crashing on .isa access.

    This patch makes get_or_create_build_phase skip unresolvable build phases.
    """
    from pbxproj.pbxsections.PBXGenericTarget import PBXGenericTarget

    def get_or_create_build_phase_safe(self, build_phase_type, search_parameters=None, create_parameters=()):
        result = []
        parent = self.get_parent()
        search_parameters = search_parameters if search_parameters is not None else {}

        if build_phase_type is None:
            return result

        for build_phase_id in self.buildPhases:
            target_build_phase = parent[build_phase_id]
            if target_build_phase is None:
                continue
            current_build_phase = target_build_phase.isa

            if current_build_phase == build_phase_type and \
                    all(key in target_build_phase and target_build_phase[key] == search_parameters[key]
                        for key in search_parameters):
                result.append(target_build_phase)

        if len(result) == 0:
            build_phase = self._get_class_reference(build_phase_type).create(*create_parameters)
            parent[build_phase.get_id()] = build_phase
            self.add_build_phase(build_phase)
            result.append(build_phase)

        return result

    PBXGenericTarget.get_or_create_build_phase = get_or_create_build_phase_safe


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

    _patch_pbxproj_for_quoted_ids()

    proj = XcodeProject.load(args.project)
    for f in args.files:
        proj.add_file(f, target_name=args.target)
        print(f"Added: {f} -> {args.target}")
    proj.save()
    print(f"\nSaved. Run './scripts/sim.sh build' to verify (check for duplicate warnings).")


if __name__ == "__main__":
    main()
