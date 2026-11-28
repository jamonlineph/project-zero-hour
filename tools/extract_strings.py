#!/usr/bin/env python3
"""Builds game/locale/messages.pot, the template translators work from (P3-18).

The English text is the message id (gettext). Collected:
- from the UI scripts (game/src/ui, game/src/main): Loc.t("...") texts and
  the string literals on lines that set what the player sees (.text =,
  tooltip_text =, _button(...), _cycle(...), _header(...), "label": and
  "tooltip": entries, open_game_over(...));
- from game/data: names and descriptions of units, buildings, upgrades and
  powers; map names; AI personality names and descriptions; Gauntlet
  intros; faction names from MatchConfig; difficulty names.

Usage: python3 tools/extract_strings.py          writes the template
       python3 tools/extract_strings.py --check  fails if it is out of date
New translations: copy messages.pot to game/locale/<code>.po, translate,
and list it in Loc.LANGUAGES and project.godot (docs/localization.md).
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "game", "locale", "messages.pot")
UI_GLOBS = ["game/src/ui/*.gd", "game/src/main/*.gd"]
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
LOC_CALL = re.compile(r'Loc\.t\("((?:[^"\\\n]|\\.)*)"\)')
# Where shown text starts on a line: after these, up to a ".name =" (node
# names aren't shown) or the end of the line.
SHOWN = re.compile(r'\.text = |tooltip_text = |placeholder_text = |_cycle\(|_header\(|"label": |"tooltip": |open_game_over\(')
BUTTON = re.compile(r'_button\([^,()]+,\s*("(?:[^"\\\n]|\\.)*")')   # _button(parent, "Text", action)
SKIP_LINE = re.compile(r'find_child|get_node|has_node|begins_with|ends_with|DevCapture|push_error|print\(|fps \| state')


def _shown_parts(line):
    """The pieces of a script line that hold text the player sees."""
    if SKIP_LINE.search(line):
        return []
    parts = [m.group(1) for m in BUTTON.finditer(line)]
    m = SHOWN.search(line)
    if m:
        rest = line[m.end():]
        cut = rest.find(".name = ")
        parts.append(rest if cut < 0 else rest[:cut])
    return parts


def _escape(text):
    """A Python string as PO text (only for data strings: script literals are
    already escaped the same way)."""
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _from_scripts(found):
    for pattern in UI_GLOBS:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            for line in open(path, encoding="utf-8"):
                if line.lstrip().startswith("#"):
                    continue
                for m in LOC_CALL.finditer(line):
                    found.setdefault(m.group(1), set()).add(rel)
                for part in _shown_parts(line):
                    for m in LITERAL.finditer(part):
                        s = m.group(1)
                        if not re.search(r"[A-Za-z]{2,}", s) or "://" in s or re.fullmatch(r"[a-z_]+|[A-Za-z]+_%[sd]", s):
                            continue
                        found.setdefault(s, set()).add(rel)


def _add(found, text, where):
    if text and re.search(r"[A-Za-z]", text):
        found.setdefault(_escape(text), set()).add(where)


def _from_data(found):
    data = os.path.join(ROOT, "game", "data")
    with open(os.path.join(data, "index.json"), encoding="utf-8") as f:
        index = json.load(f)
    for key in ("units", "buildings", "upgrades", "powers", "maps"):
        for res in index.get(key, []):
            path = os.path.join(data, res.replace("res://data/", ""))
            with open(path, encoding="utf-8") as f:
                d = json.load(f)
            rel = "game/data/" + res.replace("res://data/", "")
            _add(found, d.get("name", ""), rel)
            if key != "maps":
                _add(found, d.get("description", ""), rel)
    pers = os.path.join(data, "ai", "personalities.json")
    with open(pers, encoding="utf-8") as f:
        for k, v in json.load(f).items():
            if isinstance(v, dict):
                _add(found, v.get("name", ""), "game/data/ai/personalities.json")
                _add(found, v.get("description", ""), "game/data/ai/personalities.json")
                _add(found, k.capitalize(), "game/data/ai/personalities.json")
    with open(os.path.join(data, "gauntlet.json"), encoding="utf-8") as f:
        for c in json.load(f).get("commanders", []):
            _add(found, c.get("intro", ""), "game/data/gauntlet.json")
    cfg = open(os.path.join(ROOT, "game", "src", "data", "match_config.gd"), encoding="utf-8").read()
    m = re.search(r"const FACTIONS: Dictionary = \{([^}]*)\}", cfg)
    if m:
        for name in re.findall(r':\s*"([^"]+)"', m.group(1)):
            _add(found, name, "game/src/data/match_config.gd")
    for level in ("Easy", "Normal", "Hard", "Random"):
        _add(found, level, "game/src/ui/main_menu.gd")


def build():
    found = {}
    _from_scripts(found)
    _from_data(found)
    lines = [
        "# Project Zero Hour: every text the player sees, in English (the message ids).",
        "# Generated by tools/extract_strings.py; don't edit by hand.",
        'msgid ""',
        'msgstr ""',
        '"Content-Type: text/plain; charset=UTF-8\\n"',
        "",
    ]
    for text in sorted(found):
        lines.append("#: " + " ".join(sorted(found[text])))
        lines.append('msgid "%s"' % text)
        lines.append('msgstr ""')
        lines.append("")
    return "\n".join(lines)


def main(argv):
    text = build()
    if "--check" in argv:
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if current != text:
            print("game/locale/messages.pot is out of date: run python3 tools/extract_strings.py")
            return 1
        print("extract_strings: up to date (%d texts)" % text.count("\nmsgid ") )
        return 0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote %s (%d texts)" % (os.path.relpath(OUT, ROOT), text.count("\nmsgid ") - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
