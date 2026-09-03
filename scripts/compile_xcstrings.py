#!/usr/bin/env python3
"""Compiles String Catalogs (.xcstrings) into <lang>.lproj/<Table>.strings.

xcodebuild does this itself; this stand-in exists for scripts/smoke_bundle.sh,
which builds Tilde.app with plain swiftc on a machine that has only the
Command Line Tools. Output matches what Xcode emits closely enough for
Foundation to pick up: one .strings file per language, source-language
entries included so the development region has a table too.

Usage: compile_xcstrings.py <Resources dir> <catalog.xcstrings>...
"""
import json
import os
import sys


def escape(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    resources, catalogs = sys.argv[1], sys.argv[2:]
    for path in catalogs:
        table = os.path.splitext(os.path.basename(path))[0]
        with open(path, encoding="utf-8") as f:
            catalog = json.load(f)
        source = catalog["sourceLanguage"]
        per_lang = {}
        for key, entry in catalog["strings"].items():
            per_lang.setdefault(source, {})[key] = key
            for lang, loc in entry.get("localizations", {}).items():
                unit = loc.get("stringUnit", {})
                if unit.get("state") == "translated":
                    per_lang.setdefault(lang, {})[key] = unit["value"]
        for lang, pairs in per_lang.items():
            folder = os.path.join(resources, f"{lang}.lproj")
            os.makedirs(folder, exist_ok=True)
            with open(os.path.join(folder, f"{table}.strings"), "w", encoding="utf-8") as f:
                for key in sorted(pairs):
                    f.write(f'"{escape(key)}" = "{escape(pairs[key])}";\n')


if __name__ == "__main__":
    main()
