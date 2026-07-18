# How Bonko Was Built Without a Patch-Editing Server

The maxmsp MCP server used in this project can create, wire, and edit objects
live — but only inside the one patch that hosts its MaxMSP-Agent, and it
cannot write or save patcher files on disk. Bonko was built without it,
because **Max patches are just JSON text files**. This doc records the method
so it can be repeated.

**When to use which workflow:**

- **Live MCP editing** (agent-hosted patch; see `m4l-polygrid/CLAUDE.md` for
  the full workflow) — best for debugging an existing patch interactively:
  you can probe objects with messages/bangs, hear results immediately, and
  read real wiring back with `get_objects_in_patch`. Constraints: edits are
  trapped in the agent's window, live in memory until a human saves, and
  `set_object_attribute` can't move objects after creation.
- **Offline JSON authoring** (this doc) — best for building patchers from
  scratch, batch edits, and anything that should be committable and testable
  without Max running. Constraint: blind to runtime behavior; structure is
  validated, semantics are verified later in Live.

## The core insight

A `.maxpat` file is a JSON document with one top-level `patcher` object:

```json
{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "rect": [100.0, 100.0, 700.0, 500.0],
    "openinpresentation": 1,
    "boxes": [ {"box": { "id": "obj-1", "maxclass": "newobj", "text": "svf~ 1500. 0.707", ... }} ],
    "lines": [ {"patchline": {"source": ["obj-1", 1], "destination": ["obj-2", 0]}} ]
  }
}
```

- **`boxes`** — one entry per object. `maxclass` is `"newobj"` for ordinary
  objects (the object name and arguments go in `text`, e.g. `"pattr TargetId
  @parameter_enable 1"`), or the UI class directly (`live.dial`, `live.text`,
  `message`, `comment`, `meter~`, `button`, `bpatcher`, `inlet`, `outlet`).
  Every box needs a unique `id` and a `patching_rect`; UI objects
  additionally get `"presentation": 1` and a `presentation_rect`.
- **`lines`** — patch cords: `source`/`destination` are `[box-id,
  inlet/outlet-index]` pairs, 0-indexed left to right.
- **`live.*` parameter objects** — need `"parameter_enable": 1` and a
  `saved_attribute_attributes.valueof` block carrying `parameter_longname`,
  `parameter_shortname`, `parameter_type`, `parameter_range`,
  `parameter_unitstyle`, `parameter_initial`, etc. This is what makes a dial
  automatable and saved with the Live set.
- **Abstractions** — a separate `.maxpat` file referenced by a `bpatcher` box
  (`"name": "bonko.slot.maxpat"`). Instantiating the same file N times gives
  N independent copies; Max auto-renames conflicting parameter longnames
  (`Prob` → `Prob[1]`) at load.
- Escaping quirk: commas inside object text are escaped with a backslash,
  which in JSON becomes `\\,` (see the detector's `expr` box).

So "building a patch" = writing these JSON files with an ordinary file-write
tool. No Max involvement is needed until the moment a human opens the result.

## What kept blind JSON authoring honest

Writing patch JSON without Max running would be guesswork without two
compensating practices:

**1. A structural validator as the test harness** (`tools/validate_patch.py`,
tests in `tests/`). It can't run DSP, but it catches the failure modes typical
of hand-written patches: invalid JSON, duplicate box ids, patch cords pointing
at nonexistent boxes, missing rects, duplicate `parameter_longname`s, and
`live.*` UI objects missing `parameter_enable`. Every patcher file was
validated before being committed. One blind spot: the validator has no object
database, so it cannot check that an inlet/outlet *index* exists on the target
object — a cord to inlet 3 of a two-inlet object passes. That's exactly what
the `get_object_doc` step below covers.

**2. Doc-checking every load-bearing object assumption** via the MCP server's
`get_object_doc` (the one capability it does provide, and it needs no open
patch). Before each patcher was written, the plan's assumptions were verified
against the installed Max's own reference docs: `svf~` outlet order, `onebang`
re-arm behavior, `zl.reg` silent-store inlet, `line~` multi-segment lists,
`live.remote~`/`live.observer`/`live.object`/`live.path` message formats.
This step also *improved* the design: the `live.remote~` doc revealed the
`@normalized 1` attribute, which auto-scales 0..1 input to the target
parameter's range and eliminated an entire min/max-query-and-scale subgraph
from `bonko.map.maxpat`.

**3. Mining Ableton's shipped patchers for canonical patterns.** Object docs
tell you what an object *can* do, not which object the platform intends you
to use. The first map implementation hand-rolled `live.observer` + `pattr` +
manual `id` messages — it resolved parameter names but never established the
`live.remote~` binding. The fix came from grepping Live's own install for
working examples: `Max.app/.../packages/Max for Live/clippings/Live API
Snippets/Device.DeviceParameterMap.maxpat` is Ableton's official Map-button
reference, and it revealed the purpose-built `live.map` object (arm, click
capture, binding, naming, and `_persistence: 1` save/reload in one box).
When implementing any Live-integration behavior, search those clippings and
the Builtin/Devices folders for the canonical pattern *before* composing it
from primitives.

## The .amxd step

A Max for Live device is the same patcher JSON wrapped in a small binary
container. Hex-dumping Ableton's blank device
(`/Applications/Ableton Live 12 Suite.app/Contents/App-Resources/Misc/Max
Devices/Max Audio Effect.amxd`) confirmed the layout:

```
"ampf" | uint32le 4 | type code | "meta" | uint32le 4 | uint32le 0 | "ptch" | uint32le json-length | <patcher JSON>
```

The type code after `ampf` is `aaaa` for an audio effect, `mmmm` for a MIDI
effect, and `iiii` for an instrument (verified by hex-dumping all three blank
devices shipped with Live 12) — which is why the reference must be the same
device type. The 4-byte `meta` payload is zero in all three blanks; its
meaning is unknown, another reason to transplant the header rather than
synthesize it.

`tools/make_amxd.py` transplants that header rather than hard-coding it: it
reads a reference `.amxd`, finds where the JSON begins, verifies the 4 bytes
before it encode the JSON's length (trying both endiannesses), swaps in the
new patcher JSON, rewrites the length, and round-trip-checks the output.

```
python3 tools/make_amxd.py <reference.amxd> Bonko.maxpat Bonko.amxd
```

## Limits of the method

- The validator proves structure, not behavior. Runtime semantics (does the
  envelope follower actually track guitar picks?) are only testable in
  Live/Max — hence the in-Live verification checklist in the plan.
- Hand-authored JSON is minimal; Max normalizes it (canonical attribute
  ordering, resolved parameter renames) the first time the device is saved
  from the editor. Commit the normalized file after first verification.
- Coordinates and rects are laid out by arithmetic, not by eye. Expect to
  nudge the presentation layout in Max once, then re-save.
