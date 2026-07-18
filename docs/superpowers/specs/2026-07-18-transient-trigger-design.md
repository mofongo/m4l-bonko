# Transient Trigger — Max for Live Device Design

**Date:** 2026-07-18
**Status:** Approved design, pending implementation plan
**Device name:** Bonko

## Summary

A Max for Live **Audio Effect** (`.amxd`) that detects transients in the incoming
audio — tuned for guitar pick attacks — and fires triggered AD-envelope modulation
at up to **4 user-mapped parameters** anywhere in the Live set, each with independent
envelope settings and trigger probability. Mapping uses the standard Ableton
Map-button workflow (`live.remote~` + selected-parameter observation). No MIDI
output; no third-party externals (bonk~ was considered and rejected — see
Decisions).

## Goals

- Reliable transient detection on guitar (single notes, fast picking, strums,
  palm mutes) with only three tuning controls.
- Map-button UX identical in feel to Ableton's own LFO / Envelope Follower devices.
- 4 independent target slots, each: probability gate + AD envelope + min/max range.
- 100% vanilla Max objects → freezes cleanly, Apple Silicon safe, shareable.
- Audio passthrough is bit-identical (device is purely a listener).

## Non-Goals (v1)

- MIDI note output to other tracks (explicitly cut; parameter modulation only).
- Trigger-distribution logic beyond per-slot probability (round-robin sequencing,
  random-pick modes are v2; the trigger bus is the designed seam for them).
- FluCoMa or other spectral onset engines (the detector is a swappable subpatch
  if this is ever wanted).
- More than 4 slots.

## Architecture

Modular bpatcher design: one detector subpatch, four instances of one
target-slot abstraction, joined by a trigger bus.

```
plugin~ ──────────────────────────────► plugout~   (dry passthrough, untouched)
   │
   └─► [ DETECTOR ]──bang per transient──► [ TRIGGER BUS ]
         (HPF → env follower                     │
          → onset logic)            ┌────────┬───┴────┬────────┐
                                    ▼        ▼        ▼        ▼
                                 [SLOT 1] [SLOT 2] [SLOT 3] [SLOT 4]
                                  each: probability gate → AD envelope
                                        → live.remote~ → mapped parameter
```

- **Trigger bus:** a named send in v1. It is the single seam where v2 logic
  (sequencing, random pick) inserts later without modifying detector or slots.
- **Slot abstraction:** one bpatcher file instantiated 4× with a slot-number
  argument (`#1`) so each slot's `live.*` parameters get unique names for
  Live's save/undo/automation system.

## Component: Detector

All stock Max objects. Detection path only — the audio passthrough never touches
any of this.

| Stage | Implementation | Control |
|---|---|---|
| Detection HPF | `svf~` high-pass on a tapped copy of the input | **Focus** dial, 200 Hz–8 kHz, default ~1.5 kHz |
| Envelope follower | `abs~` → `slide~`, fast rise / moderate fall | (internal, fixed) |
| Onset decision | envelope crosses **above** threshold from below: `>~` → `edge~` | **Sensitivity** dial (threshold, inverted: clockwise = more triggers) |
| Retrigger guard | ignore triggers for N ms after each fire | **Retrig** dial, 20–500 ms, default 60 ms |

Rationale: the pick attack carries a burst of high-frequency energy that string
sustain lacks, so a high-pass "Focus" control separates attacks from sustain far
better than full-band amplitude detection. `slide~`'s fall time lets the envelope
decay below threshold during sustain so the next pick re-crosses and re-fires.
Default Retrig of 60 ms tracks 16th-note picking at 250 BPM while suppressing
strum chatter.

UI feedback: input level meter + trigger LED so the user can see why the detector
is or isn't firing while adjusting Sensitivity/Focus.

## Component: Target Slot (×4)

Per-trigger chain:

```
trigger ─► probability gate ─► AD envelope ─► scale to [Min..Max] ─► live.remote~
```

1. **Probability gate** — `random 100` compared against **Prob** dial (0–100 %,
   default 100 %). 0 % acts as a slot mute.
2. **AD envelope** — signal-rate (`curve~`): 0→1 over **Attack** (0–500 ms,
   default 1 ms), then 1→0 over **Decay** (10 ms–5 s, default 250 ms).
   Signal-rate because `live.remote~` takes a signal input → smooth sub-block
   modulation. **Retrigger restarts from the envelope's current value** (no
   clicks, no value pileup).
