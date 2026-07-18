#!/usr/bin/env python3
"""Tests for tools/inline_bpatchers.py. Run: python3 tests/test_inline.py"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

from inline_bpatchers import inline  # noqa: E402

FIX = os.path.join(HERE, "fixtures", "inline")


def _load(name):
    with open(os.path.join(FIX, name)) as f:
        return json.load(f)["patcher"]


def test_inline_embeds_and_recurses():
    patcher = inline(_load("outer.maxpat"), [FIX])
    box = patcher["boxes"][0]["box"]
    assert box.get("embed") == 1, f"outer bpatcher not embedded: {box}"
    assert "name" not in box, "file reference should be removed after embedding"
    assert "patcher" in box, "embedded patcher content missing"
    nested = box["patcher"]["boxes"][0]["box"]
    assert nested.get("embed") == 1, f"nested bpatcher not embedded: {nested}"
    assert nested["patcher"]["boxes"][0]["box"]["text"] == "leaf"


def test_inline_missing_reference_raises():
    patcher = {"boxes": [{"box": {"maxclass": "bpatcher", "name": "nope.maxpat"}}]}
    try:
        inline(patcher, [FIX])
    except FileNotFoundError as e:
        assert "nope.maxpat" in str(e)
    else:
        raise AssertionError("expected FileNotFoundError for missing reference")


if __name__ == "__main__":
    fails = 0
    for name, fn in sorted(globals().items()):
        if name.startswith("test_") and callable(fn):
            try:
                fn()
                print(f"PASS {name}")
            except AssertionError as e:
                print(f"FAIL {name}: {e}")
                fails += 1
    sys.exit(1 if fails else 0)
