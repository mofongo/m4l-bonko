# Bonko Transient Trigger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Bonko Max for Live audio effect: a guitar-tuned transient detector driving 4 mappable parameter slots (probability gate + AD envelope + Map button via `live.remote~`), per the spec at `docs/superpowers/specs/2026-07-18-transient-trigger-design.md`.

**Architecture:** Modular bpatcher design — one detector abstraction, one map abstraction nested inside one slot abstraction (instantiated 4×), joined by a `---`-scoped named send ("trigger bus") inside a main device patch. All patcher files are authored as raw `.maxpat` JSON and validated by a Python structural validator; the final `.amxd` is produced by wrapping the main patcher JSON in the binary chunk header copied from a reference Ableton `.amxd`.

**Tech Stack:** Max/MSP 8.6+ patcher JSON (vanilla objects only), Max for Live / Live API (`live.remote~`, `live.observer`, `live.object`, `live.path`, `live.thisdevice`), Python 3 for tooling. The `maxmsp` MCP tools (`get_object_doc`, `list_all_objects`, etc.) are available for consulting live Max documentation and inspecting patches the user opens in Max.

## Global Constraints

- **Vanilla Max objects only** — no third-party externals (bonk~ explicitly rejected in spec). The frozen device must be fully self-contained.
- **Audio passthrough is bit-identical**: `plugin~` outlets connect directly to `plugout~` inlets; nothing else touches that path.
- **All send/receive names use the `---` prefix** (`s ---trig` / `r ---trig`) so multiple device instances in one Live set never crosstalk.
- **Every user control is a `live.*` object** with `parameter_enable: 1`, a `parameter_longname`, `parameter_shortname`, range, and initial value (automatable, saved with the set).
- **Parameter longnames must be unique within each patcher file.** Across the 4 slot bpatcher instances Max auto-renames conflicts (`Prob` → `Prob[1]` …) at load; this is expected.
- **Presentation rects:** every UI object has `"presentation": 1` and a `presentation_rect`; all patcher files that render as bpatchers set `"openinpresentation": 1`; total presentation height stays ≤ 168 px (standard Live device height).
- Spec control ranges (copy exactly): Focus 200–8000 Hz default 1500; Sensitivity 0–100 % default 50; Retrig 20–500 ms default 60; Prob 0–100 % default 100; Attack 0–500 ms default 1; Decay 10–5000 ms default 250; Min 0–100 % default 0; Max 0–100 % default 100.
- **JSON authored by hand may be normalized by Max on first save.** That is fine; after the device first loads correctly, re-saving from Max produces the canonical form.
- A live Max instance may be open on the user's machine. `get_object_doc` works without a patch; patch-inspection tools require the user to have the patch open. **Never assume MCP patch-editing tools can create or save files — they cannot. All files are authored with the Write tool.**

## Assumption Checks (doc-verified during tasks)

Several Max object behaviors are encoded in this plan from documentation knowledge. Each task that depends on one contains an explicit `get_object_doc` verification step. The load-bearing assumptions:

1. `live.remote~`: 2 inlets — left takes the control **signal in the target parameter's native range**, right takes `id <n>` to bind (`id 0` unbinds).
2. `svf~` outlet order: 0 = lowpass, **1 = highpass**, 2 = bandpass, 3 = notch.
3. `onebang`: left bang passes once then blocks until a bang on the right inlet re-arms it.
4. `zl reg`: right inlet stores a list silently; bang on left inlet outputs the stored list.
5. `live.observer` observing `selected_parameter` on `live_set view` outputs `id <n>` when the user clicks any parameter in Live.
6. Live API object ids are persistent within a saved Live set, so an id stored in a `pattr` (with `parameter_enable: 1`) rebinds correctly after save/reload.

If a doc check contradicts an assumption, **stop and adapt the wiring in that task before proceeding** (the plan says exactly what to re-check in each case).

## File Structure

```
m4l-bonko/
├── docs/superpowers/…                  (spec + this plan, already committed)
├── tools/
│   ├── validate_patch.py               structural validator for .maxpat JSON
│   └── make_amxd.py                    wraps patcher JSON in .amxd binary header
├── tests/
│   ├── test_validate.py                tests for the validator
│   └── fixtures/
│       ├── minimal_good.maxpat
│       └── broken_line.maxpat
├── patchers/
│   ├── bonko.detector.maxpat           detector abstraction (bpatcher)
│   ├── bonko.map.maxpat                Map-button/bind abstraction (bpatcher, nested in slot)
│   └── bonko.slot.maxpat               target slot abstraction (bpatcher ×4)
├── Bonko.maxpat                        main device patcher (source of truth)
└── Bonko.amxd                          built device (generated by make_amxd.py)
```

---

### Task 1: Validation tooling

The validator is the "test harness" for every subsequent task: it checks that a `.maxpat` file is valid JSON, has a `patcher` root, unique box ids, patchlines that reference existing boxes, `patching_rect` on every box, and unique `parameter_longname`s per file. It recurses into embedded subpatchers.

**Files:**
- Create: `tools/validate_patch.py`
- Create: `tests/fixtures/minimal_good.maxpat`
- Create: `tests/fixtures/broken_line.maxpat`
- Test: `tests/test_validate.py`

**Interfaces:**
- Consumes: nothing.
- Produces: CLI `python3 tools/validate_patch.py <file.maxpat> [more…]` → exit 0 + `OK: N file(s) valid` on success; exit 1 with one error per line on failure. Importable function `validate(path) -> list[str]` (empty list = valid).

- [ ] **Step 1: Write the failing test**

Create `tests/test_validate.py`:

```python
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
```

