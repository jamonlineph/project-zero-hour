#!/usr/bin/env python3
"""Merges a language's translation table (tools/i18n/<code>.py) with the
template game/locale/messages.pot into game/locale/<code>.po (P3-18).
Texts missing from the table stay untranslated (the game shows English).

Usage: python3 tools/i18n/build_po.py es [--check]
"""
import importlib.util
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
POT = os.path.join(ROOT, "game", "locale", "messages.pot")
HEADER = 'msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: %s\\n"\n'


def build(code):
    spec = importlib.util.spec_from_file_location("t_" + code, os.path.join(os.path.dirname(os.path.abspath(__file__)), code + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    table = mod.T
    pot = open(POT, encoding="utf-8").read()
    out = ["# Project Zero Hour, language: %s. Built by tools/i18n/build_po.py from" % code,
           "# tools/i18n/%s.py and the template; edit the table, not this file." % code, HEADER % code]
    done = 0
    for refs, msgid in re.findall(r'#: (.*)\nmsgid "(.*)"\nmsgstr ""', pot):
        if msgid in table:
            done += 1
            out.append('#: %s\nmsgid "%s"\nmsgstr "%s"\n' % (refs, msgid, table[msgid].replace('"', '\\"')))
    return "\n".join(out), done


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    code = argv[1]
    path = os.path.join(ROOT, "game", "locale", code + ".po")
    text, done = build(code)
    if "--check" in argv:
        if (open(path, encoding="utf-8").read() if os.path.exists(path) else "") != text:
            print("game/locale/%s.po is out of date: run python3 tools/i18n/build_po.py %s" % (code, code))
            return 1
        return 0
    open(path, "w", encoding="utf-8").write(text)
    print("wrote game/locale/%s.po (%d translated)" % (code, done))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
