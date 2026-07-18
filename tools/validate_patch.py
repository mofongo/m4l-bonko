#!/usr/bin/env python3
"""Structural validator for Max .maxpat/.maxhelp JSON files.

Checks: valid JSON, top-level 'patcher' key, unique box ids, patchlines
referencing existing boxes, patching_rect on every box, and unique
parameter_longname per file. Recurses into embedded subpatchers.

Usage: python3 tools/validate_patch.py file.maxpat [more.maxpat ...]
Exit 0 if all valid, 1 otherwise.
"""
import json
import sys


def validate(path):
    errors = []
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        return [f"{path}: unreadable or invalid JSON: {e}"]
    patcher = data.get("patcher")
    if patcher is None:
        return [f"{path}: no top-level 'patcher' key"]
    longnames = []
    _check_patcher(patcher, path, errors, longnames)
    _flag_dupes(longnames, path, errors)
    return errors


def _flag_dupes(longnames, ctx, errors):
    dupes = sorted({n for n in longnames if longnames.count(n) > 1})
    if dupes:
        errors.append(f"{ctx}: duplicate parameter_longname(s): {dupes}")


def _check_patcher(patcher, ctx, errors, longnames):
    boxes = [b["box"] for b in patcher.get("boxes", []) if "box" in b]
    ids = [b.get("id") for b in boxes]
    dupes = sorted({i for i in ids if ids.count(i) > 1})
    if dupes:
        errors.append(f"{ctx}: duplicate box ids: {dupes}")
    idset = set(ids)
    for entry in patcher.get("lines", []):
        line = entry.get("patchline", {})
        for end in ("source", "destination"):
            ref = line.get(end)
            if not ref or ref[0] not in idset:
                errors.append(f"{ctx}: patchline {end} references missing box {ref}")
    for box in boxes:
        if "patching_rect" not in box:
            errors.append(f"{ctx}: box {box.get('id')} missing patching_rect")
        valueof = box.get("saved_attribute_attributes", {}).get("valueof", {})
        if "parameter_longname" in valueof:
            longnames.append(valueof["parameter_longname"])
        if box.get("maxclass", "").startswith("live.") and not box.get("parameter_enable"):
            errors.append(f"{ctx}: live.* box {box.get('id')} missing parameter_enable")
        sub = box.get("patcher")
        if sub:
            if box.get("maxclass") == "bpatcher":
                # An embedded bpatcher is its own parameter scope: Max
                # auto-renames longname conflicts across instances at load,
                # so duplicates between copies are legal. Duplicates within
                # one embedded patcher are still flagged.
                sub_names = []
                _check_patcher(sub, f"{ctx}/{box.get('id')}", errors, sub_names)
                _flag_dupes(sub_names, f"{ctx}/{box.get('id')}", errors)
            else:
                _check_patcher(sub, f"{ctx}/{box.get('id')}", errors, longnames)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    all_errors = []
    for p in sys.argv[1:]:
        all_errors.extend(validate(p))
    if all_errors:
        print("\n".join(all_errors))
        sys.exit(1)
    print(f"OK: {len(sys.argv) - 1} file(s) valid")
