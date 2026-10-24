#!/usr/bin/env python3
"""Read-only Phase 1 tool check. No downloads, installs or gameplay claims."""
import argparse
import importlib
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable name or absolute path")
    args = parser.parse_args()
    failures = []

    def report(label, okay, detail):
        print(f"{'OK' if okay else 'NEEDED'} {label}: {detail}")
        if not okay:
            failures.append(label)

    report("Python", sys.version_info >= (3, 10), sys.version.split()[0] + " (minimum 3.10)")
    try:
        pillow = importlib.import_module("PIL")
        report("Pillow", True, pillow.__version__)
    except ImportError:
        report("Pillow", False, "install python-pillow on Arch")
    try:
        numpy = importlib.import_module("numpy")
        report("numpy", True, numpy.__version__ + " (audio synthesis)")
    except ImportError:
        report("numpy", False, "install python-numpy on Arch")
    report("Git", shutil.which("git") is not None, shutil.which("git") or "install git")
    godot = shutil.which(args.godot)
    if not godot:
        report("Godot", False, "4.7.2 standard not found; install godot or use --godot PATH")
    else:
        try:
            result = subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=10, check=False)
            version = result.stdout.strip()
            valid = result.returncode == 0 and version.startswith("4.7.2.") and "mono" not in version.lower()
            report("Godot", valid, version or "version probe failed; expected 4.7.2 standard")
        except (OSError, subprocess.TimeoutExpired) as exc:
            report("Godot", False, type(exc).__name__)
    print("Not checked: export templates, display, controllers, audio, GPU performance or gameplay.")
    print("Ready for Phase 1 authoring." if not failures else "Resolve prerequisites in docs/SETUP.md.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
