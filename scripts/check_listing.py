#!/usr/bin/env python3
"""Check docs/APP_STORE_LISTING.md fields against App Store Connect's limits:
each field's length, and that it uses only characters App Store Connect takes."""
import re, sys, pathlib, unicodedata
LIMITS = {"Name": 30, "Subtitle": 30, "Promotional Text": 170, "Keywords": 100,
          "Description": 4000, "What's New in This Version": 4000}
# App Store Connect refuses some characters and doesn't publish which: 1.3.0's
# What's New was refused for ␀ and ␛ (Control Pictures). So besides printable
# ASCII and the letters, marks and digits of any script, only symbols it has
# already taken are allowed. Add one here only after App Store Connect has
# accepted it; describe anything else in words.
ACCEPTED_SYMBOLS = set("·—•⇧⌘▸、。「」・")
# Presentation forms are letters, but App Store Connect has refused them (an
# Arabic one, U+FBFD, in What's New), so they don't count as letters here.
PRESENTATION_FORMS = ((0xFB00, 0xFDFF), (0xFE70, 0xFEFF))

def refused(ch):
    if ch == "\n" or " " <= ch <= "~" or ch in ACCEPTED_SYMBOLS:
        return False
    if any(lo <= ord(ch) <= hi for lo, hi in PRESENTATION_FORMS):
        return True
    category = unicodedata.category(ch)
    return not (category[0] in "LM" or category == "Nd")

text = pathlib.Path(__file__).resolve().parent.parent.joinpath("docs/APP_STORE_LISTING.md").read_text()
locale = "?"
bad = 0
for m in re.finditer(r"^## ([^\n]+)$|^\*\*(.+?)\*\*\n```\n(.*?)\n```", text, re.M | re.S):
    if m.group(1):
        locale = m.group(1).split(" — ")[0]; continue
    field, body = m.group(2), m.group(3)
    if field not in LIMITS: continue
    n, lim = len(body), LIMITS[field]
    ok = n <= lim; bad += not ok
    print(f"{'OK  ' if ok else 'OVER'} {n:>5}/{lim:<5} {locale:20} {field}")
    for ch in sorted(set(filter(refused, body))):
        bad += 1
        print(f"CHAR {'':11} {locale:20} {field}: U+{ord(ch):04X} {unicodedata.name(ch, 'unnamed')}")
sys.exit(1 if bad else 0)
