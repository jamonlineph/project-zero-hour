#!/usr/bin/env python3
"""Balance spreadsheets <-> game data (P3-19).

Exports the numbers designers tune (units, weapons, buildings) to CSV files
that any spreadsheet program opens, and imports edited CSV files back into
the JSON files in game/data/. Only the columns below are touched; every
other field, and the key order, stays as it was. A file is only rewritten
when one of its values changed.

Usage (from the repo root):
  python3 tools/balance_sheet.py export [--out balance]   writes units.csv, weapons.csv, buildings.csv
  python3 tools/balance_sheet.py import balance/units.csv [more.csv ...] [--dry-run]
  python3 tools/balance_sheet.py self-test               round trip on a copy of game/data

After an import, run tools/run_tests.sh; changed numbers can change the
golden replays (tools/regen_golden_replays.sh, say why in the commit).
"""
import csv
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

# Sheet name -> (index.json key, columns). "id" is the key; lists are
# written joined with ";".
SHEETS = {
    "units": ("units", ["id", "faction", "name", "role", "armor_class", "cost", "max_hp", "speed_cm_per_s",
                        "build_time_ms", "vision_cm", "radius_cm", "weapons", "requires", "rearm_s",
                        "transport_capacity"]),
    "weapons": ("weapons", ["id", "damage", "damage_type", "range_cm", "min_range_cm", "reload_ms", "projectile",
                            "targets", "projectile_speed_cm_per_s", "splash_radius_cm", "stock", "restock_s", "ammo"]),
    "buildings": ("buildings", ["id", "faction", "name", "cost", "max_hp", "build_time_ms", "power", "vision_cm",
                                "requires", "produces", "limit", "requires_rank"]),
}
LIST_COLUMNS = {"weapons", "requires", "targets", "produces"}
# Columns written only when present in the file, so imports never add them.
OPTIONAL = {"role", "rearm_s", "transport_capacity", "min_range_cm", "projectile_speed_cm_per_s", "splash_radius_cm",
            "stock", "restock_s", "ammo", "limit", "requires_rank", "radius_cm", "vision_cm", "name", "faction"}


def _data_root(root):
    return os.path.join(root, "game", "data")


def _files(root, key):
    """id -> path of every data file listed under `key` in index.json."""
    data = _data_root(root)
    with open(os.path.join(data, "index.json"), encoding="utf-8") as f:
        index = json.load(f)
    out = {}
    for res in index.get(key, []):
        path = os.path.join(data, res.replace("res://data/", ""))
        out[os.path.splitext(os.path.basename(path))[0]] = path
    return out


def _cell(value):
    if isinstance(value, list):
        return ";".join(str(v) for v in value)
    if isinstance(value, bool):
        return "true" if value else "false"
    return "" if value is None else str(value)


def _parse(column, text, old):
    """The JSON value for a cell, typed like the value it replaces."""
    text = text.strip()
    if column in LIST_COLUMNS:
        return [t.strip() for t in text.split(";") if t.strip()]
    if isinstance(old, bool):
        return text.lower() in ("1", "true", "yes")
    if isinstance(old, int) or (old is None and text.lstrip("-").isdigit()):
        return int(float(text))
    if isinstance(old, float):
        return float(text)
    return text


def export(root, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for sheet, (key, columns) in SHEETS.items():
        path = os.path.join(out_dir, sheet + ".csv")
        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(columns)
            for item_id, file in sorted(_files(root, key).items()):
                with open(file, encoding="utf-8") as jf:
                    d = json.load(jf)
                w.writerow([_cell(d.get(c)) for c in columns])
        written.append(path)
    return written


def import_csv(root, csv_path, dry_run=False):
    """Applies one sheet. Returns a list of (file, column, old, new) changes."""
    sheet = os.path.splitext(os.path.basename(csv_path))[0]
    if sheet not in SHEETS:
        raise SystemExit("%s: the file name must be one of %s.csv" % (csv_path, ", ".join(SHEETS)))
    key, columns = SHEETS[sheet]
    files = _files(root, key)
    changes = []
    with open(csv_path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            item_id = (row.get("id") or "").strip()
            if item_id not in files:
                raise SystemExit("%s: unknown %s id '%s'" % (csv_path, sheet, item_id))
            path = files[item_id]
            with open(path, encoding="utf-8") as jf:
                d = json.load(jf)
            changed = False
            for c in columns:
                if c == "id" or c not in row:
                    continue
                text = row[c]
                if c not in d and (text.strip() == "" or c in OPTIONAL):
                    continue   # never add optional fields from a spreadsheet
                new = _parse(c, text, d.get(c))
                if d.get(c) != new:
                    changes.append((path, c, d.get(c), new))
                    d[c] = new
                    changed = True
            if changed and not dry_run:
                with open(path, "w", encoding="utf-8") as jf:
                    json.dump(d, jf, indent=2, ensure_ascii=False)
                    jf.write("\n")
    return changes


def self_test():
    """Round trip on a copy of game/data: an untouched export imports with no
    changes, and one edited cell changes exactly that value."""
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copytree(_data_root(ROOT), os.path.join(tmp, "game", "data"))
        sheets = export(tmp, os.path.join(tmp, "balance"))
        for s in sheets:
            ch = import_csv(tmp, s)
            if ch:
                raise SystemExit("self-test: re-importing an untouched %s changed %d values, e.g. %s" % (s, len(ch), ch[0]))
        units = os.path.join(tmp, "balance", "units.csv")
        with open(units, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        rows[0]["cost"] = str(int(rows[0]["cost"]) + 25)
        with open(units, "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=SHEETS["units"][1])
            w.writeheader()
            w.writerows(rows)
        ch = import_csv(tmp, units)
        if len(ch) != 1 or ch[0][1] != "cost" or ch[0][3] != ch[0][2] + 25:
            raise SystemExit("self-test: an edited cost imported as %s" % (ch,))
    print("balance_sheet: self-test ok")


def main(argv):
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd = argv[1]
    if cmd == "export":
        out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(ROOT, "balance")
        for p in export(ROOT, out):
            print("wrote", os.path.relpath(p, ROOT))
        return 0
    if cmd == "import":
        dry = "--dry-run" in argv
        paths = [a for a in argv[2:] if a != "--dry-run"]
        if not paths:
            raise SystemExit("import: give one or more CSV files")
        total = 0
        for p in paths:
            for file, col, old, new in import_csv(ROOT, p, dry):
                print("%s %s: %s -> %s" % (os.path.relpath(file, ROOT), col, old, new))
                total += 1
        print("%d value(s) %s" % (total, "would change (dry run)" if dry else "changed"))
        return 0
    if cmd == "self-test":
        self_test()
        return 0
    raise SystemExit("unknown command '%s' (export, import, self-test)" % cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
