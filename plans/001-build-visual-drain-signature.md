# 001 — Build the visual drain signature

- **Status**: TODO
- **Commit**: dc191bd
- **Severity**: HIGH
- **Category**: Missed opportunities
- **Estimated scope**: 3 files, about 220 lines

## Problem

The focused incident is a stack of text. Users must read three lines before
they can compare CPU, RAM, battery impact, and duration.

```swift
// Sources/Unhog/ResourceLensView.swift:101 — current
VStack(alignment: .leading, spacing: 5) {
    Text("\(MetricFormatting.memory(group.memoryBytes)) · "
        + "\(MetricFormatting.ramShare(store.ramShare(for: group))) "
        + "of installed RAM")
    Text(cpuDescription(group.cpuPercent))
    Text("\(batteryDescription(store.batteryEstimate(for: group)))"
        + durationSuffix(incident))
}
```

At `587% CPU`, the most important fact is “about 5.9 cores,” but it has no
visual weight. The interface should be understood before its labels are read.

## Target

Replace the metric paragraph with a compact `DrainSignatureView`:

```text
CPU     ▮▮▮▮▮▉□□□□□□    5.9 / 12 cores
RAM     ██□□□□□□□□□□    1.53 GB · 6%
Impact  ● ● ●             likely high · 1 min
```

- CPU uses one vertical pillar per logical core. Five full pillars and one
  90%-filled pillar represent 5.9 cores. Never turn raw `587%` into a
  whole-Mac percentage bar.
- RAM uses installed RAM as its denominator.
- Impact is a three-step qualitative scale. It must say `likely high`,
  `may be elevated`, or `looks low`; never show a fake battery percentage.
- Put the incident signal first: CPU first for CPU incidents, RAM first for
  memory incidents.
- Keep the existing title, scoped action, and `See why`.
- Expose the entire graphic as one VoiceOver element. Hide decorative pillars,
  fills, and dots.

The entrance reveal is rare and explanatory. Set a local `revealProgress` from
0 to 1 on first appearance using:

```swift
.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
```

Animate only `scaleEffect` and `opacity`. Anchor CPU pillar fill at `.bottom`
and RAM fill at `.leading`. Routine two-second samples update immediately;
they must not replay the entrance.

With Reduce Motion, use a 200 ms opacity fade and no scale movement.

## Repo conventions to follow

- Semantic colors live in `Sources/Unhog/DesignSystem.swift`.
- Metric formatting lives in `Sources/Unhog/Formatting.swift`.
- The current view reads prepared domain values from `AppStore`; it never
  samples processes itself.
- Use `UnhogTheme.appColor(for:)` for identity and
  `UnhogTheme.attention` only for unusual impact.

## Steps

1. Add `Sources/Unhog/DrainSignatureView.swift`.
2. Define a small value type, `DrainSignature`, containing:
   `primarySignal`, `cpuPercent`, `logicalCoreCount`, `memoryBytes`,
   `installedRAMShare`, `batteryEstimate`, and `duration`.
3. Add a pure factory at the public seam
   `ProcessGroup + incident + installed RAM → DrainSignature`.
4. Before implementation, add focused tests proving:
   - `587% CPU` becomes `5.87` cores against the real supplied core count;
   - RAM share remains `0.06`, not `6`;
   - CPU incidents put CPU first and memory incidents put RAM first.
5. Render CPU pillars, the RAM rail, and qualitative impact row using
   transforms and opacity only.
6. Replace `ResourceLensView.swift:101-120` with `DrainSignatureView`.
7. Remove the now-unused private CPU, battery, and duration formatting helpers
   from `ResourceLensView`.
8. Add one preview fixture for a CPU-led Playwright incident.

## Boundaries

- Do NOT change pressure thresholds or process sampling.
- Do NOT present battery impact as measured power.
- Do NOT remove exact text values; visuals and labels must agree.
- Do NOT add chart or animation dependencies.
- Do NOT animate on every resource sample.
- If the source differs from commit `dc191bd`, stop and report drift.

## Verification

- **Mechanical**:
  `swift test --filter DrainSignatureTests`, then `swift test`.
- **Feel check**:
  - Open the CPU preview and understand “about six cores” before reading.
  - Confirm 6% RAM looks small rather than exaggerated.
  - Inspect at 10% animation speed: fills grow from their physical origin.
  - Toggle Reduce Motion: movement disappears, a 200 ms fade remains.
- **Done when**: the focused block has no three-line metric paragraph, every
  visual has an exact text equivalent, and routine samples do not replay.
