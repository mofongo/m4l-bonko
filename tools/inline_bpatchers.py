#!/usr/bin/env python3
"""Recursively embed bpatcher file references into a patcher dict.

Max resolves `bpatcher @name foo.maxpat` against the loading patcher's own
folder and the global search path only — never subfolders. Embedding the
referenced patcher content (embed: 1) at build time makes the resulting
device self-contained, so it loads from any location without search-path
setup.

Used by make_amxd.py; importable for tests.
"""
import json
import os


def inline(patcher, search_dirs):
    """Embed every file-referencing bpatcher in `patcher`, recursively.

    Mutates and returns `patcher`. Raises FileNotFoundError if a referenced
    file cannot be resolved in `search_dirs`.
    """
    for entry in patcher.get("boxes", []):
        box = entry.get("box", {})
        if box.get("maxclass") == "bpatcher" and "name" in box and "patcher" not in box:
            name = box["name"]
            path = _resolve(name, search_dirs)
            if path is None:
                raise FileNotFoundError(
                    f"bpatcher reference not found: {name} (searched {search_dirs})"
                )
            with open(path) as f:
                sub = json.load(f)["patcher"]
            box["patcher"] = inline(sub, search_dirs)
            box["embed"] = 1
            del box["name"]
        elif "patcher" in box:
            inline(box["patcher"], search_dirs)
    return patcher


def _resolve(name, search_dirs):
    for d in search_dirs:
        p = os.path.join(d, name)
        if os.path.isfile(p):
            return p
    return None
