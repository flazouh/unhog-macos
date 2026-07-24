# 005 — Redesign the menu bar signal

- **Status**: DONE
- **Commit**: dc191bd
- **Severity**: HIGH
- **Category**: Product clarity
- **Estimated scope**: 4 files, about 220 lines

## Problem

The current menu bar label changes SF Symbol, but it does not explain whether
CPU or memory caused the state. The popover header then repeats the same
status. Users must open Unhog before learning why it wants attention.

## Target

Implement the adaptive state model in
`docs/menu-bar-and-settings-spec.md`.

Default behavior:

```text
normal:       ○
CPU incident: ! 5.9c
RAM incident: ! 06%
partial stop: △ 2
recovered:    ✓ 3.2 GB
```

Keep the item icon-only while calm. During an incident, add the primary metric.
Use a stable, monospaced metric slot and update only when sampled state changes.

## Test seam

Add a pure presenter:

```swift
MenuBarPresentation.make(
    phase: ResourceLensPhase,
    focusedGroup: ProcessGroup?,
    incident: ResourceIncident?,
    preferences: UnhogPreferences
) -> MenuBarPresentation
```

Test symbol, compact label, spoken label, priority, and display mode without
creating a SwiftUI scene.

## Steps

1. Write failing tests for every state and priority edge.
2. Add `MenuBarPresentation` to `UnhogCore`.
3. Add Adaptive, Icon only, Top CPU, and Top RAM display modes.
4. Replace `AppStore.menuBarSymbol` and its separate accessibility switch
   with the presenter output.
5. Render icon plus optional compact label in `UnhogApp`.
6. Use monospaced digits and stable width for the optional label.
7. Return Recovered to Calm after eight seconds without a repeating timer.
8. Show only verified recovered CPU or memory in the temporary receipt label.
9. Open the correct popover phase for Attention, Stopping, Recovered,
   Restarted, and Partial.

## Boundaries

- No destructive menu bar shortcut.
- No continuous animation, spinner, pulse, or display timer.
- No composite health score.
- Do not say a top-workload metric is whole-system usage.
- Shape must communicate state without colour.
- If source differs from `dc191bd`, stop and report drift.

## Verification

- `swift test --filter MenuBarPresentationTests`
- `swift test`
- Check light, dark, Increase Contrast, and VoiceOver.
- Confirm calm mode performs no view updates beyond actual state changes.
- Confirm adjacent menu bar content does not jitter during sample updates.
