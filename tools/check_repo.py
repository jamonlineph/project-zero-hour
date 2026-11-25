#!/usr/bin/env python3
"""Repository checks that keep the project legally clean and tidy.

1. Banned file types: archives and formats used by other games' data files
   must never be committed (see docs/06-legal-and-licensing.md).
2. Asset provenance: every file under game/assets/ (except Godot's .import
   sidecars and the manifest itself) needs a row in ASSET_MANIFEST.csv with an
   author, a source and an allowed license; every row must point to a file.
3. Size: no single file over 20 MB (keep the repo cloneable by every tool).

Exit code 0 = clean, 1 = problems found. Uses only the standard library.
"""

import csv
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(REPO, "game", "assets")
MANIFEST = os.path.join(REPO, "ASSET_MANIFEST.csv")
ALLOWED_LICENSES = {"CC-BY-SA-4.0", "CC-BY-4.0", "CC0-1.0", "OFL-1.1"}
BANNED_EXTENSIONS = {".big", ".w3d", ".wnd", ".csf", ".bik", ".scb", ".map", ".str", ".ini.big"}
SKIP_DIRS = {".git", ".godot", "build", "__pycache__", "export"}
MAX_BYTES = 20 * 1024 * 1024
ASSET_SKIP_SUFFIXES = (".import", ".md")


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            yield os.path.join(dirpath, name)


def rel(path):
    return os.path.relpath(path, REPO).replace(os.sep, "/")


def main():
    problems = []

    for path in walk(REPO):
        lower = path.lower()
        if any(lower.endswith(ext) for ext in BANNED_EXTENSIONS):
            problems.append("banned file type: %s" % rel(path))
        if os.path.getsize(path) > MAX_BYTES:
            problems.append("file over 20 MB: %s" % rel(path))

    rows = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            for line_no, row in enumerate(csv.DictReader(f), start=2):
                path = (row.get("path") or "").strip()
                if not path:
                    problems.append("ASSET_MANIFEST.csv line %d: empty path" % line_no)
                    continue
                rows[path] = row
                for field in ("author", "source", "license"):
                    if not (row.get(field) or "").strip():
                        problems.append("ASSET_MANIFEST.csv: %s has no %s" % (path, field))
                lic = (row.get("license") or "").strip()
                if lic and lic not in ALLOWED_LICENSES:
                    problems.append("ASSET_MANIFEST.csv: %s has license %s (allowed: %s)"
                                    % (path, lic, ", ".join(sorted(ALLOWED_LICENSES))))
                if not os.path.exists(os.path.join(REPO, path)):
                    problems.append("ASSET_MANIFEST.csv: %s does not exist" % path)
    else:
        problems.append("missing ASSET_MANIFEST.csv")

    if os.path.isdir(ASSETS):
        for path in walk(ASSETS):
            r = rel(path)
            if path == MANIFEST or r.endswith(ASSET_SKIP_SUFFIXES):
                continue
            if r not in rows:
                problems.append("asset without a manifest row: %s" % r)

    if problems:
        print("check_repo: %d problem(s)" % len(problems))
        for p in problems:
            print("  - " + p)
        return 1
    print("check_repo: ok (%d assets in manifest)" % len(rows))
    return 0


if __name__ == "__main__":
    sys.exit(main())
