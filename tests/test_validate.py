#!/usr/bin/env python3
"""Tests for tools/validate_patch.py. Run: python3 tests/test_validate.py"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))

from validate_patch import validate  # noqa: E402

FIX = os.path.join(HERE, "fixtures")


def test_good_fixture_passes():
    errs = validate(os.path.join(FIX, "minimal_good.maxpat"))
    assert errs == [], f"expected no errors, got: {errs}"


def test_broken_line_fails():
    errs = validate(os.path.join(FIX, "broken_line.maxpat"))
    assert any("missing box" in e for e in errs), f"expected missing-box error, got: {errs}"


def test_duplicate_param_longname_fails():
    # broken_line.maxpat also contains two live.dials sharing longname "Dup"
    errs = validate(os.path.join(FIX, "broken_line.maxpat"))
    assert any("duplicate parameter_longname" in e for e in errs), f"got: {errs}"


def test_embedded_bpatcher_longnames_are_separate_scopes():
    # Two embedded copies of the same abstraction share longnames legally
    # (Max auto-renames per instance at load) — must NOT be flagged.
    errs = validate(os.path.join(FIX, "embedded_dup_ok.maxpat"))
    assert errs == [], f"expected no errors, got: {errs}"


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