Create `tests/fixtures/minimal_good.maxpat`:

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 400.0, 300.0],
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "cycle~ 440", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 30.0, 70.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "*~ 0.1", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 70.0, 50.0, 22.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}}
    ]
  }
}
```

Create `tests/fixtures/broken_line.maxpat` (patchline to a nonexistent box AND two dials with the same longname):

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 400.0, 300.0],
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "cycle~ 440", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 30.0, 70.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "live.dial", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [150.0, 30.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Dup", "parameter_shortname": "Dup", "parameter_type": 0, "parameter_range": [0.0, 100.0]}}}},
      {"box": {"id": "obj-3", "maxclass": "live.dial", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [220.0, 30.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Dup", "parameter_shortname": "Dup", "parameter_type": 0, "parameter_range": [0.0, 100.0]}}}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-99", 0]}}
    ]
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 tests/test_validate.py`
Expected: crash with `ModuleNotFoundError: No module named 'validate_patch'` (validator doesn't exist yet).

- [ ] **Step 3: Write the validator**

Create `tools/validate_patch.py`:

```python
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
    dupes = sorted({n for n in longnames if longnames.count(n) > 1})
    if dupes:
        errors.append(f"{path}: duplicate parameter_longname(s): {dupes}")
    return errors


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
```

Note: the `parameter_enable` check applies to UI objects saved with a `live.*` maxclass (`live.dial`, `live.text`, …). Non-UI Live API objects (`live.thisdevice`, `live.path`, `live.observer`, `live.object`, `live.remote~`, and `pattr`) are saved as `maxclass: "newobj"` with the object name in `text`, so the check correctly ignores them.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 tests/test_validate.py`
Expected: `PASS` × 3, exit 0. Also run the CLI: `python3 tools/validate_patch.py tests/fixtures/minimal_good.maxpat` → `OK: 1 file(s) valid`.

- [ ] **Step 5: Add .gitignore and commit**

Create `.gitignore`:

```
*.maxpat~
*.amxd~
.DS_Store
__pycache__/
```

```bash
git add .gitignore tools/validate_patch.py tests/
git commit -m "feat: add maxpat structural validator with tests"
```

---

### Task 2: Detector abstraction (`patchers/bonko.detector.maxpat`)

Vanilla onset detector per spec: detection HPF (`svf~` highpass out) → `abs~` → `slide~` envelope → threshold crossing (`>~` + `edge~`) → retrigger guard (`onebang` re-armed by `delay`). UI: Focus/Sens/Retrig dials, input meter, trigger LED.

**Files:**
- Create: `patchers/bonko.detector.maxpat`
- Test: `python3 tools/validate_patch.py patchers/bonko.detector.maxpat`

**Interfaces:**
- Consumes: validator CLI from Task 1.
- Produces: an abstraction with **1 signal inlet** (audio to analyze) and **1 outlet** (bang per detected transient), rendering a 120×161 presentation UI. Loaded by Task 5 as `bpatcher @name bonko.detector.maxpat`. Parameters: `Focus`, `Sens`, `Retrig`.

- [ ] **Step 1: Verify object assumptions against Max docs**

Using the maxmsp MCP tool `get_object_doc`, check:
- `svf~` → confirm outlet order (assumption: outlet index 1 = highpass) and that inlet 1 accepts a float frequency.
- `onebang` → confirm right-inlet bang re-arms, and whether it starts armed (the patch sends a `loadbang` to the right inlet regardless, so initial state doesn't matter).
- `slide~` → confirm args are `slide~ <slide-up> <slide-down>` smoothing factors.
- `edge~` → confirm left outlet bangs on zero→nonzero transition.

If `svf~`'s highpass is a different outlet index, change the single patchline from `obj-2` accordingly in Step 2. If any other assumption fails, adjust that one connection — the topology is otherwise independent.

- [ ] **Step 2: Write the patcher file**

Create `patchers/bonko.detector.maxpat`:

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 700.0, 500.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "inlet", "index": 1, "comment": "audio in (signal)", "numinlets": 0, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 30.0, 30.0, 30.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "svf~ 1500. 0.707", "numinlets": 3, "numoutlets": 4, "outlettype": ["signal", "signal", "signal", "signal"], "patching_rect": [30.0, 90.0, 110.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "abs~", "numinlets": 1, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 130.0, 40.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "newobj", "text": "slide~ 10. 2205.", "numinlets": 3, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 170.0, 100.0, 22.0]}},
      {"box": {"id": "obj-5", "maxclass": "newobj", "text": ">~ 0.05", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 250.0, 60.0, 22.0]}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "edge~", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [55.0, 290.0, 46.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "newobj", "text": "onebang", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [55.0, 330.0, 60.0, 22.0]}},
      {"box": {"id": "obj-8", "maxclass": "newobj", "text": "t b b b", "numinlets": 1, "numoutlets": 3, "outlettype": ["bang", "bang", "bang"], "patching_rect": [55.0, 370.0, 50.0, 22.0]}},
      {"box": {"id": "obj-9", "maxclass": "newobj", "text": "delay 60", "numinlets": 2, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [110.0, 410.0, 60.0, 22.0]}},
      {"box": {"id": "obj-10", "maxclass": "outlet", "index": 1, "comment": "bang per transient", "numinlets": 1, "numoutlets": 0, "patching_rect": [55.0, 455.0, 30.0, 30.0]}},
      {"box": {"id": "obj-11", "maxclass": "newobj", "text": "loadbang", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [200.0, 290.0, 60.0, 22.0]}},
      {"box": {"id": "obj-12", "maxclass": "live.dial", "varname": "focus", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [300.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [64.0, 22.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Focus", "parameter_shortname": "Focus", "parameter_type": 0, "parameter_unitstyle": 3, "parameter_range": [200.0, 8000.0], "parameter_exponent": 3.0, "parameter_initial_enable": 1, "parameter_initial": [1500.0]}}}},
      {"box": {"id": "obj-13", "maxclass": "live.dial", "varname": "sens", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [380.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [10.0, 106.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Sens", "parameter_shortname": "Sens", "parameter_type": 0, "parameter_unitstyle": 5, "parameter_range": [0.0, 100.0], "parameter_initial_enable": 1, "parameter_initial": [50.0]}}}},
      {"box": {"id": "obj-14", "maxclass": "newobj", "text": "expr 0.5*pow(0.001\\,$f1*0.01)", "numinlets": 1, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [380.0, 130.0, 180.0, 22.0]}},
      {"box": {"id": "obj-15", "maxclass": "live.dial", "varname": "retrig", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [460.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [64.0, 106.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Retrig", "parameter_shortname": "Retrig", "parameter_type": 0, "parameter_unitstyle": 2, "parameter_range": [20.0, 500.0], "parameter_initial_enable": 1, "parameter_initial": [60.0]}}}},
      {"box": {"id": "obj-16", "maxclass": "meter~", "numinlets": 1, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [200.0, 170.0, 12.0, 80.0], "presentation": 1, "presentation_rect": [6.0, 24.0, 10.0, 76.0]}},
      {"box": {"id": "obj-17", "maxclass": "button", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [130.0, 410.0, 20.0, 20.0], "presentation": 1, "presentation_rect": [40.0, 24.0, 16.0, 16.0]}},
      {"box": {"id": "obj-18", "maxclass": "comment", "text": "BONKO DETECT", "numinlets": 1, "numoutlets": 0, "patching_rect": [300.0, 20.0, 120.0, 20.0], "presentation": 1, "presentation_rect": [4.0, 2.0, 112.0, 18.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-12", 0], "destination": ["obj-2", 1]}},
      {"patchline": {"source": ["obj-2", 1], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-3", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-16", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-14", 0]}},
      {"patchline": {"source": ["obj-14", 0], "destination": ["obj-5", 1]}},
      {"patchline": {"source": ["obj-5", 0], "destination": ["obj-6", 0]}},
      {"patchline": {"source": ["obj-6", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-11", 0], "destination": ["obj-7", 1]}},
      {"patchline": {"source": ["obj-7", 0], "destination": ["obj-8", 0]}},
      {"patchline": {"source": ["obj-8", 0], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-8", 1], "destination": ["obj-9", 0]}},
      {"patchline": {"source": ["obj-8", 2], "destination": ["obj-17", 0]}},
      {"patchline": {"source": ["obj-15", 0], "destination": ["obj-9", 1]}},
      {"patchline": {"source": ["obj-9", 0], "destination": ["obj-7", 1]}}
    ]
  }
}
```

Design notes encoded above: Sens is inverted via `expr` — threshold = 0.5 × 0.001^(sens/100), so 0 % → 0.5 (least sensitive) and 100 % → 0.0005 (most sensitive). `slide~ 10. 2205.` ≈ instant rise, ~50 ms fall at 44.1 kHz — the fall is what lets the envelope re-cross threshold between picks. `t b b b` fires right-to-left: LED, then start retrig lockout, then emit the trigger bang.

- [ ] **Step 3: Validate**

Run: `python3 tools/validate_patch.py patchers/bonko.detector.maxpat`
Expected: `OK: 1 file(s) valid`

- [ ] **Step 4: Commit**

```bash
git add patchers/bonko.detector.maxpat
git commit -m "feat: add vanilla transient detector abstraction"
```

---

### Task 3: Map/bind abstraction (`patchers/bonko.map.maxpat`)

The Map button mechanics: arm via a `live.text` toggle, observe `live_set view selected_parameter`, capture the picked parameter id, bind `live.remote~`, fetch the parameter's min/max for output scaling and its name + device name for the label, persist the id in a `pattr`, rebind on set load via `live.thisdevice`, and clear gracefully if the stored id is stale.

**Files:**
- Create: `patchers/bonko.map.maxpat`
- Test: `python3 tools/validate_patch.py patchers/bonko.map.maxpat`

**Interfaces:**
- Consumes: validator CLI from Task 1.
- Produces: an abstraction with **1 signal inlet** (envelope, 0..1 range, already Min/Max-shaped by the slot) and **0 outlets** (it drives `live.remote~` internally), rendering a 130×26 presentation strip (Map button + target label). Loaded by Task 4 as `bpatcher @name bonko.map.maxpat`. Parameters: `MapBtn`, `TargetId`.

- [ ] **Step 1: Verify Live API object assumptions against Max docs**

Using `get_object_doc`, check:
- `live.remote~` → confirm inlet count and that `id <n>` on the **right** inlet binds / `id 0` unbinds, and that the **left signal inlet expects values in the parameter's native range** (this is why the patch fetches `min`/`max` and scales). If the signal range is normalized 0..1 instead, delete boxes obj-20/obj-21 (`get min`/`get max`) and the two patchlines into `scale~`, and set `scale~`'s args to `0. 1. 0. 1.` permanently.
- `live.observer` → confirm right inlet accepts `id <n>` to set the observed object and `property <name>` on the left inlet selects the property; observing `selected_parameter` outputs `id <n>`.
- `live.object` → confirm right inlet takes `id <n>` and `get <property>` on the left outputs `<property> <value…>`; confirm `DeviceParameter` has properties `name`, `min`, `max`, `canonical_parent`.
- `live.path` → confirm `path live_set view` resolves and the id outlet emits `id <n>`.
- `live.text` → confirm the attribute value that makes it a toggle (the JSON below uses `"mode": 1`) and that `set $1` changes state without output.
- `pattr` → confirm `parameter_enable: 1` makes its value persist in the Live set, and which `parameter_type` value means "blob" (the JSON below uses 3). Also confirm `parameter_invisible: 1` hides it from automation while still storing.

- [ ] **Step 2: Write the patcher file**

Create `patchers/bonko.map.maxpat`. Wiring summary before the JSON — the executor should read this against the `lines` array:

- **Arm/disarm:** `live.text` (obj-4) outputs 1/0 → opens/closes `gate` (obj-10) AND hits `sel 0` (obj-25); on 0: `id 0` → remote (unbind), `0` stored to pattr, label reset to `Map a parameter`.
- **Pick:** `live.thisdevice` (obj-6) → `t b b` (obj-27): right branch sends `path live_set view` (obj-28) to `live.path` (obj-7); its id out → `t b l` (obj-29): list → `live.observer` (obj-8) right inlet, then bang → `property selected_parameter` (obj-9) → observer left. Observer output → `route id` (obj-11) → `gate` (obj-10) → `route 0` (obj-12, discards id 0) → valid-id dispatcher.
- **Valid-id dispatcher** `t b b b b b i i i` (obj-13), firing right-to-left: set `live.object` A target (`id $1`, obj-14 → obj-15 right) → store id (obj-16 `i` → obj-17 `pattr TargetId`) → bind remote (`id $1` obj-18 → obj-3 right) → `get min` (obj-20) → `get max` (obj-21) → `get name` (obj-22) → `get canonical_parent` (obj-23) → disarm (bang → `set 0` obj-30 to live.text AND `0` obj-31 to gate control).
- **live.object A** (obj-15) output → `route name canonical_parent min max` (obj-19): `name` remainder → `tosymbol` (obj-24) → **right** (cold) inlet of `pak s s` (obj-35); `canonical_parent` remainder (`id <n>`) → `route id` (obj-32) → `t b i` (obj-33): `id $1` (obj-34) → `live.object` B (obj-36) right, then bang → `get name` (obj-37) → B left; B output → `route name` (obj-38) → `tosymbol` (obj-39) → **left** (hot) inlet of `pak s s` → `sprintf symout %s > %s` (obj-40) → `prepend set` (obj-41) → label message box (obj-5). `min` → `scale~` (obj-2) inlet 3; `max` → inlet 4. Because the dispatcher fires `get name` (param) before `get canonical_parent` (device), the cold inlet is filled before the hot one fires — label shows `Device > Param`.
- **Restore:** `live.thisdevice` → `t b b` (obj-27) left branch → `deferlow` (obj-42) → `t b b` (obj-43): right → `0` (obj-44) → stale-flag `i` (obj-45) right (reset); left → bang `pattr` (obj-17, outputs stored id) AND → `delay 200` (obj-46) → flag `i` left (output) → `sel 0` (obj-47) → unmap chain (obj-26). pattr output → `change` (obj-48, breaks the store→output loop) → `route 0` (obj-49, discard empty) → valid-id dispatcher (obj-13). When the restored id is alive, `route name` fires → `1` (obj-50) sets the stale flag → `sel 0` stays quiet. Dead id → no name → flag still 0 after 200 ms → auto-unmap.
- **Unmap chain** `t b b b` (obj-26): `id 0` (obj-51) → remote right; `0` (obj-52) → id store obj-16 (→ pattr); `set Map a parameter` (obj-53) → label.
- **Audio:** inlet (obj-1) → `scale~ 0. 1. 0. 1.` (obj-2) → `live.remote~` (obj-3) left.

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 1000.0, 700.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "inlet", "index": 1, "comment": "envelope signal 0..1", "numinlets": 0, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 30.0, 30.0, 30.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "scale~ 0. 1. 0. 1.", "numinlets": 5, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 90.0, 110.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "live.remote~", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 140.0, 80.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "live.text", "varname": "map_btn", "parameter_enable": 1, "mode": 1, "text": "Map", "texton": "Map", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [200.0, 30.0, 44.0, 20.0], "presentation": 1, "presentation_rect": [0.0, 4.0, 38.0, 18.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "MapBtn", "parameter_shortname": "Map", "parameter_type": 2, "parameter_range": [0, 1], "parameter_invisible": 1}}}},
      {"box": {"id": "obj-5", "maxclass": "message", "text": "Map a parameter", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 620.0, 150.0, 22.0], "presentation": 1, "presentation_rect": [42.0, 4.0, 86.0, 18.0]}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "live.thisdevice", "numinlets": 1, "numoutlets": 3, "outlettype": ["bang", "int", ""], "patching_rect": [420.0, 30.0, 80.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "newobj", "text": "live.path", "numinlets": 1, "numoutlets": 3, "outlettype": ["", "", ""], "patching_rect": [560.0, 110.0, 60.0, 22.0]}},
      {"box": {"id": "obj-8", "maxclass": "newobj", "text": "live.observer", "numinlets": 2, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [560.0, 200.0, 84.0, 22.0]}},
      {"box": {"id": "obj-9", "maxclass": "message", "text": "property selected_parameter", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [660.0, 160.0, 170.0, 22.0]}},
      {"box": {"id": "obj-10", "maxclass": "newobj", "text": "gate", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 280.0, 40.0, 22.0]}},
      {"box": {"id": "obj-11", "maxclass": "newobj", "text": "route id", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [560.0, 240.0, 56.0, 22.0]}},
      {"box": {"id": "obj-12", "maxclass": "newobj", "text": "route 0", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [560.0, 320.0, 52.0, 22.0]}},
      {"box": {"id": "obj-13", "maxclass": "newobj", "text": "t b b b b b i i i", "numinlets": 1, "numoutlets": 8, "outlettype": ["bang", "bang", "bang", "bang", "bang", "int", "int", "int"], "patching_rect": [560.0, 360.0, 120.0, 22.0]}},
      {"box": {"id": "obj-14", "maxclass": "message", "text": "id $1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [900.0, 400.0, 44.0, 22.0]}},
      {"box": {"id": "obj-15", "maxclass": "newobj", "text": "live.object", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [700.0, 470.0, 70.0, 22.0]}},
      {"box": {"id": "obj-16", "maxclass": "newobj", "text": "i", "numinlets": 2, "numoutlets": 1, "outlettype": ["int"], "patching_rect": [850.0, 400.0, 30.0, 22.0]}},
      {"box": {"id": "obj-17", "maxclass": "newobj", "text": "pattr TargetId @parameter_enable 1", "numinlets": 2, "numoutlets": 3, "outlettype": ["", "", ""], "patching_rect": [850.0, 440.0, 200.0, 22.0], "saved_object_attributes": {"parameter_enable": 1, "parameter_mappable": 0}, "saved_attribute_attributes": {"valueof": {"parameter_longname": "TargetId", "parameter_shortname": "TargetId", "parameter_type": 3, "parameter_invisible": 1}}}},
      {"box": {"id": "obj-18", "maxclass": "message", "text": "id $1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [800.0, 400.0, 44.0, 22.0]}},
      {"box": {"id": "obj-19", "maxclass": "newobj", "text": "route name canonical_parent min max", "numinlets": 1, "numoutlets": 5, "outlettype": ["", "", "", "", ""], "patching_rect": [700.0, 510.0, 220.0, 22.0]}},
      {"box": {"id": "obj-20", "maxclass": "message", "text": "get min", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [750.0, 400.0, 50.0, 22.0]}},
      {"box": {"id": "obj-21", "maxclass": "message", "text": "get max", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [696.0, 400.0, 54.0, 22.0]}},
      {"box": {"id": "obj-22", "maxclass": "message", "text": "get name", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [636.0, 400.0, 58.0, 22.0]}},
      {"box": {"id": "obj-23", "maxclass": "message", "text": "get canonical_parent", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [500.0, 400.0, 130.0, 22.0]}},
      {"box": {"id": "obj-24", "maxclass": "newobj", "text": "tosymbol", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [700.0, 545.0, 60.0, 22.0]}},
      {"box": {"id": "obj-25", "maxclass": "newobj", "text": "sel 0", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", ""], "patching_rect": [200.0, 70.0, 40.0, 22.0]}},
      {"box": {"id": "obj-26", "maxclass": "newobj", "text": "t b b b", "numinlets": 1, "numoutlets": 3, "outlettype": ["bang", "bang", "bang"], "patching_rect": [200.0, 110.0, 54.0, 22.0]}},
      {"box": {"id": "obj-27", "maxclass": "newobj", "text": "t b b", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [420.0, 70.0, 40.0, 22.0]}},
      {"box": {"id": "obj-28", "maxclass": "message", "text": "path live_set view", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 70.0, 110.0, 22.0]}},
      {"box": {"id": "obj-29", "maxclass": "newobj", "text": "t b l", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", ""], "patching_rect": [560.0, 150.0, 40.0, 22.0]}},
      {"box": {"id": "obj-30", "maxclass": "message", "text": "set 0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [340.0, 400.0, 40.0, 22.0]}},
      {"box": {"id": "obj-31", "maxclass": "message", "text": "0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [390.0, 400.0, 24.0, 22.0]}},
      {"box": {"id": "obj-32", "maxclass": "newobj", "text": "route id", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [940.0, 510.0, 56.0, 22.0]}},
      {"box": {"id": "obj-33", "maxclass": "newobj", "text": "t b i", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", "int"], "patching_rect": [940.0, 545.0, 40.0, 22.0]}},
      {"box": {"id": "obj-34", "maxclass": "message", "text": "id $1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [990.0, 580.0, 44.0, 22.0]}},
      {"box": {"id": "obj-35", "maxclass": "newobj", "text": "pak s s", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [700.0, 620.0, 54.0, 22.0]}},
      {"box": {"id": "obj-36", "maxclass": "newobj", "text": "live.object", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [940.0, 615.0, 70.0, 22.0]}},
      {"box": {"id": "obj-37", "maxclass": "message", "text": "get name", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [880.0, 580.0, 58.0, 22.0]}},
      {"box": {"id": "obj-38", "maxclass": "newobj", "text": "route name", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [940.0, 650.0, 70.0, 22.0]}},
      {"box": {"id": "obj-39", "maxclass": "newobj", "text": "tosymbol", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [860.0, 650.0, 60.0, 22.0]}},
      {"box": {"id": "obj-40", "maxclass": "newobj", "text": "sprintf symout %s > %s", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [700.0, 655.0, 140.0, 22.0]}},
      {"box": {"id": "obj-41", "maxclass": "newobj", "text": "prepend set", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 590.0, 74.0, 22.0]}},
      {"box": {"id": "obj-42", "maxclass": "newobj", "text": "deferlow", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [420.0, 110.0, 60.0, 22.0]}},
      {"box": {"id": "obj-43", "maxclass": "newobj", "text": "t b b", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [420.0, 150.0, 40.0, 22.0]}},
      {"box": {"id": "obj-44", "maxclass": "message", "text": "0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [470.0, 190.0, 24.0, 22.0]}},
      {"box": {"id": "obj-45", "maxclass": "newobj", "text": "i", "numinlets": 2, "numoutlets": 1, "outlettype": ["int"], "patching_rect": [420.0, 270.0, 30.0, 22.0]}},
      {"box": {"id": "obj-46", "maxclass": "newobj", "text": "delay 200", "numinlets": 2, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [420.0, 230.0, 66.0, 22.0]}},
      {"box": {"id": "obj-47", "maxclass": "newobj", "text": "sel 0", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", ""], "patching_rect": [420.0, 310.0, 40.0, 22.0]}},
      {"box": {"id": "obj-48", "maxclass": "newobj", "text": "change", "numinlets": 1, "numoutlets": 3, "outlettype": ["", "", ""], "patching_rect": [850.0, 480.0, 50.0, 22.0]}},
      {"box": {"id": "obj-49", "maxclass": "newobj", "text": "route 0", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [850.0, 515.0, 52.0, 22.0]}},
      {"box": {"id": "obj-50", "maxclass": "message", "text": "1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [640.0, 545.0, 24.0, 22.0]}},
      {"box": {"id": "obj-51", "maxclass": "message", "text": "id 0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [200.0, 150.0, 34.0, 22.0]}},
      {"box": {"id": "obj-52", "maxclass": "message", "text": "0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [244.0, 150.0, 24.0, 22.0]}},
      {"box": {"id": "obj-53", "maxclass": "message", "text": "set Map a parameter", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [278.0, 150.0, 124.0, 22.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-2", 0], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-25", 0]}},
      {"patchline": {"source": ["obj-25", 0], "destination": ["obj-26", 0]}},
      {"patchline": {"source": ["obj-26", 0], "destination": ["obj-51", 0]}},
      {"patchline": {"source": ["obj-26", 1], "destination": ["obj-52", 0]}},
      {"patchline": {"source": ["obj-26", 2], "destination": ["obj-53", 0]}},
      {"patchline": {"source": ["obj-51", 0], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-52", 0], "destination": ["obj-16", 0]}},
      {"patchline": {"source": ["obj-53", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-6", 0], "destination": ["obj-27", 0]}},
      {"patchline": {"source": ["obj-27", 1], "destination": ["obj-28", 0]}},
      {"patchline": {"source": ["obj-28", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-7", 0], "destination": ["obj-29", 0]}},
      {"patchline": {"source": ["obj-29", 1], "destination": ["obj-8", 1]}},
      {"patchline": {"source": ["obj-29", 0], "destination": ["obj-9", 0]}},
      {"patchline": {"source": ["obj-9", 0], "destination": ["obj-8", 0]}},
      {"patchline": {"source": ["obj-8", 0], "destination": ["obj-11", 0]}},
      {"patchline": {"source": ["obj-11", 0], "destination": ["obj-10", 1]}},
      {"patchline": {"source": ["obj-10", 0], "destination": ["obj-12", 0]}},
      {"patchline": {"source": ["obj-12", 1], "destination": ["obj-13", 0]}},
      {"patchline": {"source": ["obj-13", 7], "destination": ["obj-14", 0]}},
      {"patchline": {"source": ["obj-14", 0], "destination": ["obj-15", 1]}},
      {"patchline": {"source": ["obj-13", 6], "destination": ["obj-16", 0]}},
      {"patchline": {"source": ["obj-16", 0], "destination": ["obj-17", 0]}},
      {"patchline": {"source": ["obj-13", 5], "destination": ["obj-18", 0]}},
      {"patchline": {"source": ["obj-18", 0], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-13", 4], "destination": ["obj-20", 0]}},
      {"patchline": {"source": ["obj-13", 3], "destination": ["obj-21", 0]}},
      {"patchline": {"source": ["obj-13", 2], "destination": ["obj-22", 0]}},
      {"patchline": {"source": ["obj-13", 1], "destination": ["obj-23", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-30", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-31", 0]}},
      {"patchline": {"source": ["obj-30", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-31", 0], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-20", 0], "destination": ["obj-15", 0]}},
      {"patchline": {"source": ["obj-21", 0], "destination": ["obj-15", 0]}},
      {"patchline": {"source": ["obj-22", 0], "destination": ["obj-15", 0]}},
      {"patchline": {"source": ["obj-23", 0], "destination": ["obj-15", 0]}},
      {"patchline": {"source": ["obj-15", 0], "destination": ["obj-19", 0]}},
      {"patchline": {"source": ["obj-19", 0], "destination": ["obj-24", 0]}},
      {"patchline": {"source": ["obj-19", 0], "destination": ["obj-50", 0]}},
      {"patchline": {"source": ["obj-24", 0], "destination": ["obj-35", 1]}},
      {"patchline": {"source": ["obj-19", 1], "destination": ["obj-32", 0]}},
      {"patchline": {"source": ["obj-32", 0], "destination": ["obj-33", 0]}},
      {"patchline": {"source": ["obj-33", 1], "destination": ["obj-34", 0]}},
      {"patchline": {"source": ["obj-34", 0], "destination": ["obj-36", 1]}},
      {"patchline": {"source": ["obj-33", 0], "destination": ["obj-37", 0]}},
      {"patchline": {"source": ["obj-37", 0], "destination": ["obj-36", 0]}},
      {"patchline": {"source": ["obj-36", 0], "destination": ["obj-38", 0]}},
      {"patchline": {"source": ["obj-38", 0], "destination": ["obj-39", 0]}},
      {"patchline": {"source": ["obj-39", 0], "destination": ["obj-35", 0]}},
      {"patchline": {"source": ["obj-35", 0], "destination": ["obj-40", 0]}},
      {"patchline": {"source": ["obj-40", 0], "destination": ["obj-41", 0]}},
      {"patchline": {"source": ["obj-41", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-19", 2], "destination": ["obj-2", 3]}},
      {"patchline": {"source": ["obj-19", 3], "destination": ["obj-2", 4]}},
      {"patchline": {"source": ["obj-27", 0], "destination": ["obj-42", 0]}},
      {"patchline": {"source": ["obj-42", 0], "destination": ["obj-43", 0]}},
      {"patchline": {"source": ["obj-43", 1], "destination": ["obj-44", 0]}},
      {"patchline": {"source": ["obj-44", 0], "destination": ["obj-45", 1]}},
      {"patchline": {"source": ["obj-43", 0], "destination": ["obj-17", 0]}},
      {"patchline": {"source": ["obj-43", 0], "destination": ["obj-46", 0]}},
      {"patchline": {"source": ["obj-46", 0], "destination": ["obj-45", 0]}},
      {"patchline": {"source": ["obj-45", 0], "destination": ["obj-47", 0]}},
      {"patchline": {"source": ["obj-47", 0], "destination": ["obj-26", 0]}},
      {"patchline": {"source": ["obj-17", 0], "destination": ["obj-48", 0]}},
      {"patchline": {"source": ["obj-48", 0], "destination": ["obj-49", 0]}},
      {"patchline": {"source": ["obj-49", 1], "destination": ["obj-13", 0]}},
      {"patchline": {"source": ["obj-50", 0], "destination": ["obj-45", 1]}}
    ]
  }
}
```

Known subtleties encoded above:
- Bang to `pattr`'s left inlet (restore path) makes it output its stored value; a stored value flowing back in through `change` (obj-48) breaks the infinite store→output→store loop.
- `route 0` appears twice on purpose: obj-12 filters "nothing selected" during mapping; obj-49 filters "empty/unmapped" during restore.
- The min/max floats route into `scale~` message inlets 3 and 4 (out-low / out-high). If Min > Max on the *target parameter* side that can't happen (Live parameters always have min < max); envelope inversion is handled upstream in the slot.
- `restore` sends `get name` for a dead id → `live.object` posts a console warning once; acceptable per spec ("no error spam" = no repeated errors).

- [ ] **Step 3: Validate**

Run: `python3 tools/validate_patch.py patchers/bonko.map.maxpat`
Expected: `OK: 1 file(s) valid`

- [ ] **Step 4: Commit**

```bash
git add patchers/bonko.map.maxpat
git commit -m "feat: add Map-button parameter binding abstraction"
```

---

### Task 4: Slot abstraction (`patchers/bonko.slot.maxpat`)

Per-trigger chain: `r ---trig` → probability gate → AD envelope (`line~`, retrigger-from-current) → Min/Max scaling → the map bpatcher.

**Files:**
- Create: `patchers/bonko.slot.maxpat`
- Test: `python3 tools/validate_patch.py patchers/bonko.slot.maxpat`

**Interfaces:**
- Consumes: `patchers/bonko.map.maxpat` (Task 3) as an embedded bpatcher; the trigger bus name `---trig` (bang per transient, published by Task 5's main patch).
- Produces: an abstraction with **no inlets/outlets** (trigger arrives via `r ---trig`), rendering a 138×161 presentation UI. Loaded 4× by Task 5 as `bpatcher @name bonko.slot.maxpat`. Parameters per instance: `Prob`, `Atk`, `Dec`, `Min`, `Max` (+ the nested map abstraction's `MapBtn`, `TargetId`) — Max auto-renames across instances.

- [ ] **Step 1: Verify object assumptions against Max docs**

Using `get_object_doc`, check:
- `zl` → confirm `zl reg` right inlet stores silently and left-inlet bang outputs the stored list.
- `line~` → confirm it accepts multi-segment lists of (target, ramp-ms) pairs (`1. 5 0. 250`) and that a new list restarts from the **current** output value.
- `random` → confirm `random 100` outputs 0–99 on bang.

If `line~` does not accept multi-segment lists, replace obj-8's message with two chained messages (`1. $1` then delayed `0. $2`) — but this is a documented core `line~` feature, so expect it to pass.

- [ ] **Step 2: Write the patcher file**

Create `patchers/bonko.slot.maxpat`:

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 700.0, 560.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "r ---trig", "numinlets": 0, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 30.0, 60.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "t b", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [30.0, 70.0, 32.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "random 100", "numinlets": 2, "numoutlets": 1, "outlettype": ["int"], "patching_rect": [30.0, 110.0, 74.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "newobj", "text": "< 100.", "numinlets": 2, "numoutlets": 1, "outlettype": ["int"], "patching_rect": [30.0, 150.0, 50.0, 22.0]}},
      {"box": {"id": "obj-5", "maxclass": "live.dial", "varname": "prob", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [160.0, 90.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [8.0, 34.0, 40.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Prob", "parameter_shortname": "Prob", "parameter_type": 0, "parameter_unitstyle": 5, "parameter_range": [0.0, 100.0], "parameter_initial_enable": 1, "parameter_initial": [100.0]}}}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "sel 1", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", ""], "patching_rect": [30.0, 190.0, 40.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "newobj", "text": "zl reg 1. 250.", "numinlets": 2, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [30.0, 230.0, 90.0, 22.0]}},
      {"box": {"id": "obj-8", "maxclass": "message", "text": "1. $1 0. $2", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 270.0, 80.0, 22.0]}},
      {"box": {"id": "obj-9", "maxclass": "newobj", "text": "line~", "numinlets": 2, "numoutlets": 2, "outlettype": ["signal", "bang"], "patching_rect": [30.0, 310.0, 44.0, 22.0]}},
      {"box": {"id": "obj-10", "maxclass": "newobj", "text": "scale~ 0. 1. 0. 1.", "numinlets": 5, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 360.0, 110.0, 22.0]}},
      {"box": {"id": "obj-11", "maxclass": "bpatcher", "name": "bonko.map.maxpat", "numinlets": 1, "numoutlets": 0, "patching_rect": [30.0, 420.0, 300.0, 60.0], "presentation": 1, "presentation_rect": [4.0, 4.0, 130.0, 26.0], "viewvisibility": 1}},
      {"box": {"id": "obj-12", "maxclass": "live.dial", "varname": "atk", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [230.0, 90.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [52.0, 34.0, 40.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Atk", "parameter_shortname": "Atk", "parameter_type": 0, "parameter_unitstyle": 2, "parameter_range": [0.0, 500.0], "parameter_exponent": 2.0, "parameter_initial_enable": 1, "parameter_initial": [1.0]}}}},
      {"box": {"id": "obj-13", "maxclass": "live.dial", "varname": "dec", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [300.0, 90.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [96.0, 34.0, 40.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Dec", "parameter_shortname": "Dec", "parameter_type": 0, "parameter_unitstyle": 2, "parameter_range": [10.0, 5000.0], "parameter_exponent": 2.0, "parameter_initial_enable": 1, "parameter_initial": [250.0]}}}},
      {"box": {"id": "obj-14", "maxclass": "newobj", "text": "pak 1. 250.", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [230.0, 160.0, 74.0, 22.0]}},
      {"box": {"id": "obj-15", "maxclass": "live.dial", "varname": "envmin", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [400.0, 90.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [30.0, 90.0, 40.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Min", "parameter_shortname": "Min", "parameter_type": 0, "parameter_unitstyle": 5, "parameter_range": [0.0, 100.0], "parameter_initial_enable": 1, "parameter_initial": [0.0]}}}},
      {"box": {"id": "obj-16", "maxclass": "newobj", "text": "/ 100.", "numinlets": 2, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [400.0, 160.0, 46.0, 22.0]}},
      {"box": {"id": "obj-17", "maxclass": "live.dial", "varname": "envmax", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [470.0, 90.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [74.0, 90.0, 40.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Max", "parameter_shortname": "Max", "parameter_type": 0, "parameter_unitstyle": 5, "parameter_range": [0.0, 100.0], "parameter_initial_enable": 1, "parameter_initial": [100.0]}}}},
      {"box": {"id": "obj-18", "maxclass": "newobj", "text": "/ 100.", "numinlets": 2, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [470.0, 160.0, 46.0, 22.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-2", 0], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-3", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-5", 0], "destination": ["obj-4", 1]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-6", 0]}},
      {"patchline": {"source": ["obj-6", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-12", 0], "destination": ["obj-14", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-14", 1]}},
      {"patchline": {"source": ["obj-14", 0], "destination": ["obj-7", 1]}},
      {"patchline": {"source": ["obj-7", 0], "destination": ["obj-8", 0]}},
      {"patchline": {"source": ["obj-8", 0], "destination": ["obj-9", 0]}},
      {"patchline": {"source": ["obj-9", 0], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-15", 0], "destination": ["obj-16", 0]}},
      {"patchline": {"source": ["obj-16", 0], "destination": ["obj-10", 3]}},
      {"patchline": {"source": ["obj-17", 0], "destination": ["obj-18", 0]}},
      {"patchline": {"source": ["obj-18", 0], "destination": ["obj-10", 4]}},
      {"patchline": {"source": ["obj-10", 0], "destination": ["obj-11", 0]}}
    ]
  }
}
```

Design notes: `pak` (obj-14) fires on every dial change, but its output goes to `zl reg`'s **right** (silent store) inlet — the envelope only fires when `sel 1` bangs `zl reg`'s left inlet. Min > Max simply inverts the scale~ output — the spec's free "duck" mode. Attack of 0 ms is a legal `line~` jump.

- [ ] **Step 3: Validate**

Run: `python3 tools/validate_patch.py patchers/bonko.slot.maxpat`
Expected: `OK: 1 file(s) valid`

- [ ] **Step 4: Commit**

```bash
git add patchers/bonko.slot.maxpat
git commit -m "feat: add target slot abstraction (probability + AD envelope + map)"
```

---

### Task 5: Main patch, `.amxd` builder, and built device

Assemble the device: passthrough, mono sum → detector → `s ---trig`, four slot bpatchers, presentation layout. Then build `Bonko.amxd` by wrapping the patcher JSON in the binary header harvested from a reference Ableton `.amxd`.

**Files:**
- Create: `Bonko.maxpat`
- Create: `tools/make_amxd.py`
- Create: `Bonko.amxd` (generated)
- Test: `python3 tools/validate_patch.py Bonko.maxpat` + round-trip check inside `make_amxd.py`

**Interfaces:**
- Consumes: `patchers/bonko.detector.maxpat` (1 in / 1 out), `patchers/bonko.slot.maxpat` (no I/O, listens on `---trig`), validator CLI.
- Produces: `Bonko.amxd`, loadable in Live; CLI `python3 tools/make_amxd.py <reference.amxd> <input.maxpat> <output.amxd>`.

- [ ] **Step 1: Write the main patcher**

Create `Bonko.maxpat`:

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 900.0, 400.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "plugin~", "numinlets": 1, "numoutlets": 2, "outlettype": ["signal", "signal"], "patching_rect": [30.0, 30.0, 60.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "plugout~", "numinlets": 2, "numoutlets": 2, "outlettype": ["signal", "signal"], "patching_rect": [30.0, 90.0, 66.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "+~", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [150.0, 90.0, 34.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "newobj", "text": "*~ 0.5", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [150.0, 130.0, 48.0, 22.0]}},
      {"box": {"id": "obj-5", "maxclass": "bpatcher", "name": "bonko.detector.maxpat", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [150.0, 170.0, 160.0, 100.0], "presentation": 1, "presentation_rect": [4.0, 4.0, 120.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "s ---trig", "numinlets": 1, "numoutlets": 0, "patching_rect": [150.0, 290.0, 60.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 30.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [128.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-8", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 130.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [270.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-9", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 230.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [412.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-10", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 330.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [554.0, 4.0, 138.0, 161.0], "viewvisibility": 1}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-1", 1], "destination": ["obj-2", 1]}},
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-1", 1], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-3", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-5", 0], "destination": ["obj-6", 0]}}
    ]
  }
}
```

Run: `python3 tools/validate_patch.py Bonko.maxpat patchers/*.maxpat`
Expected: `OK: 4 file(s) valid`

- [ ] **Step 2: Locate a reference .amxd on this machine**

```bash
mdfind -name "Max Audio Effect.amxd" 2>/dev/null | head -5
# fallback if Spotlight finds nothing:
find /Applications -name "*.amxd" -path "*Max Audio Effect*" 2>/dev/null | head -5
find ~/Music/Ableton -name "*.amxd" 2>/dev/null | head -5
```

Expected: at least one path to an Ableton-shipped **Max Audio Effect** `.amxd` (it must be an *audio* effect — the header differs by device type). Record the path for Step 4. If none is found, **stop this step** and mark Step 4/5 as skipped; Task 6 contains the manual fallback (paste into a blank device) and the plan still completes.

- [ ] **Step 3: Write the .amxd builder**

Create `tools/make_amxd.py`:

```python
#!/usr/bin/env python3
"""Build an .amxd by transplanting patcher JSON into a reference .amxd's
binary chunk header.

An .amxd is a chunked binary container whose final chunk holds the patcher
JSON. Rather than hard-coding the chunk layout, this script finds where the
JSON payload begins in a known-good reference file, checks that the 4 bytes
immediately before it encode that payload's length (trying both endiannesses),
and rewrites that length for the new payload.

Usage: python3 tools/make_amxd.py <reference.amxd> <input.maxpat> <output.amxd>
"""
import json
import struct
import sys


def build(ref_path, maxpat_path, out_path):
    with open(ref_path, "rb") as f:
        ref = f.read()
    idx = ref.find(b'{')
    if idx < 8:
        sys.exit(f"error: no JSON payload found in reference {ref_path}")
    ref_json_len = len(ref) - idx
    header = bytearray(ref[:idx])
    size_bytes = bytes(header[-4:])
    endian = None
    for fmt in ("<I", ">I"):
        if struct.unpack(fmt, size_bytes)[0] == ref_json_len:
            endian = fmt
            break
    if endian is None:
        sys.exit(
            "error: could not confirm payload-length field in reference header "
            f"(last-4-bytes={size_bytes.hex()}, json_len={ref_json_len}). "
            "Use the manual fallback (paste patch into a blank device in Max)."
        )
    with open(maxpat_path) as f:
        payload = json.dumps(json.load(f)).encode("utf-8")
    header[-4:] = struct.pack(endian, len(payload))
    with open(out_path, "wb") as f:
        f.write(bytes(header) + payload)
    # round-trip check: extracted JSON must parse and match input
    with open(out_path, "rb") as f:
        out = f.read()
    extracted = out[out.find(b'{'):]
    assert json.loads(extracted) == json.loads(payload), "round-trip mismatch"
    print(f"OK: wrote {out_path} ({len(payload)} bytes JSON, endian {endian})")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__)
        sys.exit(2)
    build(*sys.argv[1:4])
```

- [ ] **Step 4: Build the device**

Run (substitute the reference path from Step 2):

```bash
python3 tools/make_amxd.py "<REFERENCE_PATH>" Bonko.maxpat Bonko.amxd
```

Expected: `OK: wrote Bonko.amxd (… bytes JSON, endian …)`. If the script exits with the could-not-confirm error, the reference header layout differs from the assumption — do not force it; rely on the Task 6 manual fallback and note it in the commit message.

- [ ] **Step 5: Commit**

```bash
git add Bonko.maxpat tools/make_amxd.py Bonko.amxd
git commit -m "feat: assemble main device patch and .amxd builder"
```

---

### Task 6: In-Live verification and normalization

Manual verification with the user, against the spec's testing plan. The abstractions (`patchers/*.maxpat`) must be findable by the device: the simplest arrangement is that `Bonko.amxd` lives next to the `patchers/` folder and the user adds the project folder (recursively) to Max's search path once (Max → Settings → File Preferences), or the executor copies the three abstraction files next to `Bonko.amxd` — both work; the repo layout already satisfies the second.

**Files:**
- Modify: `Bonko.amxd` (re-saved/normalized from Max after first successful load)

**Interfaces:**
- Consumes: `Bonko.amxd` from Task 5, a Live set with a guitar DI clip (ask the user for one, or any percussive audio clip as stand-in).
- Produces: a verified, Max-normalized `Bonko.amxd`.

- [ ] **Step 1: Load the device in Live**

Ask the user to drop `Bonko.amxd` onto an audio track. **Fallback if Task 5 could not build the .amxd or Live rejects it:** drop Ableton's blank "Max Audio Effect" onto the track, click its edit (pencil) button, and in the Max editor: File → Open `Bonko.maxpat`, Edit → Select All → Copy, paste into the blank device's patcher between `plugin~`/`plugout~` (deleting the template's default objects first), then save. Either route ends with the device on a track.

Expected: device loads with no missing-object errors in the Max window; UI shows detector section + 4 slots. If boxes show as broken text objects, check the Max window's error list and fix the named box in the corresponding `.maxpat` (then rebuild and reload).

- [ ] **Step 2: Run the spec's test checklist with the user**

Walk through each; record pass/fail:

1. **Passthrough null test:** duplicate the track, bypass Bonko on the copy, phase-invert one (Utility), play — expect silence (bit-identical passthrough).
2. **Detection:** play the guitar/percussive clip; trigger LED fires on attacks; Sens raises/lowers trigger density; Focus high → still catches pick attacks; Retrig at 500 ms visibly suppresses rapid retriggers.
3. **Mapping lifecycle:** click Map on slot 1 → click Auto Filter cutoff on another track → label reads `Auto Filter > Frequency` (or similar), cutoff pulses on transients with slot 1's Attack/Decay/Min/Max shaping it. Unmap releases the parameter at its original value.
4. **Probability:** slot Prob at 50 % → roughly half the transients fire it (watch ~30 triggers).
5. **Multi-slot:** map all 4 slots to different parameters → all fire per transient, each with its own envelope.
6. **Persistence:** save the set, close, reopen → all 4 mappings restored with names. Delete a target device, save, reopen → that slot silently shows `Map a parameter`, others intact.
7. **Undo:** map, then Cmd-Z — Live-side state behaves sanely (no crash; note behavior).
8. **CPU:** Live's CPU meter shows negligible change with the device active.

If any check fails, debug via superpowers:systematic-debugging (the maxmsp MCP tools can inspect the open patch: `get_objects_in_patch`, `get_object_attributes`, `send_messages_to_object`), fix the source `.maxpat`, rebuild with `make_amxd.py`, and re-verify that check.

- [ ] **Step 3: Normalize and commit the verified device**

In the Max editor, save the device once (Max rewrites the `.amxd` in canonical form — parameter auto-renames like `Prob[1]` land here). Copy the saved `.amxd` back into the repo if Max saved it elsewhere. Then:

```bash
git add -A
git commit -m "feat: verified Bonko device in Live; normalized amxd"
```

---

## Plan Self-Review Notes

- **Spec coverage:** detector (Task 2), map/bind incl. persistence + stale-id handling (Task 3), slots with probability/AD/min-max-invert (Task 4), passthrough + trigger bus + 4 slots + UI (Task 5), full testing plan (Task 6). V2 items intentionally absent per spec.
- **Known-risk areas are flagged, not hidden:** the doc-check steps in Tasks 2–4 name each assumption and the exact wiring change if the doc disagrees; Task 5's `.amxd` builder self-verifies and has a manual fallback in Task 6.
- **Type consistency:** trigger bus name `---trig` used identically in Tasks 4 and 5; abstraction filenames match between definition and `bpatcher @name` references; parameter longnames unique per file.