3. **Min/Max scaling** — envelope 0..1 mapped to **Min**/**Max** dials (each
   0–100 % of the target parameter's range). Min > Max inverts the envelope
   (built-in "duck" mode, no extra control).
4. **Map binding** — standard Ableton pattern:
   - Click **Map** → observe `live_set view selected_parameter` via
     `live.path` / `live.observer`.
   - User clicks any parameter on any device in the set → capture its id, bind
     `live.remote~`, display "DeviceName > ParamName" on the slot.
   - Map button toggles to **unmap**; unmapping releases the parameter back to
     Live at its pre-mapped value.
   - Binding persists with the Live set (id stored in the device's `pattr`
     state, re-resolved on set load).

Per-slot controls: **Map** (with name display), **Prob**, **Attack**, **Decay**,
**Min**, **Max**.

## UI Layout

Standard Live device height, horizontal:

```
┌──────────┬──────────────┬──────────────┬──────────────┬──────────────┐
│ DETECT   │ SLOT 1       │ SLOT 2       │ SLOT 3       │ SLOT 4       │
│ [meter]● │ [Map: name ] │ [Map: name ] │ [Map: name ] │ [Map: name ] │
│ Focus    │ Prob         │ Prob         │ Prob         │ Prob         │
│ Sens     │ Atk  Dec     │ Atk  Dec     │ Atk  Dec     │ Atk  Dec     │
│ Retrig   │ Min  Max     │ Min  Max     │ Min  Max     │ Min  Max     │
└──────────┴──────────────┴──────────────┴──────────────┴──────────────┘
   ● = trigger LED
```

Every user control is a `live.*` object → automatable, MIDI-mappable, saved with
the set, undo-friendly.

## Edge Cases & Error Handling

- **Deleted target device:** stale `live.object` id detected on next trigger or
  set load → slot silently clears to unmapped state ("Map"). No error spam.
- **Parameter already automated/mapped elsewhere:** standard Live behavior —
  `live.remote~` takes control (Live greys out the parameter); unmapping
  releases it.
- **Set load order:** all Live API binding deferred until `live.thisdevice`
  bangs (the standard M4L initialization gotcha).
- **Freeze/share:** all-vanilla objects, so the frozen `.amxd` is fully
  self-contained with no dependencies.

## Testing Plan

- **Passthrough null test:** device in the chain vs. bypassed — output must be
  bit-identical.
- **Detection accuracy:** recorded guitar DI loop covering picked single notes,
  fast picking, strums, palm mutes; verify sensible trigger behavior across
  Sensitivity/Focus/Retrig ranges.
- **Probability sanity:** at 50 %, ~100 triggers should land near 50 ± 10 fires.
- **Mapping lifecycle:** map → modulate → unmap → undo → save → reload set →
  binding restored; delete target device → slot clears gracefully.
- **CPU:** negligible load (target ≤ ~1 % on an idle set).

## Decisions Log

| Decision | Choice | Why |
|---|---|---|
| bonk~ external | **Rejected** | Aged, sporadically maintained Max port; Apple Silicon/signing risk; vanilla objects suffice for guitar |
| Detection engine | Vanilla Max (env follower + threshold) | Zero dependencies, freezes cleanly; detector is a swappable subpatch if FluCoMa is ever wanted |
| Output mechanism | `live.remote~` parameter modulation only | User confirmed; avoids the M4L audio-effect MIDI-routing workaround entirely |
| Trigger shape | AD envelope per slot | Most musical; gate/toggle modes deferred |
| Slot count | 4 | Fits device width; architecture indifferent to count |
| Per-slot logic in v1 | Probability only | Cheap, immediately useful; sequencing/distribution modes are v2 via the trigger bus seam |
| Structure | Modular bpatchers | Slot built once, instantiated 4×; v2 logic touches only the trigger bus |

## Post-v1 Additions

- **Rnd toggle per slot** (user request during verification): when on, each
  trigger assigns a fresh random Attack in [0 .. Atk dial] and random Decay in
  [10 ms .. Dec dial] — the dials act as ceilings. Toggling off restores exact
  dial values. Implemented via a gate routing the trigger to either the stored
  dial pair or a random-generation path, both writing the same `zl.reg`.
- **Mapping mechanism** (verification fix): hand-rolled observer/pattr chain
  replaced with Ableton's canonical `live.map @strict 1` → `live.remote~
  @normalized 1` pattern (both with `_persistence: 1`). Label shows parameter
  name only. Map toggle off = full unmap.

## V2 Ideas (out of scope, recorded for the seam design)

- Trigger-distribution modes on the bus: All / Round-robin / Random pick.
- Per-slot velocity: scale envelope peak by transient strength.
- Gate and toggle trigger shapes as a per-slot mode selector.
- FluCoMa `fluid.onsetslice~` as an alternative detector engine.
